import { Router } from 'express';
import Joi from 'joi';
import { validate } from '../../middleware/validate.js';
import { requireAuth, requirePerm } from '../../middleware/auth.js';
import { wrap } from '../../middleware/error.js';
import { ok } from '../../utils/response.js';
import { maintenanceService } from './service.js';

const router = Router();
router.use(requireAuth);

router.post('/reset', requirePerm('settings:edit'), validate({
  body: Joi.object({
    level: Joi.string().valid('test_sales', 'stock_zero').required(),
    confirmation: Joi.string().required(),
  }),
}), wrap(async (req, res) => {
  const result = await maintenanceService.resetDatabase(req.user.pharmacyId, req.body, req.user);
  return ok(res, result);
}));

router.get('/health-check', requirePerm('settings:view'), wrap(async (req, res) => {
  const result = await maintenanceService.healthCheck(req.user.pharmacyId);
  return ok(res, result);
}));

export const maintenanceRouter = router;
