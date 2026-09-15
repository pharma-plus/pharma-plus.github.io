import { Router } from 'express';
import Joi from 'joi';
import { validate } from '../../middleware/validate.js';
import { requireAuth, requirePerm } from '../../middleware/auth.js';
import { wrap } from '../../middleware/error.js';
import { ok } from '../../utils/response.js';
import { syncService } from './service.js';

const router = Router();
router.use(requireAuth);

router.get('/state', requirePerm('sync:view'), wrap(async (req, res) => {
  const state = await syncService.serverState(req.user.pharmacyId);
  return ok(res, state);
}));

router.post('/push', requirePerm('sync:edit'), validate({
  body: Joi.object({
    deviceId: Joi.string().max(200).required(),
    entity: Joi.string().max(60).required(),
    lastRevision: Joi.number().integer().min(0).default(0),
    status: Joi.string().valid('success', 'error').default('success'),
    error: Joi.string().max(1000).allow(null, ''),
  }),
}), wrap(async (req, res) => {
  const op = await syncService.push(req.user.pharmacyId, req.body, req.user);
  return ok(res, op);
}));

router.get('/pull/:entity', requirePerm('sync:view'), validate({
  params: Joi.object({ entity: Joi.string().valid('medications') }),
  query: Joi.object({
    sinceRevision: Joi.number().integer().min(0).default(0),
    limit: Joi.number().integer().min(1).max(2000).default(500),
  }),
}), wrap(async (req, res) => {
  const data = await syncService.pull(req.user.pharmacyId, req.params.entity, req.query);
  return ok(res, data);
}));

export const syncRouter = router;
