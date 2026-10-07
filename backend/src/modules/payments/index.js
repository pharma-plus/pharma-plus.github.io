import { Router } from 'express';
import Joi from 'joi';
import { validate } from '../../middleware/validate.js';
import { requireAuth, requirePerm, requireBranchAccess } from '../../middleware/auth.js';
import { wrap } from '../../middleware/error.js';
import { ok } from '../../utils/response.js';
import { paymentsService } from './service.js';

const router = Router();
router.use(requireAuth);

router.get('/', requirePerm('sales:view'), validate({
  query: Joi.object({
    page: Joi.number().integer().min(1).default(1),
    limit: Joi.number().integer().min(1).max(200).default(20),
    saleId: Joi.string().uuid(),
    method: Joi.string().valid('cash', 'card', 'mobile', 'mixed', 'credit'),
    status: Joi.string().valid('pending', 'completed', 'failed', 'refunded'),
  }),
}), wrap(async (req, res) => {
  const result = await paymentsService.listPayments(req.user.pharmacyId, req.query);
  return ok(res, result.items, result.meta);
}));

router.post('/', requirePerm('sales:create'), requireBranchAccess('branchId'), validate({
  body: Joi.object({
    branchId: Joi.string().uuid().allow(null),
    saleId: Joi.string().uuid(),
    invoiceId: Joi.string().uuid(),
    customerId: Joi.string().uuid().allow(null),
    method: Joi.string().valid('cash', 'card', 'mobile', 'mixed', 'credit').required(),
    amount: Joi.number().positive().required(),
    reference: Joi.string().max(100).allow(null, ''),
  }).or('saleId', 'invoiceId'),
}), wrap(async (req, res) => {
  const result = await paymentsService.recordPayment(req.user.pharmacyId, req.body, req.user);
  return ok(res, result);
}));

router.get('/:id', requirePerm('sales:view'), wrap(async (req, res) => {
  const result = await paymentsService.getPayment(req.user.pharmacyId, req.params.id);
  return ok(res, result);
}));

router.post('/:id/refund', requirePerm('sales:edit'), requireBranchAccess('branchId'), validate({
  body: Joi.object({
    branchId: Joi.string().uuid().allow(null),
    amount: Joi.number().positive().required(),
    reason: Joi.string().max(300).allow(null, ''),
  }),
}), wrap(async (req, res) => {
  const result = await paymentsService.refundPayment(
    req.user.pharmacyId, req.params.id, req.body.amount, req.body.reason, req.user,
  );
  return ok(res, result);
}));

export const paymentsRouter = router;
