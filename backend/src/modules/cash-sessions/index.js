import { Router } from 'express';
import Joi from 'joi';
import { validate } from '../../middleware/validate.js';
import { requireAuth, requirePerm, requireBranchAccess } from '../../middleware/auth.js';
import { wrap } from '../../middleware/error.js';
import { ok } from '../../utils/response.js';
import { cashSessionService } from './service.js';

const router = Router();
router.use(requireAuth);

router.get('/open', requirePerm('cashier:view'), validate({
  query: Joi.object({ branchId: Joi.string().uuid() }),
}), wrap(async (req, res) => {
  const result = await cashSessionService.getOpenSession(req.user.pharmacyId, req.query.branchId);
  return ok(res, result);
}));

router.post('/', requirePerm('cashier:create'), requireBranchAccess('branchId'), validate({
  body: Joi.object({
    branchId: Joi.string().uuid().required(),
    initialCash: Joi.number().min(0),
    initialBalance: Joi.number().min(0),
    notes: Joi.string().max(300).allow(null, ''),
  }).or('initialCash', 'initialBalance'),
}), wrap(async (req, res) => {
  const result = await cashSessionService.openSession(req.user.pharmacyId, req.body, req.user);
  return ok(res, result);
}));

router.post('/:id/events', requirePerm('cashier:edit'), requireBranchAccess('branchId'), validate({
  body: Joi.object({
    eventType: Joi.string().valid('entry', 'exit', 'refund', 'correction').required(),
    amount: Joi.number().positive().required(),
    method: Joi.string().max(30).default('cash'),
    note: Joi.string().max(300).allow(null, ''),
    notes: Joi.string().max(300).allow(null, ''),
  }),
}), wrap(async (req, res) => {
  const result = await cashSessionService.addEvent(req.params.id, req.body, req.user);
  return ok(res, result);
}));

router.post('/:id/close', requirePerm('cashier:edit'), requireBranchAccess('branchId'), validate({
  body: Joi.object({
    countedCash: Joi.number().min(0),
    finalBalance: Joi.number().min(0),
    notes: Joi.string().max(300).allow(null, ''),
  }).or('countedCash', 'finalBalance'),
}), wrap(async (req, res) => {
  const result = await cashSessionService.closeSession(req.params.id, req.body, req.user);
  return ok(res, result);
}));

router.get('/stats/global', requirePerm('cashier:view'), wrap(async (req, res) => {
  const result = await cashSessionService.getGlobalStats(req.user.pharmacyId);
  return ok(res, result);
}));

export const cashSessionsRouter = router;
