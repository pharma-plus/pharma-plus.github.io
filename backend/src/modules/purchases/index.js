import { Router } from 'express';
import Joi from 'joi';
import { validate } from '../../middleware/validate.js';
import { requireAuth, requirePerm } from '../../middleware/auth.js';
import { wrap } from '../../middleware/error.js';
import { ok, created } from '../../utils/response.js';
import { purchasesService } from './service.js';

const router = Router();
router.use(requireAuth);

const itemSchema = Joi.object({
  medication_id: Joi.string().uuid().required(),
  quantity: Joi.number().positive().required(),
  unit_cost: Joi.number().min(0).default(0),
  tva_rate: Joi.number().min(0).max(100).default(20),
  discount: Joi.number().min(0).max(100).default(0),
});

router.get('/orders', requirePerm('purchases:view'), validate({
  query: Joi.object({
    page: Joi.number().integer().min(1).default(1),
    limit: Joi.number().integer().min(1).max(200).default(20),
    supplierId: Joi.string().uuid(),
    status: Joi.string().valid('draft', 'sent', 'confirmed', 'partial', 'received', 'returned', 'cancelled'),
    from: Joi.date().iso(),
    to: Joi.date().iso(),
    q: Joi.string().max(100).allow(''),
  }),
}), wrap(async (req, res) => {
  const result = await purchasesService.listOrders(req.user.pharmacyId, req.query);
  return ok(res, result.items, result.meta);
}));

router.post('/orders', requirePerm('purchases:create'), validate({
  body: Joi.object({
    branchId: Joi.string().uuid().required(),
    supplierId: Joi.string().uuid().required(),
    expectedDate: Joi.date().allow(null),
    notes: Joi.string().max(500).allow(null, ''),
    items: Joi.array().items(itemSchema).min(1).max(500).required(),
  }),
}), wrap(async (req, res) => {
  const order = await purchasesService.createOrder(req.user.pharmacyId, req.body, req.user);
  return created(res, order);
}));

router.get('/orders/:id', requirePerm('purchases:view'), wrap(async (req, res) => {
  const order = await purchasesService.getOrder(req.user.pharmacyId, req.params.id);
  return ok(res, order);
}));

router.post('/orders/:id/status', requirePerm('purchases:edit'), validate({
  body: Joi.object({ status: Joi.string().valid('draft', 'sent', 'confirmed', 'cancelled').required() }),
}), wrap(async (req, res) => {
  const order = await purchasesService.updateStatus(req.user.pharmacyId, req.params.id, req.body.status, req.user);
  return ok(res, order);
}));

router.get('/receptions', requirePerm('purchases:view'), validate({
  query: Joi.object({
    page: Joi.number().integer().min(1).default(1),
    limit: Joi.number().integer().min(1).max(200).default(20),
    orderId: Joi.string().uuid(),
    branchId: Joi.string().uuid(),
  }),
}), wrap(async (req, res) => {
  const result = await purchasesService.listReceptions(req.user.pharmacyId, req.query);
  return ok(res, result.items, result.meta);
}));

router.post('/orders/:id/receive', requirePerm('purchases:create'), validate({
  body: Joi.object({
    branchId: Joi.string().uuid().required(),
    notes: Joi.string().max(500).allow(null, ''),
    items: Joi.array().items(Joi.object({
      medication_id: Joi.string().uuid().required(),
      quantity: Joi.number().positive().required(),
      lot_number: Joi.string().max(100).required(),
      manufacture_date: Joi.date().allow(null),
      expiry_date: Joi.date().required(),
      cost_price: Joi.number().min(0).optional(),
    })).min(1).max(500).required(),
  }),
}), wrap(async (req, res) => {
  const result = await purchasesService.receiveOrder(
    req.user.pharmacyId, { orderId: req.params.id, ...req.body }, req.user,
  );
  return created(res, result);
}));

export const purchasesRouter = router;
