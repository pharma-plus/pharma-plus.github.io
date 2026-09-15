import { query, withTransaction } from '../../db/pool.js';
import { auditLog } from '../../middleware/audit.js';
import { AppError, NotFoundError } from '../../utils/errors.js';
import { uuid } from '../../utils/crypto.js';
import { insertMovement } from '../stock/service.js';
import { paginate } from '../../utils/response.js';

/**
 * Calcule les totaux d'une ligne de vente.
 * net = qty * prix * (1 - remise%) ; taxe = net * TVA%.
 */
export function computeLine(item) {
  const gross = item.quantity * item.unit_price;
  const discountAmount = gross * (item.discount / 100);
  const net = gross - discountAmount;
  return {
    net,
    tax: net * (item.tva_rate / 100),
    discountAmount,
  };
}

/** Sélectionne les lots disponibles par FEFO (premier péremption, premier sorti). */
async function selectLots(client, branchId, medicationId, pharmacyId, quantity) {
  const { rows } = await client.query(
    `SELECT sb.lot_id, (sb.quantity - sb.reserved_quantity) AS available, l.expiry_date
       FROM stock_balances sb
       LEFT JOIN lots l ON l.id = sb.lot_id
      WHERE sb.branch_id = $1 AND sb.medication_id = $2 AND sb.pharmacy_id = $3
        AND (sb.quantity - sb.reserved_quantity) > 0
        AND (l.expiry_date IS NULL OR l.expiry_date >= CURRENT_DATE)
      ORDER BY l.expiry_date ASC NULLS LAST`,
    [branchId, medicationId, pharmacyId],
  );
  if (rows.length === 0) {
    throw new AppError('Produit indisponible en stock', 409, 'OUT_OF_STOCK');
  }
  let remaining = Number(quantity);
  const selected = [];
  for (const row of rows) {
    const take = Math.min(remaining, Number(row.available));
    if (take > 0) selected.push({ lot_id: row.lot_id, quantity: take });
    remaining -= take;
    if (remaining <= 0) break;
  }
  if (remaining > 0) {
    throw new AppError('Quantité insuffisante en stock', 409, 'INSUFFICIENT_STOCK');
  }
  return selected;
}

