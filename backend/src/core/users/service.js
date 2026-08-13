import argon2 from 'argon2';
import { query, withTransaction } from '../../db/pool.js';
import { auditLog } from '../../middleware/audit.js';
import {
  NotFoundError, ConflictError, AppError, ForbiddenError,
} from '../../utils/errors.js';
import { sanitizeUser, uuid } from '../../utils/crypto.js';
import { paginate } from '../../utils/response.js';

function toPublic(row) {
  return {
    id: row.id, first_name: row.first_name, last_name: row.last_name,
    email: row.email, phone: row.phone, photo_url: row.photo_url,
    status: row.status, role_id: row.role_id, role_name: row.role_name,
    branch_id: row.branch_id, branch_name: row.branch_name,
    two_factor_enabled: row.two_factor_enabled, must_change_password: row.must_change_password,
    last_login_at: row.last_login_at, created_at: row.created_at,
  };
}

export const usersService = {
  async list(pharmacyId, { page = 1, limit = 20, q, status, roleId, branchId }) {
    const pg = paginate(page, limit);
    const where = ['u.pharmacy_id = $1'];
    const params = [pharmacyId];
    let i = 2;

    if (q) { where.push(`(u.first_name ILIKE $${i} OR u.last_name ILIKE $${i} OR u.email ILIKE $${i})`); params.push(`%${q}%`); i++; }
    if (status) { where.push(`u.status = $${i}`); params.push(status); i++; }
    if (roleId) { where.push(`u.role_id = $${i}`); params.push(roleId); i++; }
    if (branchId) { where.push(`u.branch_id = $${i}`); params.push(branchId); i++; }

    const count = await query(
      `SELECT count(*)::int AS total FROM users u WHERE ${where.join(' AND ')}`, params,
    );
    const { rows } = await query(
      `SELECT u.id, u.first_name, u.last_name, u.email, u.phone, u.photo_url,
              u.status, u.role_id, r.name AS role_name, u.branch_id, b.name AS branch_name,
              u.two_factor_enabled, u.must_change_password, u.last_login_at, u.created_at
         FROM users u
         LEFT JOIN roles r ON r.id = u.role_id
         LEFT JOIN branches b ON b.id = u.branch_id
        WHERE ${where.join(' AND ')}
        ORDER BY u.created_at DESC
        LIMIT $${i} OFFSET $${i + 1}`,
      [...params, pg.limit, pg.offset],
    );

    return { items: rows.map(toPublic), meta: { ...pg, total: count.rows[0].total } };
  },

  async get(pharmacyId, id) {
    const { rows } = await query(
      `SELECT u.*, r.name AS role_name, b.name AS branch_name
         FROM users u
         LEFT JOIN roles r ON r.id = u.role_id
         LEFT JOIN branches b ON b.id = u.branch_id
        WHERE u.id = $1 AND u.pharmacy_id = $2`,
      [id, pharmacyId],
    );
    if (!rows[0]) throw new NotFoundError('Utilisateur introuvable');
    return toPublic(rows[0]);
  },

  async create(pharmacyId, data, actor) {
    return withTransaction(pharmacyId, async (client) => {
      // Vérifie la limite d'utilisateurs de la licence
      const lic = await client.query(
        `SELECT max_users FROM licenses
          WHERE pharmacy_id = $1 AND status = 'active' AND expiry_date >= now()
          ORDER BY created_at DESC LIMIT 1`,
        [pharmacyId],
      );
      const maxUsers = lic.rows[0]?.max_users ?? 1;
      const current = await client.query(
        'SELECT count(*)::int AS n FROM users WHERE pharmacy_id = $1', [pharmacyId],
      );
      if (current.rows[0].n >= maxUsers) {
        throw new AppError('Limite d’utilisateurs de la licence atteinte', 403, 'LICENSE_LIMIT');
      }

      const role = await client.query(
        'SELECT id FROM roles WHERE id = $1 AND pharmacy_id = $2',
        [data.role_id, pharmacyId],
      );
      if (!role.rows[0]) throw new ForbiddenError('Rôle invalide pour cette pharmacie');

      const existing = await client.query(
        'SELECT id FROM users WHERE lower(email) = lower($1) AND pharmacy_id = $2',
        [data.email, pharmacyId],
      );
      if (existing.rows[0]) throw new ConflictError('Cet email est déjà utilisé');

      const passwordHash = await argon2.hash(data.password || 'ChangeMe123!', { type: argon2.argon2id });
      const id = uuid();
      await client.query(
        `INSERT INTO users (id, pharmacy_id, branch_id, role_id, first_name, last_name,
                            email, phone, photo_url, password_hash, must_change_password)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10, true)`,
        [id, pharmacyId, data.branch_id ?? null, data.role_id,
         data.first_name, data.last_name, data.email, data.phone ?? null,
         data.photo_url ?? null, passwordHash],
      );

      await auditLog({
        pharmacyId, userId: actor?.id, action: 'create', module: 'users',
        entity: 'user', entityId: id, newValues: { email: data.email },
      });

      return this.get(pharmacyId, id);
    });
  },

  async update(pharmacyId, id, data, actor) {
    const existing = await this.get(pharmacyId, id);
    const fields = [];
    const params = [id, pharmacyId];
    let i = 3;

    for (const [key, value] of Object.entries(data)) {
      const column = {
        first_name: 'first_name', last_name: 'last_name', phone: 'phone',
        photo_url: 'photo_url', branch_id: 'branch_id', status: 'status',
        role_id: 'role_id',
      }[key];
      if (!column || value === undefined) continue;
      fields.push(`${column} = $${i}`);
      params.push(value);
      i++;
    }
    if (!fields.length) return existing;

    await query(`UPDATE users SET ${fields.join(', ')} WHERE id = $1 AND pharmacy_id = $2`, params);
    await auditLog({
      pharmacyId, userId: actor?.id, action: 'edit', module: 'users',
      entity: 'user', entityId: id, oldValues: existing, newValues: data,
    });
    return this.get(pharmacyId, id);
  },

  async resetPassword(pharmacyId, id, newPassword, actor) {
    const user = await this.get(pharmacyId, id);
    const hash = await argon2.hash(newPassword, { type: argon2.argon2id });
    await query(
      `UPDATE users SET password_hash = $1, must_change_password = true, failed_attempts = 0, locked_until = NULL
        WHERE id = $2 AND pharmacy_id = $3`,
      [hash, id, pharmacyId],
    );
    await query('UPDATE user_sessions SET revoked_at = now() WHERE user_id = $1', [id]);
    await auditLog({
      pharmacyId, userId: actor?.id, action: 'reset_password', module: 'users',
      entity: 'user', entityId: id, newValues: { email: user.email },
    });
  },

  async setStatus(pharmacyId, id, status, actor) {
    const user = await this.get(pharmacyId, id);
    await query('UPDATE users SET status = $1 WHERE id = $2 AND pharmacy_id = $3',
      [status, id, pharmacyId]);
    if (status !== 'active') {
      await query('UPDATE user_sessions SET revoked_at = now() WHERE user_id = $1', [id]);
    }
    await auditLog({
      pharmacyId, userId: actor?.id, action: status === 'active' ? 'activate' : 'deactivate',
      module: 'users', entity: 'user', entityId: id, oldValues: { status: user.status }, newValues: { status },
    });
  },

  async remove(pharmacyId, id, actor) {
    const user = await this.get(pharmacyId, id);
    await query('UPDATE user_sessions SET revoked_at = now() WHERE user_id = $1', [id]);
    await query('DELETE FROM users WHERE id = $1 AND pharmacy_id = $2', [id, pharmacyId]);
    await auditLog({
      pharmacyId, userId: actor?.id, action: 'delete', module: 'users',
      entity: 'user', entityId: id, newValues: { email: user.email },
    });
  },
};
