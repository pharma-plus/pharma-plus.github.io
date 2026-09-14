import { Router } from 'express';
import Joi from 'joi';
import { validate } from '../../middleware/validate.js';
import { requireAuth, requirePerm, requireSuperAdmin } from '../../middleware/auth.js';
import { wrap } from '../../middleware/error.js';
import { ok, created, noContent } from '../../utils/response.js';
import { backupsService } from './service.js';

const router = Router();
router.use(requireAuth);

router.get('/', requirePerm('backups:view'), validate({
  query: Joi.object({
    page: Joi.number().integer().min(1).default(1),
    limit: Joi.number().integer().min(1).max(200).default(20),
    status: Joi.string().valid('running', 'completed', 'failed', 'restoring', 'verified'),
  }),
}), wrap(async (req, res) => {
  const result = await backupsService.list(req.user.pharmacyId, req.query);
  return ok(res, result.items, result.meta);
}));

router.post('/', requirePerm('backups:create'), validate({
  body: Joi.object({
    type: Joi.string().valid('manual', 'auto').default('manual'),
    scope: Joi.string().valid('full', 'schema', 'data').default('full'),
  }),
}), wrap(async (req, res) => {
  const backup = await backupsService.start(req.user.pharmacyId, req.body, req.user);
  return created(res, backup);
}));

router.post('/:id/restore', requirePerm('backups:approve'), wrap(async (req, res) => {
  const backup = await backupsService.requestRestore(req.user.pharmacyId, req.params.id, req.user);
  return ok(res, backup);
}));

router.post('/:id/verify', requirePerm('backups:edit'), wrap(async (req, res) => {
  const backup = await backupsService.verify(req.user.pharmacyId, req.params.id, req.user);
  return ok(res, backup);
}));

router.delete('/:id', requirePerm('backups:delete'), wrap(async (req, res) => {
  await backupsService.remove(req.user.pharmacyId, req.params.id, req.user);
  return noContent(res);
}));

router.get('/stats/global', requireSuperAdmin, wrap(async (req, res) => {
  const stats = await backupsService.globalStats();
  return ok(res, stats);
}));

export const backupsRouter = router;