export const salesService = {
  /**
   * Caisse (POS) : validation, décrément de stock par lots FEFO,
   * paiement, ticket et facture éventuelle.
   */
  async createSale(pharmacyId, { branchId, customerId = null, items, payments, saleType = 'pos', notes, prescriptionId = null }, user) {
    if (!items?.length) throw new AppError('Panier vide', 422, 'EMPTY_CART');

    return withTransaction(pharmacyId, async (client) => {
      const number = (await client.query(
        "SELECT fn_next_number($1::uuid, 'VTE') AS n", [pharmacyId],
      )).rows[0].n;

      const saleId = uuid();
      let subtotal = 0;
      let discountTotal = 0;
      let taxTotal = 0;
      let costTotal = 0;
      const saleItems = [];
      const prepared = [];

      // Passe 1 : validation + calcul des lignes (sans insertion, pour pouvoir
      // insérer l'en-tête de vente AVANT les lignes qui le référencent).
      for (const item of items) {
        const med = await client.query(
          `SELECT id, name, price_sale, tva_rate, price_purchase, status
             FROM medications WHERE id = $1 AND pharmacy_id = $2`,
          [item.medication_id, pharmacyId],
        );
        if (!med.rows[0]) throw new NotFoundError(`Médicament introuvable : ${item.medication_id}`);
        const m = med.rows[0];
        if (m.status === 'retired') throw new AppError(`${m.name} est retiré de la vente`, 409, 'NOT_SALEABLE');

        const unitPrice = item.unit_price ?? Number(m.price_sale);
        const tvaRate = item.tva_rate ?? Number(m.tva_rate);
        const discount = item.discount ?? 0;
        const calc = computeLine({ quantity: item.quantity, unit_price: unitPrice, discount, tva_rate: tvaRate });

        let lotsUsed = [];
        if (saleType === 'pos') {
          lotsUsed = await selectLots(client, branchId, item.medication_id, pharmacyId, item.quantity);
        }

        prepared.push({
          medicationId: item.medication_id, lotId: item.lot_id ?? null,
          quantity: item.quantity, unitPrice, costPrice: Number(m.price_purchase),
          tvaRate, discount, net: calc.net, lotsUsed,
        });

        subtotal += calc.net;
        discountTotal += calc.discountAmount;
        taxTotal += calc.tax;
        costTotal += Number(item.quantity) * Number(m.price_purchase);
        saleItems.push({ medication_id: item.medication_id, name: m.name, quantity: item.quantity, unit_price: unitPrice, net: calc.net });
      }

      const total = Math.round((subtotal + taxTotal) * 100) / 100;
      const paidAmount = (payments || []).reduce((acc, p) => acc + Number(p.amount || 0), 0);
      const changeAmount = paidAmount > total ? Math.round((paidAmount - total) * 100) / 100 : 0;

      // Vente à crédit
      let creditAmount = 0;
      if (saleType === 'credit') {
        creditAmount = total;
        if (customerId) {
          const cust = await client.query(
            'SELECT credit_limit, credit_balance FROM customers WHERE id = $1 AND pharmacy_id = $2',
            [customerId, pharmacyId],
          );
          if (!cust.rows[0]) throw new NotFoundError('Client introuvable');
          const newBalance = Number(cust.rows[0].credit_balance) + total;
          if (cust.rows[0].credit_limit > 0 && newBalance > Number(cust.rows[0].credit_limit)) {
            throw new AppError('Le crédit du client serait dépassé', 409, 'CREDIT_LIMIT_EXCEEDED');
          }
          await client.query(
            'UPDATE customers SET credit_balance = credit_balance + $1 WHERE id = $2',
            [total, customerId],
          );
        }
      }

      await client.query(
        `INSERT INTO sales (id, pharmacy_id, branch_id, user_id, customer_id, number,
                            sale_type, status, subtotal, discount_total, tax_total,
                            total, cost_total, paid_amount, change_amount,
                            payment_method, notes, prescription_id)
         VALUES ($1,$2,$3,$4,$5,$6,$7,'completed',$8,$9,$10,$11,$12,$13,$14,$15,$16,$17)`,
        [saleId, pharmacyId, branchId, user?.id, customerId, number,
         saleType, subtotal, discountTotal, taxTotal, total, costTotal,
         paidAmount, changeAmount,
         (payments || []).map((p) => p.method).join('+') || 'credit',
         notes ?? null, prescriptionId ?? null],
      );

      // Passe 2 : décrément du stock (FEFO) + insertion des lignes de vente.
      for (const p of prepared) {
        for (const l of p.lotsUsed) {
          await insertMovement(client, {
            pharmacyId, branchId, medicationId: p.medicationId, lotId: l.lot_id,
            type: 'sale', quantity: l.quantity, unitCost: p.costPrice,
            referenceType: 'sale', referenceId: saleId, userId: user?.id,
          });
        }
        await client.query(
          `INSERT INTO sale_items (id, pharmacy_id, sale_id, medication_id, lot_id, quantity,
                                   unit_price, cost_price, tva_rate, discount, line_total)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)`,
          [uuid(), pharmacyId, saleId, p.medicationId, p.lotsUsed[0]?.lot_id ?? p.lotId,
           p.quantity, p.unitPrice, p.costPrice, p.tvaRate, p.discount, p.net],
        );
      }

      // Enregistrement des paiements
      for (const p of payments || []) {
        await client.query(
          `INSERT INTO payments (pharmacy_id, sale_id, customer_id, method, amount, reference, received_by)
           VALUES ($1,$2,$3,$4,$5,$6,$7)`,
          [pharmacyId, saleId, customerId ?? null, p.method, p.amount, p.reference ?? null, user?.id],
        );
      }

      // Facture pour les ventes à crédit (ou à la demande)
      let invoice = null;
      if (saleType === 'credit' || (payments || []).some((p) => p.generateInvoice)) {
        invoice = await this._createInvoice(client, pharmacyId, branchId, saleId, customerId, {
          subtotal, taxTotal, total, paidAmount, user,
        });
      }

      // Ticket
      const ticket = (await client.query(
        `INSERT INTO receipts (pharmacy_id, sale_id, branch_id, number, width_mm, content, printed_by)
         VALUES ($1,$2,$3,
                 (SELECT fn_next_number($1::uuid, 'TKT')),
                 80, $4, $5)
         RETURNING id, number`,
        [pharmacyId, saleId, branchId, JSON.stringify({ items: saleItems, subtotal, taxTotal, total, paid: paidAmount }), user?.id],
      )).rows[0];

      await auditLog({
        pharmacyId, userId: user?.id, action: 'create', module: 'sales',
        entity: 'sale', entityId: saleId, newValues: { number, total },
      });

      return {
        id: saleId, number, total, subtotal, tax_total: taxTotal,
        discount_total: discountTotal, paid_amount: paidAmount, change_amount: changeAmount,
        items: saleItems, ticket, invoice,
      };
    });
  },

  async _createInvoice(client, pharmacyId, branchId, saleId, customerId, { subtotal, taxTotal, total, paidAmount, user }) {
    const { rows } = await client.query(
      `INSERT INTO invoices (pharmacy_id, branch_id, sale_id, customer_id, number, type,
                             issue_date, due_date, subtotal, tax_total, total,
                             paid_amount, status, created_by)
       VALUES ($1,$2,$3,$4,
               (SELECT fn_next_number($1::uuid, 'FAC')),
               'invoice', CURRENT_DATE, CURRENT_DATE + interval '30 days',
               $5,$6,$7,$8, CASE WHEN $8 >= $7 THEN 'paid' ELSE 'unpaid' END, $9)
       RETURNING id, number, total, status`,
      [pharmacyId, branchId, saleId, customerId, subtotal, taxTotal, total, paidAmount, user?.id],
    );
    return rows[0];
  },

  /** Liste des ventes. */
  async listSales(pharmacyId, { page = 1, limit = 20, branchId, customerId, saleType, status, from, to, q }) {
    const pg = paginate(page, limit);
    const where = ['s.pharmacy_id = $1'];
    const params = [pharmacyId];
    let i = 2;
    if (branchId) { where.push(`s.branch_id = $${i}`); params.push(branchId); i++; }
    if (customerId) { where.push(`s.customer_id = $${i}`); params.push(customerId); i++; }
    if (saleType) { where.push(`s.sale_type = $${i}`); params.push(saleType); i++; }
    if (status) { where.push(`s.status = $${i}`); params.push(status); i++; }
    if (from) { where.push(`s.created_at >= $${i}`); params.push(from); i++; }
    if (to) { where.push(`s.created_at <= $${i}`); params.push(to); i++; }
    if (q) { where.push(`(s.number ILIKE $${i} OR c.name ILIKE $${i})`); params.push(`%${q}%`); i++; }

    const count = await query(
      `SELECT count(*)::int AS total FROM sales s
         LEFT JOIN customers c ON c.id = s.customer_id
        WHERE ${where.join(' AND ')}`, params,
    );
    const { rows } = await query(
      `SELECT s.id, s.number, s.sale_type, s.status, s.total, s.paid_amount,
              s.change_amount, s.payment_method, s.created_at, s.branch_id,
              b.name AS branch_name, c.name AS customer_name,
              u.first_name AS user_first_name, u.last_name AS user_last_name
         FROM sales s
         JOIN branches b ON b.id = s.branch_id
         LEFT JOIN customers c ON c.id = s.customer_id
         LEFT JOIN users u ON u.id = s.user_id
        WHERE ${where.join(' AND ')}
        ORDER BY s.created_at DESC
        LIMIT $${i} OFFSET $${i + 1}`,
      [...params, pg.limit, pg.offset],
    );
    return { items: rows, meta: { ...pg, total: count.rows[0].total } };
  },

  async getSale(pharmacyId, id) {
    const { rows } = await query(
      `SELECT s.*, b.name AS branch_name, c.name AS customer_name,
              u.first_name AS user_first_name, u.last_name AS user_last_name
         FROM sales s
         JOIN branches b ON b.id = s.branch_id
         LEFT JOIN customers c ON c.id = s.customer_id
         LEFT JOIN users u ON u.id = s.user_id
        WHERE s.id = $1 AND s.pharmacy_id = $2`,
      [id, pharmacyId],
    );
    if (!rows[0]) throw new NotFoundError('Vente introuvable');
    const sale = rows[0];
    const [items, payments] = await Promise.all([
      query(
        `SELECT si.*, m.name AS medication_name, m.dosage, m.form, l.lot_number
           FROM sale_items si
           LEFT JOIN medications m ON m.id = si.medication_id
           LEFT JOIN lots l ON l.id = si.lot_id
          WHERE si.sale_id = $1`, [id]),
      query('SELECT * FROM payments WHERE sale_id = $1 ORDER BY received_at', [id]),
    ]);
    sale.items = items.rows;
    sale.payments = payments.rows;
    return sale;
  },

  /**
   * Retour / remboursement : réintègre le stock, crée un avoir.
   */
  async returnSale(pharmacyId, { saleId, branchId, reason, returnType = 'refund', items }, user) {
    return withTransaction(pharmacyId, async (client) => {
      const sale = await client.query(
        'SELECT * FROM sales WHERE id = $1 AND pharmacy_id = $2', [saleId, pharmacyId],
      );
      if (!sale.rows[0]) throw new NotFoundError('Vente introuvable');
      if (sale.rows[0].status !== 'completed') throw new AppError('Vente déjà retournée', 409, 'ALREADY_RETURNED');
      const s = sale.rows[0];

      // Validation : quantités retournées <= quantités vendues
      let refundTotal = 0;
      for (const item of items) {
        const line = await client.query(
          `SELECT id, medication_id, lot_id, quantity, unit_price, line_total
             FROM sale_items WHERE sale_id = $1 AND medication_id = $2`,
          [saleId, item.medication_id],
        );
        if (!line.rows[0]) throw new NotFoundError(`Article de la vente introuvable : ${item.medication_id}`);
        if (Number(item.quantity) > Number(line.rows[0].quantity)) {
          throw new AppError('Quantité retournée supérieure à la quantité vendue', 409, 'INVALID_RETURN_QTY');
        }
        refundTotal += Number(line.rows[0].line_total) * (Number(item.quantity) / Number(line.rows[0].quantity));
      }

      const returnId = uuid();
      const number = (await client.query(
        "SELECT fn_next_number($1::uuid, 'RTR') AS n", [pharmacyId],
      )).rows[0].n;

      await client.query(
        `INSERT INTO sale_returns (id, pharmacy_id, branch_id, sale_id, number, return_type, reason, total_refund, user_id)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
        [returnId, pharmacyId, branchId, saleId, number, returnType, reason ?? null, refundTotal, user?.id],
      );

      for (const item of items) {
        const line = (await client.query(
          `SELECT id, lot_id, medication_id, quantity, unit_price FROM sale_items
            WHERE sale_id = $1 AND medication_id = $2`, [saleId, item.medication_id],
        )).rows[0];

        await client.query(
          `INSERT INTO sale_return_items (return_id, pharmacy_id, sale_item_id, medication_id, lot_id, quantity, unit_price)
           VALUES ($1,$2,$3,$4,$5,$6,$7)`,
          [returnId, pharmacyId, line.id, line.medication_id, line.lot_id, item.quantity, line.unit_price],
        );
        await insertMovement(client, {
          pharmacyId, branchId, medicationId: line.medication_id, lotId: line.lot_id,
          type: 'sale_return', quantity: item.quantity, unitCost: 0,
          referenceType: 'sale_return', referenceId: returnId, userId: user?.id,
        });
      }

      await client.query("UPDATE sales SET status = 'returned' WHERE id = $1", [saleId]);

      // Avoir
      await client.query(
        `INSERT INTO invoices (pharmacy_id, branch_id, sale_id, customer_id, number, type,
                               issue_date, subtotal, tax_total, total, paid_amount, status, created_by)
         VALUES ($1,$2,$3,$4,
                 (SELECT fn_next_number($1::uuid, 'AVR')),
                 'avoir', CURRENT_DATE, 0, 0, -$5, -$5, 'paid', $6)`,
        [pharmacyId, branchId, saleId, s.customer_id, refundTotal, user?.id],
      );

      // Remboursement client crédit
      if (s.sale_type === 'credit' && s.customer_id) {
        await client.query(
          'UPDATE customers SET credit_balance = GREATEST(0, credit_balance - $1) WHERE id = $2',
          [refundTotal, s.customer_id],
        );
      }

      await auditLog({
        pharmacyId, userId: user?.id, action: 'return', module: 'sales',
        entity: 'sale', entityId: saleId, newValues: { refundTotal, number },
      });

      return { id: returnId, number, refund_total: refundTotal };
    });
  },

  async listInvoices(pharmacyId, { page = 1, limit = 20, customerId, status, from, to }) {
    const pg = paginate(page, limit);
    const where = ['i.pharmacy_id = $1'];
    const params = [pharmacyId];
    let i = 2;
    if (customerId) { where.push(`i.customer_id = $${i}`); params.push(customerId); i++; }
    if (status) { where.push(`i.status = $${i}`); params.push(status); i++; }
    if (from) { where.push(`i.issue_date >= $${i}`); params.push(from); i++; }
    if (to) { where.push(`i.issue_date <= $${i}`); params.push(to); i++; }

    const count = await query(`SELECT count(*)::int AS total FROM invoices i WHERE ${where.join(' AND ')}`, params);
    const { rows } = await query(
      `SELECT i.*, c.name AS customer_name, b.name AS branch_name
         FROM invoices i
         LEFT JOIN customers c ON c.id = i.customer_id
         LEFT JOIN branches b ON b.id = i.branch_id
        WHERE ${where.join(' AND ')}
        ORDER BY i.issue_date DESC
        LIMIT $${i} OFFSET $${i + 1}`,
      [...params, pg.limit, pg.offset],
    );
    return { items: rows, meta: { ...pg, total: count.rows[0].total } };
  },

  async recordPayment(pharmacyId, { invoiceId = null, saleId = null, customerId, method, amount, reference }, user) {
    return withTransaction(pharmacyId, async (client) => {
      const paymentId = uuid();
      await client.query(
        `INSERT INTO payments (pharmacy_id, sale_id, customer_id, method, amount, reference, received_by)
         VALUES ($1,$2,$3,$4,$5,$6,$7)`,
        [pharmacyId, saleId ?? null, customerId ?? null, method, amount, reference ?? null, user?.id],
      );

      // Applique au client crédit
      if (customerId) {
        await client.query(
          'UPDATE customers SET credit_balance = GREATEST(0, credit_balance - $1) WHERE id = $2',
          [amount, customerId],
        );
      }
      // Applique à la facture
      if (invoiceId) {
        const inv = await client.query(
          `UPDATE invoices SET paid_amount = paid_amount + $1,
                  status = CASE WHEN paid_amount + $1 >= total THEN 'paid'
                                WHEN paid_amount + $1 > 0 THEN 'partial' ELSE status END
            WHERE id = $2 AND pharmacy_id = $3
           RETURNING *`, [amount, invoiceId, pharmacyId],
        );
        if (!inv.rows[0]) throw new NotFoundError('Facture introuvable');
      }
      await auditLog({
        pharmacyId, userId: user?.id, action: 'payment', module: 'sales',
        entity: invoiceId ? 'invoice' : 'customer', entityId: invoiceId ?? customerId,
        newValues: { method, amount, reference },
      });
      return { id: paymentId, amount, method };
    });
  },

  // ---------------- Réservations clients ----------------
  async listReservations(pharmacyId, { page = 1, limit = 20, status, branchId, customerId }) {
    const pg = paginate(page, limit);
    const where = ['r.pharmacy_id = $1'];
    const params = [pharmacyId];
    let i = 2;
    if (status) { where.push(`r.status = $${i}`); params.push(status); i++; }
    if (branchId) { where.push(`r.branch_id = $${i}`); params.push(branchId); i++; }
    if (customerId) { where.push(`r.customer_id = $${i}`); params.push(customerId); i++; }

    const count = await query(`SELECT count(*)::int AS total FROM reservations r WHERE ${where.join(' AND ')}`, params);
    const { rows } = await query(
      `SELECT r.id, r.branch_id, b.name AS branch_name, r.customer_id, c.name AS customer_name,
              r.medication_id, m.name AS medication_name, r.quantity, r.status,
              r.expires_at, r.created_at, r.fulfilled_at
         FROM reservations r
         JOIN branches b ON b.id = r.branch_id
         LEFT JOIN customers c ON c.id = r.customer_id
         JOIN medications m ON m.id = r.medication_id
        WHERE ${where.join(' AND ')}
        ORDER BY r.created_at DESC
        LIMIT $${i} OFFSET $${i + 1}`,
      [...params, pg.limit, pg.offset],
    );
    return { items: rows, meta: { ...pg, total: count.rows[0].total } };
  },

  async createReservation(pharmacyId, { branchId, customerId = null, medicationId, quantity, expiresAt = null }, user) {
    return withTransaction(pharmacyId, async (client) => {
      const med = await client.query(
        'SELECT id, name, status FROM medications WHERE id = $1 AND pharmacy_id = $2',
        [medicationId, pharmacyId],
      );
      if (!med.rows[0]) throw new NotFoundError('Médicament introuvable');
      if (med.rows[0].status !== 'available') throw new AppError(`${med.rows[0].name} n'est pas disponible`, 409, 'NOT_SALEABLE');

      // Sélection FEFO des lots à réserver
      const lots = await selectLots(client, branchId, medicationId, pharmacyId, quantity);

      const id = uuid();
      await client.query(
        `INSERT INTO reservations (id, pharmacy_id, branch_id, customer_id, medication_id, quantity, status, expires_at)
         VALUES ($1,$2,$3,$4,$5,$6,'pending',COALESCE($7, now() + interval '48 hours'))`,
        [id, pharmacyId, branchId, customerId ?? null, medicationId, quantity, expiresAt ?? null],
      );

      for (const lot of lots) {
        await insertMovement(client, {
          pharmacyId, branchId, medicationId, lotId: lot.lot_id,
          type: 'reservation', quantity: lot.quantity, unitCost: 0,
          referenceType: 'reservation', referenceId: id, userId: user?.id,
        });
      }

      await auditLog({ pharmacyId, userId: user?.id, action: 'create', module: 'sales', entity: 'reservation', entityId: id, newValues: { medicationId, quantity } });
      return this.getReservation(pharmacyId, id);
    });
  },

  async getReservation(pharmacyId, id) {
    const { rows } = await query(
      `SELECT r.id, r.branch_id, b.name AS branch_name, r.customer_id, c.name AS customer_name,
              r.medication_id, m.name AS medication_name, r.quantity, r.status,
              r.expires_at, r.created_at, r.fulfilled_at
         FROM reservations r
         JOIN branches b ON b.id = r.branch_id
         LEFT JOIN customers c ON c.id = r.customer_id
         JOIN medications m ON m.id = r.medication_id
        WHERE r.id = $1 AND r.pharmacy_id = $2`,
      [id, pharmacyId],
    );
    if (!rows[0]) throw new NotFoundError('Réservation introuvable');
    return rows[0];
  },

  async releaseReservation(pharmacyId, id, user) {
    return withTransaction(pharmacyId, async (client) => {
      const { rows } = await client.query(
        `SELECT id, branch_id, medication_id, quantity, status FROM reservations
          WHERE id = $1 AND pharmacy_id = $2`, [id, pharmacyId],
      );
      if (!rows[0]) throw new NotFoundError('Réservation introuvable');
      const res = rows[0];
      if (!['pending', 'ready'].includes(res.status)) {
        throw new AppError(`Réservation déjà ${res.status}`, 409, 'INVALID_STATE');
      }

      // Libère la quantité réservée (sur les balances concernées)
      const balances = await client.query(
        `SELECT lot_id, reserved_quantity FROM stock_balances
          WHERE branch_id = $1 AND medication_id = $2 AND pharmacy_id = $3
            AND reserved_quantity > 0 ORDER BY updated_at`,
        [res.branch_id, res.medication_id, pharmacyId],
      );
      let toRelease = Number(res.quantity);
      for (const bal of balances.rows) {
        if (toRelease <= 0) break;
        const qty = Math.min(toRelease, Number(bal.reserved_quantity));
        if (qty > 0) {
          await insertMovement(client, {
            pharmacyId, branchId: res.branch_id, medicationId: res.medication_id,
            lotId: bal.lot_id, type: 'release', quantity: qty, unitCost: 0,
            referenceType: 'reservation', referenceId: id, userId: user?.id,
          });
          toRelease -= qty;
        }
      }

      await client.query(
        `UPDATE reservations SET status = 'cancelled', fulfilled_at = now() WHERE id = $1`, [id],
      );
      await auditLog({ pharmacyId, userId: user?.id, action: 'release', module: 'sales', entity: 'reservation', entityId: id, newValues: { status: 'cancelled' } });
      return this.getReservation(pharmacyId, id);
    });
  },
};
