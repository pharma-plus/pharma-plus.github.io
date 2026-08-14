import { query } from '../../db/pool.js';
import { auditLog } from '../../middleware/audit.js';
import { NotFoundError, ValidationError } from '../../utils/errors.js';
import { paginate } from '../../utils/response.js';

/**
 * Sauvegardes : enregistrement de jobs. Le vrai travail (dump pg_dump,
 * chiffrement AES-256, upload S3) est délégué à un worker dédié.
 */
export const backupsService = {
  async list(pharmacyId, { page = 1, limit = 20, status }) {
    const pg = paginate(page, limit);
    const where = ['b.pharmacy_id = $1'];
    const params = [pharmacyId];
    let i = 2;
    if (status) { where.push(`b.status = $${i}`); params.push(status); i++; }
    const count = await query(`SELECT count(*)::int AS total FROM backups b WHERE ${where.join(' AND ')}`, params);
    const { rows } = await query(
      `SELECT b.*
         FROM backups b
        WHERE ${where.join(' AND ')}
        ORDER BY b.created_at DESC LIMIT $${i} OFFSET $${i + 1}`,
      [...params, pg.limit, pg.offset],
    );
    return { items: rows, meta: { ...pg, total: count.rows[0].total } };
  },

  async start(pharmacyId, data, actor) {
    const { rows } = await query(
      `INSERT INTO backups (pharmacy_id, type, scope, file_url, checksum, status)
       VALUES ($1, $2, $3, '', '', 'running')
       RETURNING id, type, scope, status, created_at`,
      [pharmacyId, data.type ?? 'manual', data.scope ?? 'full'],
    );
    await auditLog({ pharmacyId, userId: actor?.id, action: 'backup_start', module: 'backups', entity: 'backup', entityId: rows[0].id, newValues: { type: rows[0].type, scope: rows[0].scope } });
    return rows[0];
  },

  async markStatus(pharmacyId, id, status, error = null, actor = null) {
    const { rows } = await query(
      `UPDATE backups
          SET status = $1,
              error = $2,
              completed_at = CASE WHEN $1 IN ('completed','failed') THEN now() ELSE completed_at END,
              restored_at = CASE WHEN $1 = 'restoring' THEN now() ELSE restored_at END
        WHERE id = $3 AND pharmacy_id = $4
        RETURNING *`,
      [status, error, id, pharmacyId],
    );
    if (!rows[0]) throw new NotFoundError('Sauvegarde introuvable');
    await auditLog({ pharmacyId, userId: actor?.id ?? null, action: 'backup_' + status, module: 'backups', entity: 'backup', entityId: id, newValues: { status } });
    return rows[0];
  },

  async requestRestore(pharmacyId, id, actor) {
    const existing = await this.markStatus(pharmacyId, id, 'restoring', null, actor);
    if (!existing) throw new NotFoundError('Sauvegarde introuvable');
    return existing;
  },

  async verify(pharmacyId, id, actor) {
    return this.markStatus(pharmacyId, id, 'verified', null, actor);
  },

  async remove(pharmacyId, id, actor) {
    const { rows } = await query(
      `DELETE FROM backups WHERE id = $1 AND pharmacy_id = $2 AND status = 'completed'
       RETURNING id`,
      [id, pharmacyId],
    );
    if (!rows[0]) throw new ValidationError([{ field: 'id', message: 'Impossible de supprimer cette sauvegarde' }]);
    await auditLog({ pharmacyId, userId: actor?.id, action: 'backup_delete', module: 'backups', entity: 'backup', entityId: id });
  },

  /** Bilan global (super admin). */
  async globalStats() {
    const { rows } = await query(
      `SELECT status, count(*)::int AS total,
              COALESCE(sum(size_bytes), 0)::bigint AS total_bytes
         FROM backups GROUP BY status`,
    );
    return rows;
  },
};
