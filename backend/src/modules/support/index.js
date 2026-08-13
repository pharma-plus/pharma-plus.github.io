import { Router } from 'express';
import Joi from 'joi';
import { validate } from '../../middleware/validate.js';
import { requireAuth, requirePerm } from '../../middleware/auth.js';
import { wrap } from '../../middleware/error.js';
import { ok, created } from '../../utils/response.js';
import { supportService } from './service.js';

const router = Router();
router.use(requireAuth);

router.get('/', requirePerm('support:view'), validate({
  query: Joi.object({
    page: Joi.number().integer().min(1).default(1),
    limit: Joi.number().integer().min(1).max(200).default(20),
    status: Joi.string().valid('open', 'in_progress', 'resolved', 'closed'),
    priority: Joi.string().valid('low', 'normal', 'high', 'critical'),
  }),
}), wrap(async (req, res) => {
  const result = await supportService.list(req.user.pharmacyId, req.query);
  return ok(res, result.items, result.meta);
}));

router.get('/:id', requirePerm('support:view'), wrap(async (req, res) => {
  const ticket = await supportService.get(req.user.pharmacyId, req.params.id);
  return ok(res, ticket);
}));

router.post('/', requirePerm('support:create'), validate({
  body: Joi.object({
    subject: Joi.string().max(200).required(),
    priority: Joi.string().valid('low', 'normal', 'high', 'critical').default('normal'),
    message: Joi.string().max(5000).allow(null, ''),
  }),
}), wrap(async (req, res) => {
  const ticket = await supportService.create(req.user.pharmacyId, req.body, req.user);
  return created(res, ticket);
}));

router.post('/:id/messages', requirePerm('support:edit'), validate({
  body: Joi.object({ message: Joi.string().max(5000).required() }),
}), wrap(async (req, res) => {
  const message = await supportService.addMessage(req.user.pharmacyId, req.params.id, req.body, req.user);
  return created(res, message);
}));

router.post('/:id/status', requirePerm('support:edit'), validate({
  body: Joi.object({ status: Joi.string().valid('open', 'in_progress', 'resolved', 'closed').required() }),
}), wrap(async (req, res) => {
  const ticket = await supportService.updateStatus(req.user.pharmacyId, req.params.id, req.body.status, req.user);
  return ok(res, ticket);
}));

export const supportRouter = router;
