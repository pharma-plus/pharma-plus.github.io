import { Router } from 'express';
import Joi from 'joi';
import { validate } from '../../middleware/validate.js';
import { requireAuth, requirePerm } from '../../middleware/auth.js';
import { wrap } from '../../middleware/error.js';
import { ok } from '../../utils/response.js';
import { aiService } from './service.js';

const router = Router();
router.use(requireAuth);

router.get('/insights', requirePerm('ai:view'), wrap(async (req, res) => {
  const insights = await aiService.insights(req.user.pharmacyId);
  return ok(res, insights);
}));

router.post('/chat', requirePerm('ai:view'), validate({
  body: Joi.object({ query: Joi.string().max(500).required() }),
}), wrap(async (req, res) => {
  const answer = await aiService.chat(req.user.pharmacyId, req.body);
  return ok(res, answer);
}));

export const aiRouter = router;
