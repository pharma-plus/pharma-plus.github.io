import { Router } from 'express';
import Joi from 'joi';
import { validate } from '../../middleware/validate.js';
import { requireAuth, requirePerm } from '../../middleware/auth.js';
import { wrap } from '../../middleware/error.js';
import { ok } from '../../utils/response.js';
import { userSessionService } from './service.js';

const router = Router();
router.use(requireAuth);

router.get('/', requirePerm('users:view'), validate({
  query: Joi.object({
    page: Joi.number().integer().min(1).default(1),
    limit: Joi.number().integer().min(1).max(200).default(20),
    active: Joi.string().valid('true', 'false'),
    userId: Joi.string().uuid(),
  }),
}), wrap(async (req, res) => {
  const result = await userSessionService.listSessions(req.user.pharmacyId, req.query);
  return ok(res, result.items, result.meta);
}));

router.get('/active', requirePerm('users:view'), wrap(async (req, res) => {
  const result = await userSessionService.getActiveSessions(req.user.pharmacyId);
  return ok(res, result);
}));

router.post('/:id/reset-password', requirePerm('users:edit'), wrap(async (req, res) => {
  const result = await userSessionService.resetPassword(req.params.id, req.user);
  return ok(res, result);
}));

export const userSessionsRouter = router;
