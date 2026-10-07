import { query } from '../../db/pool.js';
import { auditLog } from '../../middleware/audit.js';
import { NotFoundError, ConflictError } from '../../utils/errors.js';
import { paginate } from '../../utils/response.js';

/**
 * Sessions de connexion utilisateur (appareils connectés).
 * Lecture seule sur les jetons : aucun mot de passe n'est régénéré ici —
 * la réinitialisation révocable consiste à invalider les sessions et à
 * forcer le changement de mot de passe à la prochaine connexion.
 */
export const userSessionService = {
  async listSessions(pharmacyId, { page = 1, limit = 20, active, userId } = {}) {
    const pg = paginate(page, limit);
    const where = ['s.pharmacy_id = $1'];
    const params = [pharmacyId];
    let i = 2;
    if (active === true || active === 'true') {
      where.push('s.revoked_at IS NULL AND s.expires_at > now()');
    } else if (active === false || active === 'false') {
      where.push('(s.revoked_at IS NOT NULL OR s.expires_at <= now())');
    }
    if (userId) { where.push(`s.user_id = $${i}`); params.push(userId); i++; }
    const count = await query(
      `SELECT count(*)::int AS total FROM user_sessions s WHERE ${where.join(' AND ')}`,
      params,
    );
    const { rows } = await query(
      `SELECT s.id, s.user_id, s.device_name, s.device_type, s.ip_address, s.user_agent,
              s.created_at, s.expires_at, s.revoked_at, s.last_used_at,
              u.first_name, u.last_name, u.email,
              (s.revoked_at IS NULL AND s.expires_at > now()) AS is_active
         FROM user_sessions s
         LEFT JOIN users u ON u.id = s.user_id
        WHERE ${where.join(' AND ')}
        ORDER BY s.last_used_at DESC
        LIMIT $${i} OFFSET $${i + 1}`,
      [...params, pg.limit, pg.offset],
    );
    return { items: rows, meta: { ...pg, total: count.rows[0].total } };
  },

  async getActiveSessions(pharmacyId) {
    const { rows } = await query(
      `SELECT s.id, s.user_id, s.device_name, s.device_type, s.ip_address, s.user_agent,
              s.created_at, s.expires_at, s.last_used_at,
              u.first_name, u.last_name, u.email
         FROM user_sessions s
         LEFT JOIN users u ON u.id = s.user_id
        WHERE s.pharmacy_id = $1 AND s.revoked_at IS NULL AND s.expires_at > now()
        ORDER BY s.last_used_at DESC`,
      [pharmacyId],
    );
    return rows;
  },

  /** Invalide la session cible + toutes celles de l'utilisateur et force le changement de mot de passe. */
  async resetPassword(sessionId, actor) {
    const { rows } = await query(
      `SELECT s.id, s.user_id, s.pharmacy_id, s.revoked_at
         FROM user_sessions s WHERE s.id = $1`,
      [sessionId],
    );
    const session = rows[0];
    if (!session) throw new NotFoundError('Session introuvable');
    if (session.pharmacy_id !== actor?.pharmacyId && !actor?.isSuperAdmin) {
      throw new NotFoundError('Session introuvable');
    }

    const { rows: userRows } = await query(
      'SELECT id, email FROM users WHERE id = $1',
      [session.user_id],
    );
    if (!userRows[0]) throw new NotFoundError('Utilisateur introuvable');
    if (userRows[0].id === actor?.id) {
      throw new ConflictError('Impossible de réinitialiser sa propre session');
    }

    const { rowCount } = await query(
      `UPDATE user_sessions SET revoked_at = now()
        WHERE user_id = $1 AND revoked_at IS NULL`,
      [session.user_id],
    );
    await query('UPDATE users SET must_change_password = true WHERE id = $1', [session.user_id]);
    await auditLog({
      pharmacyId: session.pharmacy_id, userId: actor?.id, action: 'reset_password',
      module: 'users', entity: 'user', entityId: session.user_id,
      oldValues: { sessionId },
      newValues: { revokedSessions: rowCount, mustChangePassword: true },
    });
    return {
      user: { id: userRows[0].id, email: userRows[0].email, mustChangePassword: true },
      revokedSessions: rowCount,
      message: 'Sessions invalidées : un nouveau mot de passe sera demandé à la prochaine connexion.',
    };
  },
};
