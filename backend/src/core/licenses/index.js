import { Router } from 'express';
import Joi from 'joi';
import { validate } from '../../middleware/validate.js';
import { requireAuth, requireSuperAdmin } from '../../middleware/auth.js';
import { wrap } from '../../middleware/error.js';
import { ok, created } from '../../utils/response.js';
import { query, withTransaction } from '../../db/pool.js';
import { auditLog } from '../../middleware/audit.js';
import { NotFoundError } from '../../utils/errors.js';

const router = Router();
router.use(requireAuth);

// --- Pharmacie connectée : état de sa licence ---
router.get('/me', wrap(async (req, res) => {
  const { rows } = await query(
    `SELECT id, type, status, billing_cycle, activation_date, expiry_date,
            max_users, max_branches, modules,
            (expiry_date - now()) < interval '30 days' AS expiring_soon,
            expiry_date < now() AS expired
       FROM licenses
      WHERE pharmacy_id = $1
      ORDER BY created_at DESC`,
    [req.user.pharmacyId],
  );
  return ok(res, rows);
}));

// --- Super Administrateur : gestion complète des licences ---
router.get('/', requireSuperAdmin, validate({
  query: Joi.object({
    pharmacyId: Joi.string().uuid(),
    status: Joi.string().valid('active', 'suspended', 'expired', 'cancelled'),
    page: Joi.number().integer().min(1).default(1),
    limit: Joi.number().integer().min(1).max(200).default(20),
  }),
}), wrap(async (req, res) => {
  const where = ['1=1'];
  const params = [];
  let i = 1;
  if (req.query.pharmacyId) { where.push(`pharmacy_id = $${i}`); params.push(req.query.pharmacyId); i++; }
  if (req.query.status) { where.push(`status = $${i}`); params.push(req.query.status); i++; }
  const limit = Math.min(parseInt(req.query.limit, 10) || 20, 200);
  const page = Math.max(parseInt(req.query.page, 10) || 1, 1);

  const count = await query(`SELECT count(*)::int AS total FROM licenses WHERE ${where.join(' AND ')}`, params);
  const { rows } = await query(
    `SELECT l.*, p.name AS pharmacy_name
       FROM licenses l JOIN pharmacies p ON p.id = l.pharmacy_id
      WHERE ${where.join(' AND ')}
      ORDER BY l.created_at DESC
      LIMIT $${i} OFFSET $${i + 1}`,
    [...params, limit, (page - 1) * limit],
  );
  return ok(res, rows, {
    page, limit, total: count.rows[0].total,
    pages: Math.max(1, Math.ceil(count.rows[0].total / limit)),
  });
}));

router.post('/', requireSuperAdmin, validate({
  body: Joi.object({
    pharmacyId: Joi.string().uuid().required(),
    type: Joi.string().valid('trial', 'standard', 'professional', 'enterprise').required(),
    billing_cycle: Joi.string().valid('monthly', 'annual').default('monthly'),
    duration_days: Joi.number().integer().min(1).max(3650).required(),
    max_users: Joi.number().integer().min(1).default(1),
    max_branches: Joi.number().integer().min(1).default(1),
    modules: Joi.object(),
  }),
}), wrap(async (req, res) => {
  const license = await withTransaction(null, async (client) => {
    const pharma = await client.query('SELECT id FROM pharmacies WHERE id = $1', [req.body.pharmacyId]);
    if (!pharma.rows[0]) throw new NotFoundError('Pharmacie introuvable');

    const expiry = new Date(Date.now() + req.body.duration_days * 24 * 3600 * 1000);
    const { rows } = await client.query(
      `INSERT INTO licenses (pharmacy_id, type, status, billing_cycle, activation_date,
                             expiry_date, max_users, max_branches, modules)
       VALUES ($1,$2,'active',$3, now(), $4, $5, $6, $7)
       RETURNING *`,
      [req.body.pharmacyId, req.body.type, req.body.billing_cycle, expiry,
       req.body.max_users, req.body.max_branches, JSON.stringify(req.body.modules ?? {})],
    );
    return rows[0];
  });
  await auditLog({
    pharmacyId: req.body.pharmacyId, userId: req.user.id,
    action: 'create', module: 'licenses', entity: 'license', entityId: license.id,
    newValues: { type: license.type, expiry_date: license.expiry_date },
  });
  return created(res, license);
}));

router.post('/:id/status', requireSuperAdmin, validate({
  body: Joi.object({ status: Joi.string().valid('active', 'suspended', 'cancelled').required() }),
}), wrap(async (req, res) => {
  const { rows } = await query(
    `UPDATE licenses SET status = $1
      WHERE id = $2
     RETURNING *, (SELECT name FROM pharmacies WHERE id = pharmacy_id) AS pharmacy_name`,
    [req.body.status, req.params.id],
  );
  if (!rows[0]) throw new NotFoundError('Licence introuvable');
  if (req.body.status === 'suspended') {
    await query('UPDATE user_sessions SET revoked_at = now() WHERE pharmacy_id = $1', [rows[0].pharmacy_id]);
  }
  await auditLog({
    pharmacyId: rows[0].pharmacy_id, userId: req.user.id,
    action: 'status_change', module: 'licenses', entity: 'license', entityId: req.params.id,
    newValues: { status: req.body.status },
  });
  return ok(res, rows[0]);
}));

router.post('/:id/renew', requireSuperAdmin, validate({
  body: Joi.object({ days: Joi.number().integer().min(1).max(3650).required() }),
}), wrap(async (req, res) => {
  const { rows } = await query(
    `UPDATE licenses
        SET expiry_date = GREATEST(now(), expiry_date) + $1 * interval '1 day',
            status = 'active'
      WHERE id = $2
     RETURNING *`,
    [req.body.days, req.params.id],
  );
  if (!rows[0]) throw new NotFoundError('Licence introuvable');
  await auditLog({
    pharmacyId: rows[0].pharmacy_id, userId: req.user.id,
    action: 'renew', module: 'licenses', entity: 'license', entityId: req.params.id,
    newValues: { expiry_date: rows[0].expiry_date },
  });
  return ok(res, rows[0]);
}));

export const licensesRouter = router;
