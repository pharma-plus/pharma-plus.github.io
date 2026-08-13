import { Router } from 'express';
import Joi from 'joi';
import { validate } from '../../middleware/validate.js';
import { requireAuth, requirePerm } from '../../middleware/auth.js';
import { wrap } from '../../middleware/error.js';
import { ok, created, noContent } from '../../utils/response.js';
import { query, withTransaction } from '../../db/pool.js';
import { auditLog } from '../../middleware/audit.js';
import { NotFoundError, ConflictError } from '../../utils/errors.js';
import { uuid } from '../../utils/crypto.js';

const router = Router();
router.use(requireAuth);

/** Rôles disponibles pour la pharmacie : rôles système clonés + personnalisés. */
async function listRoles(pharmacyId) {
  const { rows } = await query(
    `SELECT r.id, r.name, r.code, r.is_system,
            (SELECT count(*)::int FROM role_permissions rp WHERE rp.role_id = r.id) AS nb_permissions
       FROM roles r
      WHERE r.pharmacy_id = $1 OR r.pharmacy_id IS NULL
      ORDER BY r.is_system DESC, r.name`,
    [pharmacyId],
  );
  return rows;
}

router.get('/', requirePerm('users:view'), wrap(async (req, res) => {
  const roles = await listRoles(req.user.pharmacyId);
  return ok(res, roles);
}));

router.get('/permissions', requirePerm('users:view'), wrap(async (_req, res) => {
  const { rows } = await query(
    `SELECT code, name, module FROM permissions ORDER BY module, code`,
  );
  // Groupé par module
  const grouped = rows.reduce((acc, p) => {
    (acc[p.module] ||= []).push(p);
    return acc;
  }, {});
  return ok(res, grouped);
}));

router.get('/:id/permissions', requirePerm('users:view'), wrap(async (req, res) => {
  const { rows } = await query(
    `SELECT permission_code FROM role_permissions WHERE role_id = $1`, [req.params.id],
  );
  return ok(res, rows.map((r) => r.permission_code));
}));

router.post('/', requirePerm('users:create'), validate({
  body: Joi.object({
    name: Joi.string().max(80).required(),
    permissions: Joi.array().items(Joi.string()).default([]),
  }),
}), wrap(async (req, res) => {
  const role = await withTransaction(req.user.pharmacyId, async (client) => {
    const code = req.body.name.toLowerCase().replace(/[^a-z0-9]+/g, '_').slice(0, 50);
    const existing = await client.query(
      'SELECT id FROM roles WHERE pharmacy_id = $1 AND code = $2',
      [req.user.pharmacyId, code],
    );
    if (existing.rows[0]) throw new ConflictError('Un rôle avec ce nom existe déjà');

    const id = uuid();
    await client.query(
      `INSERT INTO roles (id, pharmacy_id, name, code, is_system)
       VALUES ($1,$2,$3,$4, false)`,
      [id, req.user.pharmacyId, req.body.name, code],
    );
    if (req.body.permissions.length) {
      for (const perm of req.body.permissions) {
        await client.query(
          `INSERT INTO role_permissions (role_id, permission_code) VALUES ($1,$2)
           ON CONFLICT DO NOTHING`,
          [id, perm],
        );
      }
    }
    return { id, name: req.body.name, code, is_system: false };
  });

  await auditLog({
    pharmacyId: req.user.pharmacyId, userId: req.user.id,
    action: 'create', module: 'roles', entity: 'role', entityId: role.id, newValues: role,
  });
  return created(res, role);
}));

router.put('/:id/permissions', requirePerm('users:edit'), validate({
  body: Joi.object({ permissions: Joi.array().items(Joi.string()).required() }),
}), wrap(async (req, res) => {
  const role = await query(
    'SELECT * FROM roles WHERE id = $1 AND pharmacy_id = $2',
    [req.params.id, req.user.pharmacyId],
  );
  if (!role.rows[0]) throw new NotFoundError('Rôle introuvable');
  if (role.rows[0].is_system) {
    return res.status(403).json({
      success: false,
      error: { code: 'FORBIDDEN', message: 'Les rôles système ne peuvent pas être modifiés' },
    });
  }

  await withTransaction(req.user.pharmacyId, async (client) => {
    await client.query('DELETE FROM role_permissions WHERE role_id = $1', [req.params.id]);
    for (const perm of req.body.permissions) {
      await client.query(
        'INSERT INTO role_permissions (role_id, permission_code) VALUES ($1,$2) ON CONFLICT DO NOTHING',
        [req.params.id, perm],
      );
    }
  });

  await auditLog({
    pharmacyId: req.user.pharmacyId, userId: req.user.id,
    action: 'edit', module: 'roles', entity: 'role', entityId: req.params.id,
    newValues: { permissions: req.body.permissions },
  });
  return ok(res, { message: 'Permissions mises à jour' });
}));

router.delete('/:id', requirePerm('users:delete'), wrap(async (req, res) => {
  const role = await query(
    'SELECT is_system FROM roles WHERE id = $1 AND pharmacy_id = $2',
    [req.params.id, req.user.pharmacyId],
  );
  if (!role.rows[0]) throw new NotFoundError('Rôle introuvable');
  if (role.rows[0].is_system) {
    return res.status(403).json({
      success: false,
      error: { code: 'FORBIDDEN', message: 'Les rôles système ne peuvent pas être supprimés' },
    });
  }
  await query('DELETE FROM roles WHERE id = $1 AND pharmacy_id = $2',
    [req.params.id, req.user.pharmacyId]);
  await auditLog({
    pharmacyId: req.user.pharmacyId, userId: req.user.id,
    action: 'delete', module: 'roles', entity: 'role', entityId: req.params.id,
  });
  return noContent(res);
}));

export const rolesRouter = router;
