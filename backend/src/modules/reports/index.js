import { Router } from 'express';
import Joi from 'joi';
import { validate } from '../../middleware/validate.js';
import { requireAuth, requirePerm } from '../../middleware/auth.js';
import { wrap } from '../../middleware/error.js';
import { ok } from '../../utils/response.js';
import { reportsService } from './service.js';

const router = Router();
router.use(requireAuth);

const periodSchema = Joi.object({
  branchId: Joi.string().uuid().allow(null),
  from: Joi.date().iso().required(),
  to: Joi.date().iso().required(),
  groupBy: Joi.string().valid('day', 'week', 'month'),
  limit: Joi.number().integer().min(1).max(1000),
});

router.get('/sales', requirePerm('reports:view'), validate({ query: periodSchema }),
  wrap(async (req, res) => {
    const rows = await reportsService.salesReport(req.user.pharmacyId, req.query);
    return ok(res, rows);
  }));

router.get('/products', requirePerm('reports:view'), validate({ query: periodSchema }),
  wrap(async (req, res) => {
    const rows = await reportsService.productReport(req.user.pharmacyId, req.query);
    return ok(res, rows);
  }));

router.get('/stock', requirePerm('reports:view'), validate({
  query: Joi.object({ branchId: Joi.string().uuid().allow(null) }),
}), wrap(async (req, res) => {
  const data = await reportsService.stockReport(req.user.pharmacyId, req.query);
  return ok(res, data);
}));

router.get('/financial', requirePerm('accounting:view'), validate({ query: periodSchema }),
  wrap(async (req, res) => {
    const data = await reportsService.financialReport(req.user.pharmacyId, req.query);
    return ok(res, data);
  }));

router.get('/employees', requirePerm('reports:view'), validate({ query: periodSchema }),
  wrap(async (req, res) => {
    const rows = await reportsService.employeeReport(req.user.pharmacyId, req.query);
    return ok(res, rows);
  }));

export const reportsRouter = router;
