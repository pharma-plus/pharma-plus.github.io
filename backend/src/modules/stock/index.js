import { Router } from 'express';
import Joi from 'joi';
import { validate } from '../../middleware/validate.js';
import { requireAuth, requirePerm } from '../../middleware/auth.js';
import { wrap } from '../../middleware/error.js';
import { ok, created } from '../../utils/response.js';
import { stockService } from './service.js';

const router = Router();
router.use(requireAuth);

const itemSchema = Joi.object({
  medication_id: Joi.string().uuid().required(),
  lot_id: Joi.string().uuid().allow(null),
  lot_number: Joi.string().max(100).allow(null, ''),
  manufacture_date: Joi.date().allow(null),
  expiry_date: Joi.date().required(),
  quantity: Joi.number().positive().required(),
  cost_price: Joi.number().min(0).default(0),
  supplier_id: Joi.string().uuid().allow(null),
  notes: Joi.string().max(300).allow(null, ''),
});

router.get('/balances', requirePerm('stock:view'), validate({
  query: Joi.object({
    page: Joi.number().integer().min(1).default(1),
    limit: Joi.number().integer().min(1).max(200).default(20),
    q: Joi.string().max(200).allow(''),
    branchId: Joi.string().uuid(),
    lowStock: Joi.boolean(),
    expiring: Joi.number().integer().min(1).max(365),
    expired: Joi.boolean(),
  }),
}), wrap(async (req, res) => {
  const result = await stockService.listStock(req.user.pharmacyId, req.query);
  return ok(res, result.items, result.meta);
}));

router.get('/movements', requirePerm('stock:view'), validate({
  query: Joi.object({
    page: Joi.number().integer().min(1).default(1),
    limit: Joi.number().integer().min(1).max(200).default(20),
    branchId: Joi.string().uuid(),
    medicationId: Joi.string().uuid(),
    type: Joi.string(),
    from: Joi.date().iso(),
    to: Joi.date().iso(),
  }),
}), wrap(async (req, res) => {
  const result = await stockService.listMovements(req.user.pharmacyId, req.query);
  return ok(res, result.items, result.meta);
}));

router.get('/alerts', requirePerm('stock:view'), wrap(async (req, res) => {
  const alerts = await stockService.alerts(req.user.pharmacyId);
  return ok(res, alerts);
}));

router.get('/lots', requirePerm('stock:view'), validate({
  query: Joi.object({
    page: Joi.number().integer().min(1).default(1),
    limit: Joi.number().integer().min(1).max(200).default(20),
    medicationId: Joi.string().uuid(),
    q: Joi.string().max(200).allow(''),
    expiring: Joi.number().integer().min(1).max(365),
    expired: Joi.boolean(),
  }),
}), wrap(async (req, res) => {
  const result = await stockService.listLots(req.user.pharmacyId, req.query);
  return ok(res, result.items, result.meta);
}));

router.post('/entries', requirePerm('stock:create'), validate({
  body: Joi.object({
    branchId: Joi.string().uuid().required(),
    items: Joi.array().items(itemSchema).min(1).max(200).required(),
  }),
}), wrap(async (req, res) => {
  await stockService.addStock(
    req.user.pharmacyId, req.body.branchId, req.body.items, { type: 'purchase_receipt' }, req.user,
  );
  return created(res, { message: 'Stock ajouté' });
}));

router.post('/adjustments', requirePerm('stock:edit'), validate({
  body: Joi.object({
    branchId: Joi.string().uuid().required(),
    items: Joi.array().items(Joi.object({
      medication_id: Joi.string().uuid().required(),
      new_quantity: Joi.number().min(0).required(),
    })).min(1).max(500).required(),
  }),
}), wrap(async (req, res) => {
  const result = await stockService.adjust(
    req.user.pharmacyId, req.body.branchId, req.body.items, req.user,
  );
  return ok(res, result);
}));

router.post('/write-off', requirePerm('stock:edit'), validate({
  body: Joi.object({
    branchId: Joi.string().uuid().required(),
    items: Joi.array().items(Joi.object({
      medication_id: Joi.string().uuid().required(),
      quantity: Joi.number().positive().required(),
      reason: Joi.string().max(300).allow(null, ''),
      expired: Joi.boolean().default(false),
    })).min(1).max(200).required(),
  }),
}), wrap(async (req, res) => {
  await stockService.writeOff(req.user.pharmacyId, req.body.branchId, req.body.items, req.user);
  return created(res, { message: 'Sortie enregistrée' });
}));

router.post('/transfers', requirePerm('stock:create'), validate({
  body: Joi.object({
    fromBranch: Joi.string().uuid().required(),
    toBranch: Joi.string().uuid().required(),
    items: Joi.array().items(Joi.object({
      medication_id: Joi.string().uuid().required(),
      lot_id: Joi.string().uuid().allow(null),
      quantity: Joi.number().positive().required(),
      cost_price: Joi.number().min(0).default(0),
    })).min(1).max(200).required(),
  }),
}), wrap(async (req, res) => {
  const transfer = await stockService.transfer(
    req.user.pharmacyId, req.body.fromBranch, req.body.toBranch, req.body.items, req.user,
  );
  return created(res, transfer);
}));

router.get('/transfers', requirePerm('stock:view'), validate({
  query: Joi.object({ status: Joi.string().valid('pending', 'in_transit', 'completed', 'cancelled') }),
}), wrap(async (req, res) => {
  const transfers = await stockService.listTransfers(req.user.pharmacyId, req.query);
  return ok(res, transfers);
}));

export const stockRouter = router;
