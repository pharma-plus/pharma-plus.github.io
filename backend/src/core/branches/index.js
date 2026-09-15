import { Router } from 'express';
import Joi from 'joi';
import { validate } from '../../middleware/validate.js';
import { requireAuth, requirePerm } from '../../middleware/auth.js';
import { wrap } from '../../middleware/error.js';
import { ok, created, noContent } from '../../utils/response.js';
import { query, withTransaction } from '../../db/pool.js';
import { auditLog } from '../../middleware/audit.js';
import { NotFoundError, ConflictError, AppError } from '../../utils/errors.js';
import { uuid } from '../../utils/crypto.js';

const router = Router();
router.use(requireAuth);

const branchSchema = Joi.object({
  name: Joi.string().max(160).required(),
  code: Joi.string().max(20).required(),
  address: Joi.string().max(300).allow(null, ''),
  city: Joi.string().max(120).allow(null, ''),
  phone: Joi.string().max(30).allow(null, ''),
  is_main: Joi.boolean(),
  status: Joi.string().valid('active', 'inactive'),
});

router.get('/', requirePerm('users:view'), wrap(async (req, res) => {
  const { rows } = await query(
    `SELECT b.*,
            (SELECT count(*)::int FROM users u WHERE u.branch_id = b.id) AS nb_users
       FROM branches b WHERE b.pharmacy_id = $1 ORDER BY b.is_main DESC, b.name`,
    [req.user.pharmacyId],
  );
  return ok(res, rows);
}));

router.post('/', requirePerm('settings:edit'), validate({ body: branchSchema }),
  wrap(async (req, res) => {
    const branch = await withTransaction(req.user.pharmacyId, async (client) => {
      const lic = await client.query(
        `SELECT max_branches FROM licenses
          WHERE pharmacy_id = $1 AND status = 'active' AND expiry_date >= now()
          ORDER BY created_at DESC LIMIT 1`, [req.user.pharmacyId],
      );
      const maxBranches = lic.rows[0]?.max_branches ?? 1;
      const current = await client.query(
        'SELECT count(*)::int AS n FROM branches WHERE pharmacy_id = $1', [req.user.pharmacyId],
      );
      if (current.rows[0].n >= maxBranches) {
        throw new AppError('Limite de succursales de la licence atteinte', 403, 'LICENSE_LIMIT');
      }
      const existing = await client.query(
        'SELECT id FROM branches WHERE pharmacy_id = $1 AND code = $2',
        [req.user.pharmacyId, req.body.code],
      );
      if (existing.rows[0]) throw new ConflictError('Ce code de succursale existe déjà');

      const id = uuid();
      if (req.body.is_main) {
        await client.query(
          'UPDATE branches SET is_main = false WHERE pharmacy_id = $1', [req.user.pharmacyId],
        );
      }
      await client.query(
        `INSERT INTO branches (id, pharmacy_id, name, code, address, city, phone, is_main)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
        [id, req.user.pharmacyId, req.body.name, req.body.code,
         req.body.address ?? null, req.body.city ?? null, req.body.phone ?? null,
         req.body.is_main ?? false],
      );
      return { id, ...req.body };
    });
    await auditLog({
      pharmacyId: req.user.pharmacyId, userId: req.user.id,
      action: 'create', module: 'branches', entity: 'branch', entityId: branch.id, newValues: branch,
    });
    return created(res, branch);
  }));

router.put('/:id', requirePerm('settings:edit'), validate({ body: branchSchema }),
  wrap(async (req, res) => {
    const existing = await query(
      'SELECT * FROM branches WHERE id = $1 AND pharmacy_id = $2',
      [req.params.id, req.user.pharmacyId],
    );
    if (!existing.rows[0]) throw new NotFoundError('Succursale introuvable');

    await withTransaction(req.user.pharmacyId, async (client) => {
      if (req.body.is_main) {
        await client.query('UPDATE branches SET is_main = false WHERE pharmacy_id = $1', [req.user.pharmacyId]);
      }
      await client.query(
        `UPDATE branches SET name=$1, code=$2, address=$3, city=$4, phone=$5,
                is_main = COALESCE($6, is_main), status = COALESCE($7, status)
          WHERE id=$8 AND pharmacy_id=$9`,
        [req.body.name, req.body.code, req.body.address ?? null, req.body.city ?? null,
         req.body.phone ?? null, req.body.is_main, req.body.status,
         req.params.id, req.user.pharmacyId],
      );
    });
    await auditLog({
      pharmacyId: req.user.pharmacyId, userId: req.user.id,
      action: 'edit', module: 'branches', entity: 'branch', entityId: req.params.id, newValues: req.body,
    });
    return ok(res, { id: req.params.id, ...req.body });
  }));

router.delete('/:id', requirePerm('settings:edit'), wrap(async (req, res) => {
  const existing = await query(
    'SELECT is_main FROM branches WHERE id = $1 AND pharmacy_id = $2',
    [req.params.id, req.user.pharmacyId],
  );
  if (!existing.rows[0]) throw new NotFoundError('Succursale introuvable');
  if (existing.rows[0].is_main) {
    return res.status(403).json({
      success: false,
      error: { code: 'FORBIDDEN', message: 'La succursale principale ne peut pas être supprimée' },
    });
  }
  await query('DELETE FROM branches WHERE id = $1 AND pharmacy_id = $2',
    [req.params.id, req.user.pharmacyId]);
  await auditLog({
    pharmacyId: req.user.pharmacyId, userId: req.user.id,
    action: 'delete', module: 'branches', entity: 'branch', entityId: req.params.id,
  });
  return noContent(res);
}));

export const branchesRouter = router;
