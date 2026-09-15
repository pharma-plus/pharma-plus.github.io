import { query } from '../../db/pool.js';
import { auditLog } from '../../middleware/audit.js';
import { NotFoundError } from '../../utils/errors.js';
import { paginate } from '../../utils/response.js';

export const supportService = {
  async list(pharmacyId, { page = 1, limit = 20, status, priority }) {
    const pg = paginate(page, limit);
    const where = ['t.pharmacy_id = $1'];
    const params = [pharmacyId];
    let i = 2;
    if (status) { where.push(`t.status = $${i}`); params.push(status); i++; }
    if (priority) { where.push(`t.priority = $${i}`); params.push(priority); i++; }
    const count = await query(`SELECT count(*)::int AS total FROM support_tickets t WHERE ${where.join(' AND ')}`, params);
    const { rows } = await query(
      `SELECT t.*, u.first_name, u.last_name,
              (SELECT count(*)::int FROM support_messages sm WHERE sm.ticket_id = t.id) AS nb_messages
         FROM support_tickets t LEFT JOIN users u ON u.id = t.user_id
        WHERE ${where.join(' AND ')}
        ORDER BY t.created_at DESC LIMIT $${i} OFFSET $${i + 1}`,
      [...params, pg.limit, pg.offset],
    );
    return { items: rows, meta: { ...pg, total: count.rows[0].total } };
  },

  async get(pharmacyId, id) {
    const { rows } = await query(
      `SELECT t.*, u.first_name, u.last_name
         FROM support_tickets t LEFT JOIN users u ON u.id = t.user_id
        WHERE t.id = $1 AND t.pharmacy_id = $2`,
      [id, pharmacyId],
    );
    if (!rows[0]) throw new NotFoundError('Ticket introuvable');
    const { rows: messages } = await query(
      'SELECT id, author_type, author_id, message, created_at FROM support_messages WHERE ticket_id = $1 ORDER BY created_at',
      [id],
    );
    return { ...rows[0], messages };
  },

  async create(pharmacyId, data, actor) {
    const { rows } = await query(
      `INSERT INTO support_tickets (pharmacy_id, user_id, subject, priority, status)
       VALUES ($1,$2,$3,$4,'open')
       RETURNING *`,
      [pharmacyId, actor?.id, data.subject, data.priority ?? 'normal'],
    );
    if (data.message) {
      await query(
        `INSERT INTO support_messages (ticket_id, pharmacy_id, author_type, author_id, message)
         VALUES ($1,$2,'pharmacy',$3,$4)`,
        [rows[0].id, pharmacyId, actor?.id, data.message],
      );
    }
    await auditLog({ pharmacyId, userId: actor?.id, action: 'create', module: 'support', entity: 'support_ticket', entityId: rows[0].id, newValues: { subject: data.subject } });
    return this.get(pharmacyId, rows[0].id);
  },

  async addMessage(pharmacyId, id, data, actor) {
    await this.get(pharmacyId, id);
    await query(
      `UPDATE support_tickets SET status = CASE WHEN status = 'closed' THEN 'in_progress' ELSE status END
        WHERE id = $1`,
      [id],
    );
    const { rows } = await query(
      `INSERT INTO support_messages (ticket_id, pharmacy_id, author_type, author_id, message)
       VALUES ($1,$2,'pharmacy',$3,$4) RETURNING *`,
      [id, pharmacyId, actor?.id, data.message],
    );
    await auditLog({ pharmacyId, userId: actor?.id, action: 'message', module: 'support', entity: 'support_ticket', entityId: id, newValues: { message: data.message } });
    return rows[0];
  },

  async updateStatus(pharmacyId, id, status, actor) {
    await this.get(pharmacyId, id);
    const { rows } = await query(
      `UPDATE support_tickets SET status = $1,
              resolved_at = CASE WHEN $1 = 'resolved' THEN now() ELSE resolved_at END
        WHERE id = $2 RETURNING *`,
      [status, id],
    );
    await auditLog({ pharmacyId, userId: actor?.id, action: 'update_status', module: 'support', entity: 'support_ticket', entityId: id, newValues: { status } });
    return rows[0];
  },
};
