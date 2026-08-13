import { query, withTransaction } from '../../db/pool.js';
import { auditLog } from '../../middleware/audit.js';
import { AppError, NotFoundError } from '../../utils/errors.js';
import { uuid } from '../../utils/crypto.js';
import { insertMovement } from '../stock/service.js';
import { paginate } from '../../utils/response.js';

function computeTotals(items) {
  let subtotal = 0;
  let taxTotal = 0;
  let discountTotal = 0;
  for (const it of items) {
    const gross = it.unit_cost * it.quantity_ordered;
    const discount = gross * (it.discount / 100);
    const net = gross - discount;
    subtotal += net;
    taxTotal += net * (it.tva_rate / 100);
    discountTotal += discount;
  }
  return { subtotal, taxTotal, discountTotal, total: subtotal + taxTotal };
}

export const purchasesService = {
  async createOrder(pharmacyId, { branchId, supplierId, expectedDate, notes, items }, user) {
    if (!items?.length) throw new AppError('Commande vide', 422, 'EMPTY_ORDER');
    const id = await withTransaction(pharmacyId, async (client) => {
      const number = (await client.query(
        "SELECT fn_next_number($1::uuid, 'CMD') AS n", [pharmacyId],
      )).rows[0].n;
      const totals = computeTotals(items);
      const orderId = uuid();

      await client.query(
        `INSERT INTO purchase_orders (id, pharmacy_id, branch_id, supplier_id, number,
                                      status, order_date, expected_date, subtotal,
                                      tax_total, discount_total, total, notes, created_by)
         VALUES ($1,$2,$3,$4,$5,'draft', CURRENT_DATE, $6, $7, $8, $9, $10, $11, $12)`,
        [orderId, pharmacyId, branchId, supplierId, number, expectedDate ?? null,
         totals.subtotal, totals.taxTotal, totals.discountTotal, totals.total, notes ?? null, user?.id],
      );

      for (const item of items) {
        const med = await client.query(
          'SELECT id, name FROM medications WHERE id = $1 AND pharmacy_id = $2',
          [item.medication_id, pharmacyId],
        );
        if (!med.rows[0]) throw new NotFoundError(`Médicament introuvable : ${item.medication_id}`);
        await client.query(
          `INSERT INTO purchase_order_items (order_id, pharmacy_id, medication_id, quantity_ordered,
                                             unit_cost, tva_rate, discount)
           VALUES ($1,$2,$3,$4,$5,$6,$7)`,
          [orderId, pharmacyId, item.medication_id, item.quantity, item.unit_cost ?? 0,
           item.tva_rate ?? 20, item.discount ?? 0],
        );
      }

      await auditLog({
        pharmacyId, userId: user?.id, action: 'create', module: 'purchases',
        entity: 'purchase_order', entityId: orderId, newValues: { number, total: totals.total },
      });
      return orderId;
    });
    return this.getOrder(pharmacyId, id);
  },

  async getOrder(pharmacyId, id) {
    const { rows } = await query(
      `SELECT po.*, s.name AS supplier_name, b.name AS branch_name,
              u.first_name AS created_by_name
         FROM purchase_orders po
         JOIN suppliers s ON s.id = po.supplier_id
         JOIN branches b ON b.id = po.branch_id
         LEFT JOIN users u ON u.id = po.created_by
        WHERE po.id = $1 AND po.pharmacy_id = $2`,
      [id, pharmacyId],
    );
    if (!rows[0]) throw new NotFoundError('Commande introuvable');
    const order = rows[0];
    const [items, receptions] = await Promise.all([
      query(
        `SELECT poi.*, m.name AS medication_name, m.dosage, m.form
           FROM purchase_order_items poi
           LEFT JOIN medications m ON m.id = poi.medication_id
          WHERE poi.order_id = $1 ORDER BY m.name`, [id]),
      query(
        `SELECT pr.id, pr.number, pr.received_at, pr.notes,
                (SELECT count(*)::int FROM purchase_reception_items pri
                  WHERE pri.reception_id = pr.id) AS nb_lines
           FROM purchase_receptions pr WHERE pr.order_id = $1 ORDER BY pr.received_at DESC`, [id]),
    ]);
    order.items = items.rows;
    order.receptions = receptions.rows;
    return order;
  },

  async listOrders(pharmacyId, { page = 1, limit = 20, supplierId, status, from, to, q }) {
    const pg = paginate(page, limit);
    const where = ['po.pharmacy_id = $1'];
    const params = [pharmacyId];
    let i = 2;
    if (supplierId) { where.push(`po.supplier_id = $${i}`); params.push(supplierId); i++; }
    if (status) { where.push(`po.status = $${i}`); params.push(status); i++; }
    if (from) { where.push(`po.order_date >= $${i}`); params.push(from); i++; }
    if (to) { where.push(`po.order_date <= $${i}`); params.push(to); i++; }
    if (q) { where.push(`(po.number ILIKE $${i} OR s.name ILIKE $${i})`); params.push(`%${q}%`); i++; }

    const count = await query(
      `SELECT count(*)::int AS total FROM purchase_orders po
         JOIN suppliers s ON s.id = po.supplier_id WHERE ${where.join(' AND ')}`, params,
    );
    const { rows } = await query(
      `SELECT po.id, po.number, po.status, po.order_date, po.expected_date,
              po.received_date, po.total, po.subtotal, po.tax_total,
              s.name AS supplier_name, b.name AS branch_name
         FROM purchase_orders po
         JOIN suppliers s ON s.id = po.supplier_id
         JOIN branches b ON b.id = po.branch_id
        WHERE ${where.join(' AND ')}
        ORDER BY po.created_at DESC
        LIMIT $${i} OFFSET $${i + 1}`,
      [...params, pg.limit, pg.offset],
    );
    return { items: rows, meta: { ...pg, total: count.rows[0].total } };
  },

  async updateStatus(pharmacyId, id, status, user) {
    const valid = ['draft', 'sent', 'confirmed', 'cancelled'];
    if (!valid.includes(status)) throw new AppError('Statut invalide', 422, 'BAD_STATUS');
    const { rows } = await query(
      `UPDATE purchase_orders SET status = $1 WHERE id = $2 AND pharmacy_id = $3 RETURNING *`,
      [status, id, pharmacyId],
    );
    if (!rows[0]) throw new NotFoundError('Commande introuvable');
    await auditLog({
      pharmacyId, userId: user?.id, action: 'status_change', module: 'purchases',
      entity: 'purchase_order', entityId: id, newValues: { status },
    });
    return rows[0];
  },

  /**
   * Réception partielle ou complète : vérifie les lots/péremptions,
   * met le stock à jour (movements purchase_receipt + création de lots).
   */
  async receiveOrder(pharmacyId, { orderId, branchId, notes, items }, user) {
    return withTransaction(pharmacyId, async (client) => {
      const order = await client.query(
        `SELECT * FROM purchase_orders WHERE id = $1 AND pharmacy_id = $2`,
        [orderId, pharmacyId],
      );
      if (!order.rows[0]) throw new NotFoundError('Commande introuvable');
      if (order.rows[0].status === 'cancelled') throw new AppError('Commande annulée', 409, 'CANCELLED');

      const orderItems = (await client.query(
        `SELECT * FROM purchase_order_items WHERE order_id = $1`, [orderId],
      )).rows;

      const number = (await client.query(
        "SELECT fn_next_number($1::uuid, 'RCP') AS n", [pharmacyId],
      )).rows[0].n;
      const receptionId = uuid();

      await client.query(
        `INSERT INTO purchase_receptions (id, pharmacy_id, order_id, branch_id, number, notes, received_by)
         VALUES ($1,$2,$3,$4,$5,$6,$7)`,
        [receptionId, pharmacyId, orderId, branchId, number, notes ?? null, user?.id],
      );

      let allReceived = true;
      for (const item of items) {
        const oi = orderItems.find((o) => o.medication_id === item.medication_id);
        if (!oi) throw new NotFoundError(`Article de commande introuvable : ${item.medication_id}`);
        if (Number(oi.quantity_received) + Number(item.quantity) > Number(oi.quantity_ordered)) {
          throw new AppError(
            `Réception trop importante pour ${item.medication_id} (déjà reçu : ${oi.quantity_received})`,
            409, 'OVER_RECEIPT');
        }

        // Lot (créé si nouveau)
        let lotId = item.lot_id;
        if (!lotId) {
          const existing = await client.query(
            `SELECT id FROM lots WHERE pharmacy_id = $1 AND medication_id = $2
               AND lower(lot_number) = lower($3)`,
            [pharmacyId, item.medication_id, item.lot_number],
          );
          if (existing.rows[0]) {
            lotId = existing.rows[0].id;
          } else {
            lotId = uuid();
            await client.query(
              `INSERT INTO lots (id, pharmacy_id, medication_id, supplier_id, lot_number,
                                 manufacture_date, expiry_date, cost_price)
               VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
              [lotId, pharmacyId, item.medication_id, order.rows[0].supplier_id,
               item.lot_number, item.manufacture_date ?? null, item.expiry_date,
               item.cost_price ?? oi.unit_cost],
            );
          }
        }

        await client.query(
          `INSERT INTO purchase_reception_items (reception_id, pharmacy_id, order_item_id, medication_id,
                                                 lot_id, quantity, expiry_date, cost_price)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
          [receptionId, pharmacyId, oi.id, item.medication_id, lotId, item.quantity,
           item.expiry_date ?? null, item.cost_price ?? oi.unit_cost],
        );

        await client.query(
          `UPDATE purchase_order_items SET quantity_received = quantity_received + $1
            WHERE id = $2`,
          [item.quantity, oi.id],
        );

        await insertMovement(client, {
          pharmacyId, branchId, medicationId: item.medication_id, lotId,
          type: 'purchase_receipt', quantity: item.quantity,
          unitCost: item.cost_price ?? oi.unit_cost,
          referenceType: 'purchase_reception', referenceId: receptionId,
          userId: user?.id,
        });
      }

      // Statut de la commande
      const updatedItems = (await client.query(
        `SELECT quantity_ordered, quantity_received FROM purchase_order_items WHERE order_id = $1`,
        [orderId],
      )).rows;
      const fullyReceived = updatedItems.every((o) => Number(o.quantity_received) >= Number(o.quantity_ordered));
      const anyReceived = updatedItems.some((o) => Number(o.quantity_received) > 0);
      const newStatus = fullyReceived ? 'received' : anyReceived ? 'partial' : order.rows[0].status;
      await client.query(
        `UPDATE purchase_orders SET status = $1, received_date = now() WHERE id = $2`,
        [newStatus, orderId],
      );

      await auditLog({
        pharmacyId, userId: user?.id, action: 'receive', module: 'purchases',
        entity: 'purchase_reception', entityId: receptionId,
        newValues: { number, order_number: order.rows[0].number },
      });

      return { id: receptionId, number, order_status: newStatus };
    });
  },

  async listReceptions(pharmacyId, { page = 1, limit = 20, orderId, branchId }) {
    const pg = paginate(page, limit);
    const where = ['pr.pharmacy_id = $1'];
    const params = [pharmacyId];
    let i = 2;
    if (orderId) { where.push(`pr.order_id = $${i}`); params.push(orderId); i++; }
    if (branchId) { where.push(`pr.branch_id = $${i}`); params.push(branchId); i++; }

    const count = await query(
      `SELECT count(*)::int AS total FROM purchase_receptions pr WHERE ${where.join(' AND ')}`, params,
    );
    const { rows } = await query(
      `SELECT pr.id, pr.number, pr.received_at, pr.notes, pr.order_id,
              po.number AS order_number, s.name AS supplier_name, b.name AS branch_name
         FROM purchase_receptions pr
         JOIN purchase_orders po ON po.id = pr.order_id
         JOIN suppliers s ON s.id = po.supplier_id
         JOIN branches b ON b.id = pr.branch_id
        WHERE ${where.join(' AND ')}
        ORDER BY pr.received_at DESC
        LIMIT $${i} OFFSET $${i + 1}`,
      [...params, pg.limit, pg.offset],
    );
    return { items: rows, meta: { ...pg, total: count.rows[0].total } };
  },
};
