import { Router } from 'express';
import Joi from 'joi';
import { validate } from '../../middleware/validate.js';
import { requireAuth, requirePerm } from '../../middleware/auth.js';
import { wrap } from '../../middleware/error.js';
import { ok } from '../../utils/response.js';
import { notificationsService } from './service.js';

const router = Router();
router.use(requireAuth);

router.get('/', requirePerm('notifications:view'), validate({
  query: Joi.object({
    page: Joi.number().integer().min(1).default(1),
    limit: Joi.number().integer().min(1).max(200).default(20),
    unreadOnly: Joi.boolean().default(false),
  }),
}), wrap(async (req, res) => {
  const result = await notificationsService.list(req.user.pharmacyId, {
    ...req.query,
    userId: req.user.isSuperAdmin ? null : req.user.id,
  });
  return ok(res, result.items, result.meta);
}));

router.post('/:id/read', requirePerm('notifications:edit'), wrap(async (req, res) => {
  const notification = await notificationsService.markRead(req.user.pharmacyId, req.params.id, req.user.id);
  return ok(res, notification);
}));

router.post('/read-all', requirePerm('notifications:edit'), wrap(async (req, res) => {
  const result = await notificationsService.markAllRead(req.user.pharmacyId, req.user.id);
  return ok(res, result);
}));

router.get('/alerts/stock', requirePerm('notifications:view'), wrap(async (req, res) => {
  const alerts = await notificationsService.stockAlerts(req.user.pharmacyId);
  return ok(res, alerts);
}));

export const notificationsRouter = router;
