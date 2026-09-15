import { query } from '../../db/pool.js';
import { auditLog } from '../../middleware/audit.js';
import { paginate } from '../../utils/response.js';

export const notificationsService = {
  async list(pharmacyId, { page = 1, limit = 20, userId, unreadOnly }) {
    const pg = paginate(page, limit);
    const where = ['n.pharmacy_id = $1'];
    const params = [pharmacyId];
    let i = 2;
    if (userId) { where.push(`n.user_id = $${i}`); params.push(userId); i++; }
    if (unreadOnly) { where.push(`n.read_at IS NULL`); }
    const count = await query(`SELECT count(*)::int AS total FROM notifications n WHERE ${where.join(' AND ')}`, params);
    const { rows } = await query(
      `SELECT n.id, n.user_id, n.type, n.title, n.message, n.data, n.read_at, n.created_at
         FROM notifications n
        WHERE ${where.join(' AND ')}
        ORDER BY n.created_at DESC
        LIMIT $${i} OFFSET $${i + 1}`,
      [...params, pg.limit, pg.offset],
    );
    const { rows: unread } = await query(
      `SELECT count(*)::int AS total FROM notifications n WHERE ${where.join(' AND ')} AND n.read_at IS NULL`,
      params,
    );
    return { items: rows, meta: { ...pg, total: count.rows[0].total, unread: unread[0].total } };
  },

  async markRead(pharmacyId, id, userId) {
    const { rows } = await query(
      `UPDATE notifications SET read_at = now()
        WHERE id = $1 AND pharmacy_id = $2 AND ($3::uuid IS NULL OR user_id = $3 OR user_id IS NULL)
        RETURNING *`,
      [id, pharmacyId, userId],
    );
    return rows[0] ?? null;
  },

  async markAllRead(pharmacyId, userId) {
    await query(
      `UPDATE notifications SET read_at = now()
        WHERE pharmacy_id = $1 AND read_at IS NULL
          AND ($2::uuid IS NULL OR user_id = $2 OR user_id IS NULL)`,
      [pharmacyId, userId],
    );
    return { ok: true };
  },

  async notify({ pharmacyId, userId = null, type = 'system', title, message = null, data = null }) {
    const { rows } = await query(
      `INSERT INTO notifications (pharmacy_id, user_id, type, title, message, data)
       VALUES ($1,$2,$3,$4,$5,$6) RETURNING *`,
      [pharmacyId, userId, type, title, message, data ? JSON.stringify(data) : null],
    );
    return rows[0];
  },

  /** Alertes automatiques de stock (expirations, seuils). */
  async stockAlerts(pharmacyId) {
    const { rows } = await query(
      `SELECT 'expiring' AS alert_type, m.id, m.name, l.lot_number, l.expiry_date,
              COALESCE(b.quantity, 0)::numeric(12,3) AS quantity, l.id AS lot_id
         FROM lots l
         JOIN medications m ON m.id = l.medication_id
         LEFT JOIN stock_balances b ON b.lot_id = l.id AND b.pharmacy_id = $1
        WHERE l.pharmacy_id = $1 AND l.expiry_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '90 days'
       UNION ALL
       SELECT 'low_stock' AS alert_type, m.id, m.name, NULL, NULL,
              COALESCE(SUM(sb.quantity), 0)::numeric(12,3) AS quantity, NULL
         FROM medications m
         LEFT JOIN stock_balances sb ON sb.medication_id = m.id AND sb.pharmacy_id = $1
        WHERE m.pharmacy_id = $1 AND m.status = 'available'
        GROUP BY m.id, m.name, m.min_stock
        HAVING COALESCE(SUM(sb.quantity), 0) <= COALESCE(m.min_stock, 0)
       ORDER BY alert_type, expiry_date NULLS LAST, quantity
       LIMIT 200`,
      [pharmacyId],
    );
    return rows;
  },
};
