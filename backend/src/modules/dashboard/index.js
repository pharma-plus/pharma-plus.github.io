import { Router } from 'express';
import Joi from 'joi';
import { validate } from '../../middleware/validate.js';
import { requireAuth, requirePerm } from '../../middleware/auth.js';
import { wrap } from '../../middleware/error.js';
import { ok } from '../../utils/response.js';
import { dashboardService } from './service.js';

const router = Router();
router.use(requireAuth);

const periodSchema = Joi.object({
  branchId: Joi.string().uuid().allow(null),
  from: Joi.date().iso().required(),
  to: Joi.date().iso().required(),
  compareFrom: Joi.date().iso().required(),
  compareTo: Joi.date().iso().required(),
});

router.get('/overview', requirePerm('dashboard:view'), validate({
  query: Joi.object({ branchId: Joi.string().uuid().allow(null) }),
}), wrap(async (req, res) => {
  const data = await dashboardService.overview(req.user.pharmacyId, req.query);
  return ok(res, data);
}));

router.get('/top-products', requirePerm('dashboard:view'), validate({
  query: Joi.object({
    branchId: Joi.string().uuid().allow(null),
    limit: Joi.number().integer().min(1).max(50).default(5),
  }),
}), wrap(async (req, res) => {
  const rows = await dashboardService.topProducts(
    req.user.pharmacyId, req.query.branchId, req.query.limit,
  );
  return ok(res, rows);
}));

router.get('/sales-trend', requirePerm('dashboard:view'), validate({
  query: Joi.object({
    branchId: Joi.string().uuid().allow(null),
    days: Joi.number().integer().min(7).max(365).default(30),
  }),
}), wrap(async (req, res) => {
  const rows = await dashboardService.salesTrend(
    req.user.pharmacyId, req.query.branchId, req.query.days,
  );
  return ok(res, rows);
}));

router.get('/compare', requirePerm('reports:view'), validate({ query: periodSchema }),
  wrap(async (req, res) => {
    const data = await dashboardService.compare(req.user.pharmacyId, req.query.branchId,
      req.query.from, req.query.to, req.query.compareFrom, req.query.compareTo);
    return ok(res, data);
  }));

export const dashboardRouter = router;
