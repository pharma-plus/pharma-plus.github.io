import { query, withTransaction } from '../../db/pool.js';
import { auditLog } from '../../middleware/audit.js';
import { NotFoundError, AppError } from '../../utils/errors.js';
import { uuid } from '../../utils/crypto.js';
import { paginate } from '../../utils/response.js';

/** Insère un mouvement de stock (le trigger met à jour stock_balances). */
export function insertMovement(client, { pharmacyId, branchId, medicationId, lotId, type, quantity, unitCost = 0, referenceType = null, referenceId = null, userId = null, notes = null }) {
  return client.query(
    `INSERT INTO stock_movements
       (pharmacy_id, branch_id, medication_id, lot_id, movement_type, quantity,
        unit_cost, reference_type, reference_id, user_id, notes)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)`,
    [pharmacyId, branchId, medicationId, lotId, type, quantity, unitCost,
     referenceType, referenceId, userId, notes],
  );
}

export const stockService = {
  /** État du stock (par succursale ou global). */
  async listStock(pharmacyId, { page = 1, limit = 20, q, branchId, lowStock, expiring, expired }) {
    const pg = paginate(page, limit);
    const where = ['sb.pharmacy_id = $1'];
    const params = [pharmacyId];
    let i = 2;

    if (branchId) { where.push(`sb.branch_id = $${i}`); params.push(branchId); i++; }
    if (expired) {
      where.push(`l.expiry_date < CURRENT_DATE`);
    } else if (expiring) {
      where.push(`l.expiry_date >= CURRENT_DATE AND l.expiry_date <= CURRENT_DATE + $${i} * interval '1 day'`);
      params.push(expiring); i++;
    }
    if (lowStock) {
      where.push(`(sb.quantity - sb.reserved_quantity) <= m.reorder_level`);
    }

    const whereCount = where.filter((w) => !w.startsWith('(sb.quantity'));
    const count = await query(
      `SELECT count(*)::int AS total
         FROM stock_balances sb
         JOIN medications m ON m.id = sb.medication_id
         LEFT JOIN lots l ON l.id = sb.lot_id
        WHERE ${whereCount.join(' AND ')}`, params,
    );

    const { rows } = await query(
      `SELECT sb.id, sb.branch_id, b.name AS branch_name, sb.medication_id,
              m.name AS medication_name, m.dosage, m.form, m.barcode_ean13, m.price_sale,
              sb.lot_id, l.lot_number, l.expiry_date, l.cost_price,
              sb.quantity, sb.reserved_quantity,
              (sb.quantity - sb.reserved_quantity) AS available,
              m.reorder_level, m.shelf_location,
              CASE WHEN l.expiry_date < CURRENT_DATE THEN 'expired'
                   WHEN l.expiry_date <= CURRENT_DATE + 90 THEN 'expiring'
                   ELSE 'ok' END AS expiry_status
         FROM stock_balances sb
         JOIN branches b ON b.id = sb.branch_id
         JOIN medications m ON m.id = sb.medication_id
         LEFT JOIN lots l ON l.id = sb.lot_id
        WHERE ${where.join(' AND ')}
        ORDER BY l.expiry_date NULLS LAST, m.name
        LIMIT $${i} OFFSET $${i + 1}`,
      [...params, pg.limit, pg.offset],
    );
    return { items: rows, meta: { ...pg, total: count.rows[0].total } };
  },

  /** Entrée de stock (création de lot + mouvement purchase_receipt/inventory_in). */
  async addStock(pharmacyId, branchId, items, { type = 'purchase_receipt' } = {}, user) {
    if (!items?.length) throw new AppError('Aucun article fourni', 422, 'BAD_REQUEST');
    return withTransaction(pharmacyId, async (client) => {
      for (const item of items) {
        const med = await client.query(
          'SELECT id, name FROM medications WHERE id = $1 AND pharmacy_id = $2',
          [item.medication_id, pharmacyId],
        );
        if (!med.rows[0]) throw new NotFoundError(`Médicament introuvable : ${item.medication_id}`);

        // Lot existant ?
        let lotId = item.lot_id;
        if (!lotId) {
          const existingLot = await client.query(
            `SELECT id FROM lots
              WHERE pharmacy_id = $1 AND medication_id = $2 AND lower(lot_number) = lower($3)`,
            [pharmacyId, item.medication_id, item.lot_number],
          );
          if (existingLot.rows[0]) {
            lotId = existingLot.rows[0].id;
          } else {
            const newId = uuid();
            const lotNumber = (item.lot_number && `${item.lot_number}`.trim())
              || `LOT-${Date.now()}`;
            await client.query(
              `INSERT INTO lots (id, pharmacy_id, medication_id, supplier_id, lot_number,
                                 manufacture_date, expiry_date, cost_price)
               VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
              [newId, pharmacyId, item.medication_id, item.supplier_id ?? null,
               lotNumber, item.manufacture_date ?? null,
               item.expiry_date, item.cost_price ?? 0],
            );
            lotId = newId;
          }
        }

        await insertMovement(client, {
          pharmacyId, branchId, medicationId: item.medication_id, lotId,
          type, quantity: item.quantity, unitCost: item.cost_price ?? 0,
          userId: user?.id, notes: item.notes,
        });
      }
    });
  },

  /** Ajustement de stock (écart d'inventaire). */
  async adjust(pharmacyId, branchId, items, user, inventorySessionId = null) {
    return withTransaction(pharmacyId, async (client) => {
      const result = [];
      for (const item of items) {
        const { rows } = await client.query(
          `SELECT sb.id, sb.quantity, sb.lot_id, l.expiry_date, l.cost_price
             FROM stock_balances sb LEFT JOIN lots l ON l.id = sb.lot_id
            WHERE sb.branch_id = $1 AND sb.medication_id = $2 AND sb.pharmacy_id = $3`,
          [branchId, item.medication_id, pharmacyId],
        );
        if (!rows[0]) throw new NotFoundError(`Aucune balance pour le médicament ${item.medication_id}`);
        const current = rows[0];
        const diff = Number(item.new_quantity) - Number(current.quantity);
        if (diff === 0) {
          result.push({ medication_id: item.medication_id, diff: 0 });
          continue;
        }
        await insertMovement(client, {
          pharmacyId, branchId, medicationId: item.medication_id, lotId: current.lot_id,
          type: diff > 0 ? 'inventory_in' : 'adjustment',
          quantity: Math.abs(diff), unitCost: current.cost_price ?? 0,
          referenceType: inventorySessionId ? 'inventory_session' : null,
          referenceId: inventorySessionId ?? null,
          userId: user?.id, notes: `Ajustement inventaire : ${current.quantity} → ${item.new_quantity}`,
        });
        result.push({ medication_id: item.medication_id, diff });
      }
      return result;
    });
  },

  /** Sortie de stock (mise au rebut / perte / péremption). */
  async writeOff(pharmacyId, branchId, items, user) {
    return withTransaction(pharmacyId, async (client) => {
      for (const item of items) {
        const { rows } = await client.query(
          `SELECT sb.id, sb.quantity, sb.lot_id, l.expiry_date
             FROM stock_balances sb LEFT JOIN lots l ON l.id = sb.lot_id
            WHERE sb.branch_id = $1 AND sb.medication_id = $2 AND sb.pharmacy_id = $3
              AND (sb.quantity - sb.reserved_quantity) >= $4
            LIMIT 1`,
          [branchId, item.medication_id, pharmacyId, item.quantity],
        );
        if (!rows[0]) throw new AppError(
          `Stock insuffisant ou périmé pour le médicament ${item.medication_id}`, 409, 'INSUFFICIENT_STOCK');
        await insertMovement(client, {
          pharmacyId, branchId, medicationId: item.medication_id, lotId: rows[0].lot_id,
          type: item.expired ? 'expiry_loss' : 'write_off',
          quantity: item.quantity, userId: user?.id, notes: item.reason ?? null,
        });
      }
    });
  },

  /** Historique des mouvements. */
  async listMovements(pharmacyId, { page = 1, limit = 20, branchId, medicationId, type, from, to }) {
    const pg = paginate(page, limit);
    const where = ['sm.pharmacy_id = $1'];
    const params = [pharmacyId];
    let i = 2;
    if (branchId) { where.push(`sm.branch_id = $${i}`); params.push(branchId); i++; }
    if (medicationId) { where.push(`sm.medication_id = $${i}`); params.push(medicationId); i++; }
    if (type) { where.push(`sm.movement_type = $${i}`); params.push(type); i++; }
    if (from) { where.push(`sm.created_at >= $${i}`); params.push(from); i++; }
    if (to) { where.push(`sm.created_at <= $${i}`); params.push(to); i++; }

    const count = await query(
      `SELECT count(*)::int AS total FROM stock_movements sm WHERE ${where.join(' AND ')}`, params,
    );
    const { rows } = await query(
      `SELECT sm.id, sm.branch_id, b.name AS branch_name, sm.medication_id,
              m.name AS medication_name, sm.lot_id, l.lot_number, sm.movement_type,
              sm.quantity, sm.unit_cost, sm.reference_type, sm.reference_id,
              sm.notes, sm.created_at, u.first_name, u.last_name
         FROM stock_movements sm
         JOIN branches b ON b.id = sm.branch_id
         JOIN medications m ON m.id = sm.medication_id
         LEFT JOIN lots l ON l.id = sm.lot_id
         LEFT JOIN users u ON u.id = sm.user_id
        WHERE ${where.join(' AND ')}
        ORDER BY sm.created_at DESC
        LIMIT $${i} OFFSET $${i + 1}`,
      [...params, pg.limit, pg.offset],
    );
    return { items: rows, meta: { ...pg, total: count.rows[0].total } };
  },

  /** Lots (péremptions). */
  async listLots(pharmacyId, { page = 1, limit = 20, medicationId, expiring, expired, q }) {
    const pg = paginate(page, limit);
    const where = ['l.pharmacy_id = $1'];
    const params = [pharmacyId];
    let i = 2;
    if (medicationId) { where.push(`l.medication_id = $${i}`); params.push(medicationId); i++; }
    if (q) { where.push(`(l.lot_number ILIKE $${i} OR m.name ILIKE $${i})`); params.push(`%${q}%`); i++; }
    if (expired) {
      where.push('l.expiry_date < CURRENT_DATE');
    } else if (expiring) {
      where.push(`l.expiry_date >= CURRENT_DATE AND l.expiry_date <= CURRENT_DATE + $${i} * interval '1 day'`);
      params.push(expiring); i++;
    }

    const count = await query(
      `SELECT count(*)::int AS total
         FROM lots l JOIN medications m ON m.id = l.medication_id
        WHERE ${where.join(' AND ')}`, params,
    );
    const { rows } = await query(
      `SELECT l.id, l.medication_id, m.name AS medication_name, m.barcode_ean13,
              l.lot_number, l.manufacture_date, l.expiry_date, l.cost_price, l.created_at,
              COALESCE((SELECT sum(sb.quantity - sb.reserved_quantity) FROM stock_balances sb
                 WHERE sb.lot_id = l.id), 0)::numeric(12,3) AS available,
              CASE WHEN l.expiry_date < CURRENT_DATE THEN 'expired'
                   WHEN l.expiry_date <= CURRENT_DATE + 90 THEN 'expiring'
                   ELSE 'ok' END AS expiry_status
         FROM lots l
         JOIN medications m ON m.id = l.medication_id
        WHERE ${where.join(' AND ')}
        ORDER BY l.expiry_date LIMIT $${i} OFFSET $${i + 1}`,
      [...params, pg.limit, pg.offset],
    );
    return { items: rows, meta: { ...pg, total: count.rows[0].total } };
  },

  /** Alertes stock : rupture, stock faible, péremptions. */
  async alerts(pharmacyId) {
    const [lowStock, expiring, expired, outOfStock] = await Promise.all([
      query(
        `SELECT m.id, m.name, m.reorder_level, COALESCE(sum(sb.quantity - sb.reserved_quantity), 0)::numeric(12,3) AS available
           FROM medications m
           LEFT JOIN stock_balances sb ON sb.medication_id = m.id AND sb.pharmacy_id = m.pharmacy_id
          WHERE m.pharmacy_id = $1 AND m.status = 'available'
          GROUP BY m.id
         HAVING COALESCE(sum(sb.quantity - sb.reserved_quantity), 0) <= m.reorder_level
          ORDER BY available LIMIT 100`, [pharmacyId]),
      query(
        `SELECT m.id, m.name, l.expiry_date, sum(sb.quantity)::numeric(12,3) AS quantity
           FROM lots l
           JOIN medications m ON m.id = l.medication_id AND m.pharmacy_id = l.pharmacy_id
           JOIN stock_balances sb ON sb.lot_id = l.id AND sb.quantity > 0
          WHERE l.pharmacy_id = $1 AND l.expiry_date >= CURRENT_DATE
            AND l.expiry_date <= CURRENT_DATE + 90
          GROUP BY m.id, m.name, l.expiry_date ORDER BY l.expiry_date LIMIT 100`, [pharmacyId]),
      query(
        `SELECT m.id, m.name, l.expiry_date, sum(sb.quantity)::numeric(12,3) AS quantity
           FROM lots l
           JOIN medications m ON m.id = l.medication_id AND m.pharmacy_id = l.pharmacy_id
           JOIN stock_balances sb ON sb.lot_id = l.id AND sb.quantity > 0
          WHERE l.pharmacy_id = $1 AND l.expiry_date < CURRENT_DATE
          GROUP BY m.id, m.name, l.expiry_date ORDER BY l.expiry_date LIMIT 100`, [pharmacyId]),
      query(
        `SELECT id, name, barcode_ean13 FROM medications
          WHERE pharmacy_id = $1 AND status = 'out_of_stock' LIMIT 100`, [pharmacyId]),
    ]);
    return {
      low_stock: lowStock.rows,
      expiring: expiring.rows,
      expired: expired.rows,
      out_of_stock: outOfStock.rows,
    };
  },

  // ---------------- Transferts inter-succursales ----------------
  async transfer(pharmacyId, fromBranch, toBranch, items, user) {
    if (fromBranch === toBranch) {
      throw new AppError('La succursale source et cible doivent être différentes', 422, 'BAD_REQUEST');
    }
    return withTransaction(pharmacyId, async (client) => {
      const transferId = uuid();
      const number = (await client.query(
        "SELECT fn_next_number($1::uuid, 'TRF') AS n", [pharmacyId],
      )).rows[0].n;

      await client.query(
        `INSERT INTO stock_transfers (id, pharmacy_id, from_branch, to_branch, number,
                                      status, notes, created_by)
         VALUES ($1,$2,$3,$4,$5,'in_transit',$6,$7)`,
        [transferId, pharmacyId, fromBranch, toBranch, number, null, user?.id],
      );

      for (const item of items) {
        await client.query(
          `INSERT INTO stock_transfer_items (transfer_id, pharmacy_id, medication_id, lot_id, quantity)
           VALUES ($1,$2,$3,$4,$5)`,
          [transferId, pharmacyId, item.medication_id, item.lot_id ?? null, item.quantity],
        );
        await insertMovement(client, {
          pharmacyId, branchId: fromBranch, medicationId: item.medication_id,
          lotId: item.lot_id ?? null, type: 'transfer_out', quantity: item.quantity,
          referenceType: 'stock_transfer', referenceId: transferId, userId: user?.id,
        });
        await insertMovement(client, {
          pharmacyId, branchId: toBranch, medicationId: item.medication_id,
          lotId: item.lot_id ?? null, type: 'transfer_in', quantity: item.quantity,
          unitCost: item.cost_price ?? 0,
          referenceType: 'stock_transfer', referenceId: transferId, userId: user?.id,
        });
      }

      await client.query(
        `UPDATE stock_transfers SET status = 'completed', completed_at = now() WHERE id = $1`,
        [transferId],
      );
      await auditLog({
        pharmacyId, userId: user?.id, action: 'create', module: 'stock',
        entity: 'stock_transfer', entityId: transferId,
        newValues: { number, from_branch: fromBranch, to_branch: toBranch },
      });
      return { id: transferId, number };
    });
  },

  async listTransfers(pharmacyId, { status }) {
    const where = ['st.pharmacy_id = $1'];
    const params = [pharmacyId];
    if (status) { where.push(`st.status = $2`); params.push(status); }
    const { rows } = await query(
      `SELECT st.*, fb.name AS from_branch_name, tb.name AS to_branch_name
         FROM stock_transfers st
         JOIN branches fb ON fb.id = st.from_branch
         JOIN branches tb ON tb.id = st.to_branch
        WHERE ${where.join(' AND ')} ORDER BY st.created_at DESC`,
      params,
    );
    return rows;
  },
};
