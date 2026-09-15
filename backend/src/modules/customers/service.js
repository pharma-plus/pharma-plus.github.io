import { query } from '../../db/pool.js';
import { auditLog } from '../../middleware/audit.js';
import { NotFoundError } from '../../utils/errors.js';
import { uuid } from '../../utils/crypto.js';
import { paginate } from '../../utils/response.js';

export const customersService = {
  async list(pharmacyId, { page = 1, limit = 20, q, status, hasCredit }) {
    const pg = paginate(page, limit);
    const where = ['c.pharmacy_id = $1'];
    const params = [pharmacyId];
    let i = 2;
    if (q) { where.push(`(c.name ILIKE $${i} OR c.phone ILIKE $${i} OR c.email ILIKE $${i})`); params.push(`%${q}%`); i++; }
    if (status) { where.push(`c.status = $${i}`); params.push(status); i++; }
    if (hasCredit) { where.push(`c.credit_balance > 0`); }

    const count = await query(`SELECT count(*)::int AS total FROM customers c WHERE ${where.join(' AND ')}`, params);
    const { rows } = await query(
      `SELECT c.id, c.name, c.phone, c.whatsapp, c.email, c.city, c.loyalty_points,
              c.credit_limit, c.credit_balance, c.status, c.created_at,
              (SELECT count(*)::int FROM sales s WHERE s.customer_id = c.id) AS nb_sales,
              (SELECT COALESCE(sum(s.total),0)::numeric(14,2) FROM sales s
                WHERE s.customer_id = c.id AND s.status='completed') AS total_spent
         FROM customers c
        WHERE ${where.join(' AND ')}
        ORDER BY c.name
        LIMIT $${i} OFFSET $${i + 1}`,
      [...params, pg.limit, pg.offset],
    );
    return { items: rows, meta: { ...pg, total: count.rows[0].total } };
  },

  async get(pharmacyId, id) {
    const { rows } = await query(
      `SELECT c.* FROM customers c WHERE c.id = $1 AND c.pharmacy_id = $2`,
      [id, pharmacyId],
    );
    if (!rows[0]) throw new NotFoundError('Client introuvable');
    const customer = rows[0];
    const [sales, invoices] = await Promise.all([
      query(
        `SELECT s.id, s.number, s.total, s.created_at, s.status, s.sale_type
           FROM sales s WHERE s.customer_id = $1 AND s.pharmacy_id = $2
          ORDER BY s.created_at DESC LIMIT 100`, [id, pharmacyId]),
      query(
        `SELECT i.id, i.number, i.type, i.total, i.paid_amount, i.status, i.due_date
           FROM invoices i WHERE i.customer_id = $1 AND i.pharmacy_id = $2
          ORDER BY i.issue_date DESC LIMIT 50`, [id, pharmacyId]),
    ]);
    return { ...customer, sales: sales.rows, invoices: invoices.rows };
  },

  async history(pharmacyId, id, { page = 1, limit = 20 }) {
    await this.get(pharmacyId, id);
    const pg = paginate(page, limit);
    const { rows } = await query(
      `SELECT s.id, s.number, s.sale_type, s.status, s.total, s.created_at,
              s.paid_amount, s.change_amount,
              (SELECT count(*)::int FROM sale_items si WHERE si.sale_id = s.id) AS nb_lines,
              (SELECT COALESCE(sum(p.amount),0)::numeric(14,2) FROM payments p WHERE p.sale_id = s.id) AS total_paid
         FROM sales s
        WHERE s.customer_id = $1 AND s.pharmacy_id = $2
        ORDER BY s.created_at DESC
        LIMIT $${3} OFFSET $${4}`,
      [id, pharmacyId, pg.limit, pg.offset],
    );
    const [reservations, returns] = await Promise.all([
      query(
        `SELECT r.id, r.medication_id, m.name AS medication_name, r.quantity, r.status, r.created_at
           FROM reservations r JOIN medications m ON m.id = r.medication_id
          WHERE r.customer_id = $1 AND r.pharmacy_id = $2
          ORDER BY r.created_at DESC LIMIT 50`, [id, pharmacyId]),
      query(
        `SELECT sr.id, sr.number, sr.return_type, sr.reason, sr.total_refund, sr.returned_at
           FROM sale_returns sr WHERE sr.sale_id IN
             (SELECT s.id FROM sales s WHERE s.customer_id = $1 AND s.pharmacy_id = $2)
          ORDER BY sr.returned_at DESC LIMIT 50`, [id, pharmacyId]),
    ]);
    return { sales: rows, reservations: reservations.rows, returns: returns.rows, meta: pg };
  },

  async create(pharmacyId, data, actor) {
    const id = uuid();
    await query(
      `INSERT INTO customers (id, pharmacy_id, name, phone, whatsapp, email, address,
                              birth_date, loyalty_points, credit_limit, notes)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)`,
      [id, pharmacyId, data.name, data.phone ?? null, data.whatsapp ?? null,
       data.email ?? null, data.address ?? null, data.birth_date ?? null,
       data.loyalty_points ?? 0, data.credit_limit ?? 0, data.notes ?? null],
    );
    await auditLog({ pharmacyId, userId: actor?.id, action: 'create', module: 'customers', entity: 'customer', entityId: id, newValues: { name: data.name } });
    return this.get(pharmacyId, id);
  },

  async update(pharmacyId, id, data, actor) {
    const existing = await this.get(pharmacyId, id);
    const fields = [];
    const params = [id, pharmacyId];
    let i = 3;
    const map = {
      name: 'name', phone: 'phone', whatsapp: 'whatsapp', email: 'email',
      address: 'address', birth_date: 'birth_date', credit_limit: 'credit_limit',
      notes: 'notes', status: 'status',
    };
    for (const [key, value] of Object.entries(data)) {
      if (!(key in map) || value === undefined) continue;
      fields.push(`${map[key]} = $${i}`);
      params.push(value);
      i++;
    }
    if (fields.length) {
      await query(`UPDATE customers SET ${fields.join(', ')} WHERE id = $1 AND pharmacy_id = $2`, params);
    }
    await auditLog({ pharmacyId, userId: actor?.id, action: 'edit', module: 'customers', entity: 'customer', entityId: id, oldValues: { name: existing.name }, newValues: data });
    return this.get(pharmacyId, id);
  },

  async remove(pharmacyId, id, actor) {
    const existing = await this.get(pharmacyId, id);
    await query('DELETE FROM customers WHERE id = $1 AND pharmacy_id = $2', [id, pharmacyId]);
    await auditLog({ pharmacyId, userId: actor?.id, action: 'delete', module: 'customers', entity: 'customer', entityId: id, newValues: { name: existing.name } });
  },
};
