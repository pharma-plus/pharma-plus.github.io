import { query } from '../../db/pool.js';
import { auditLog } from '../../middleware/audit.js';
import { NotFoundError } from '../../utils/errors.js';
import { uuid } from '../../utils/crypto.js';
import { paginate } from '../../utils/response.js';

export const suppliersService = {
  async list(pharmacyId, { page = 1, limit = 20, q, city, status }) {
    const pg = paginate(page, limit);
    const where = ['s.pharmacy_id = $1'];
    const params = [pharmacyId];
    let i = 2;
    if (q) { where.push(`(s.name ILIKE $${i} OR s.contact_name ILIKE $${i} OR s.phone ILIKE $${i})`); params.push(`%${q}%`); i++; }
    if (city) { where.push(`s.city ILIKE $${i}`); params.push(`%${city}%`); i++; }
    if (status) { where.push(`s.status = $${i}`); params.push(status); i++; }

    const count = await query(`SELECT count(*)::int AS total FROM suppliers s WHERE ${where.join(' AND ')}`, params);
    const { rows } = await query(
      `SELECT s.id, s.name, s.contact_name, s.phone, s.whatsapp, s.email, s.city,
              s.payment_terms, s.delivery_delay, s.rating, s.status, s.created_at,
              (SELECT count(*)::int FROM purchase_orders po WHERE po.supplier_id = s.id) AS nb_orders,
              (SELECT COALESCE(sum(po.total), 0)::numeric(14,2) FROM purchase_orders po
                WHERE po.supplier_id = s.id AND po.status IN ('received','partial','confirmed')) AS total_purchases
         FROM suppliers s
        WHERE ${where.join(' AND ')}
        ORDER BY s.name
        LIMIT $${i} OFFSET $${i + 1}`,
      [...params, pg.limit, pg.offset],
    );
    return { items: rows, meta: { ...pg, total: count.rows[0].total } };
  },

  async get(pharmacyId, id) {
    const { rows } = await query(
      `SELECT s.*,
              (SELECT COALESCE(sum(po.total),0)::numeric(14,2) FROM purchase_orders po
                WHERE po.supplier_id = s.id AND po.status IN ('received','partial','confirmed')) AS total_purchases,
              (SELECT count(*)::int FROM purchase_orders po WHERE po.supplier_id = s.id) AS nb_orders
         FROM suppliers s WHERE s.id = $1 AND s.pharmacy_id = $2`,
      [id, pharmacyId],
    );
    if (!rows[0]) throw new NotFoundError('Fournisseur introuvable');
    const supplier = rows[0];

    const [orders, payments] = await Promise.all([
      query(
        `SELECT po.id, po.number, po.status, po.order_date, po.total, po.created_at
           FROM purchase_orders po WHERE po.supplier_id = $1 AND po.pharmacy_id = $2
          ORDER BY po.created_at DESC LIMIT 50`, [id, pharmacyId]),
      query(
        `SELECT sp.id, sp.amount, sp.payment_date, sp.method, sp.reference
           FROM supplier_payments sp WHERE sp.supplier_id = $1 AND sp.pharmacy_id = $2
          ORDER BY sp.payment_date DESC LIMIT 50`, [id, pharmacyId]),
    ]);
    return { ...supplier, orders: orders.rows, payments: payments.rows };
  },

  async create(pharmacyId, data, actor) {
    const id = uuid();
    await query(
      `INSERT INTO suppliers (id, pharmacy_id, name, contact_name, phone, whatsapp, email,
                              address, city, website, payment_terms, delivery_delay, notes)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)`,
      [id, pharmacyId, data.name, data.contact_name ?? null, data.phone ?? null,
       data.whatsapp ?? null, data.email ?? null, data.address ?? null, data.city ?? null,
       data.website ?? null, data.payment_terms ?? null, data.delivery_delay ?? null,
       data.notes ?? null],
    );
    await auditLog({ pharmacyId, userId: actor?.id, action: 'create', module: 'suppliers', entity: 'supplier', entityId: id, newValues: { name: data.name } });
    return this.get(pharmacyId, id);
  },

  async update(pharmacyId, id, data, actor) {
    const existing = await this.get(pharmacyId, id);
    const fields = [];
    const params = [id, pharmacyId];
    let i = 3;
    const map = {
      name: 'name', contact_name: 'contact_name', phone: 'phone', whatsapp: 'whatsapp',
      email: 'email', address: 'address', city: 'city', website: 'website',
      payment_terms: 'payment_terms', delivery_delay: 'delivery_delay',
      rating: 'rating', notes: 'notes', status: 'status',
    };
    for (const [key, value] of Object.entries(data)) {
      if (!(key in map) || value === undefined) continue;
      fields.push(`${map[key]} = $${i}`);
      params.push(value);
      i++;
    }
    if (fields.length) {
      await query(`UPDATE suppliers SET ${fields.join(', ')} WHERE id = $1 AND pharmacy_id = $2`, params);
    }
    await auditLog({ pharmacyId, userId: actor?.id, action: 'edit', module: 'suppliers', entity: 'supplier', entityId: id, oldValues: { name: existing.name }, newValues: data });
    return this.get(pharmacyId, id);
  },

  async remove(pharmacyId, id, actor) {
    const existing = await this.get(pharmacyId, id);
    await query('DELETE FROM suppliers WHERE id = $1 AND pharmacy_id = $2', [id, pharmacyId]);
    await auditLog({ pharmacyId, userId: actor?.id, action: 'delete', module: 'suppliers', entity: 'supplier', entityId: id, newValues: { name: existing.name } });
  },

  async addPayment(pharmacyId, { supplierId, amount, paymentDate, method, reference, notes }, actor) {
    await this.get(pharmacyId, supplierId);
    const id = uuid();
    await query(
      `INSERT INTO supplier_payments (id, pharmacy_id, supplier_id, amount, payment_date, method, reference, notes, created_by)
       VALUES ($1,$2,$3,$4,COALESCE($5,CURRENT_DATE),$6,$7,$8,$9)`,
      [id, pharmacyId, supplierId, amount, paymentDate ?? null, method, reference ?? null, notes ?? null, actor?.id],
    );
    await auditLog({ pharmacyId, userId: actor?.id, action: 'payment', module: 'suppliers', entity: 'supplier', entityId: supplierId, newValues: { amount, method } });
    return { id, amount, method };
  },

  /** Performance des fournisseurs (rapports). */
  async performance(pharmacyId) {
    const { rows } = await query(
      `SELECT s.id, s.name,
              count(po.id) AS nb_orders,
              COALESCE(sum(CASE WHEN po.status IN ('received','partial') THEN po.total END), 0)::numeric(14,2) AS received_total,
              count(*) FILTER (WHERE po.status IN ('sent','confirmed')) AS pending_orders,
              COALESCE(avg(CASE WHEN po.expected_date IS NOT NULL AND po.received_date IS NOT NULL
                                THEN (po.received_date::date - po.expected_date) END), 0)::numeric(5,1) AS avg_delay_days,
              COALESCE(sum(sp.amount), 0)::numeric(14,2) AS total_paid,
              s.rating
         FROM suppliers s
         LEFT JOIN purchase_orders po ON po.supplier_id = s.id AND po.pharmacy_id = s.pharmacy_id
         LEFT JOIN supplier_payments sp ON sp.supplier_id = s.id AND sp.pharmacy_id = s.pharmacy_id
        WHERE s.pharmacy_id = $1
        GROUP BY s.id, s.rating, s.name
        ORDER BY nb_orders DESC`,
      [pharmacyId],
    );
    return rows;
  },
};
