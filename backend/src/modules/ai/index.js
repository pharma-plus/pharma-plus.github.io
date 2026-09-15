import { Router } from 'express';
import Joi from 'joi';
import { validate } from '../../middleware/validate.js';
import { requireAuth, requirePerm } from '../../middleware/auth.js';
import { wrap } from '../../middleware/error.js';
import { ok } from '../../utils/response.js';
import { aiService } from './service.js';

const router = Router();
router.use(requireAuth);

const branchQuery = Joi.object({
  branchId: Joi.string().uuid().allow(null, '').default(null),
});

router.get('/insights', requirePerm('ai:view'), wrap(async (req, res) => {
  const insights = await aiService.insights(req.user.pharmacyId);
  return ok(res, insights);
}));

router.get('/reorder-plan', requirePerm('ai:view'), validate({
  query: branchQuery.keys({
    daysCover: Joi.number().integer().min(7).max(60).default(14),
  }),
}), wrap(async (req, res) => {
  const plan = await aiService.reorderPlan(req.user.pharmacyId, {
    branchId: req.query.branchId || null,
    daysCover: req.query.daysCover,
  });
  return ok(res, plan);
}));

router.get('/sales-analysis', requirePerm('ai:view'), validate({
  query: branchQuery.keys({
    days: Joi.number().integer().min(7).max(90).default(30),
  }),
}), wrap(async (req, res) => {
  const analysis = await aiService.salesAnalysis(req.user.pharmacyId, {
    branchId: req.query.branchId || null,
    days: req.query.days,
  });
  return ok(res, analysis);
}));

router.post('/chat', requirePerm('ai:view'), validate({
  body: Joi.object({ query: Joi.string().max(500).required() }),
}), wrap(async (req, res) => {
  const answer = await aiService.chat(req.user.pharmacyId, req.user.id, req.body);
  return ok(res, answer);
}));


export const aiRouter = router;
