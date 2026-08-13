import { Router } from 'express';
import Joi from 'joi';
import { validate } from '../../middleware/validate.js';
import { requireAuth, requirePerm } from '../../middleware/auth.js';
import { wrap } from '../../middleware/error.js';
import { ok, created } from '../../utils/response.js';
import { salesService } from './service.js';

const router = Router();
router.use(requireAuth);

const paymentSchema = Joi.object({
  method: Joi.string().valid('cash', 'card', 'mobile', 'mixed', 'credit').required(),
  amount: Joi.number().positive().required(),
  reference: Joi.string().max(100).allow(null, ''),
  generateInvoice: Joi.boolean().default(false),
});

const itemSchema = Joi.object({
  medication_id: Joi.string().uuid().required(),
  quantity: Joi.number().positive().required(),
  unit_price: Joi.number().min(0).optional(),
  discount: Joi.number().min(0).max(100).default(0),
  tva_rate: Joi.number().min(0).max(100).optional(),
  lot_id: Joi.string().uuid().allow(null),
});

// ---------------- Caisse (POS) ----------------
router.post('/', requirePerm('sales:create'), validate({
  body: Joi.object({
    branchId: Joi.string().uuid().required(),
    customerId: Joi.string().uuid().allow(null),
    saleType: Joi.string().valid('pos', 'credit', 'online', 'reservation').default('pos'),
    prescriptionId: Joi.string().uuid().allow(null),
    notes: Joi.string().max(500).allow(null, ''),
    items: Joi.array().items(itemSchema).min(1).max(500).required(),
    payments: Joi.array().items(paymentSchema).optional(),
  }),
}), wrap(async (req, res) => {
  const sale = await salesService.createSale(req.user.pharmacyId, req.body, req.user);
  return created(res, sale);
}));

router.get('/', requirePerm('sales:view'), validate({
  query: Joi.object({
    page: Joi.number().integer().min(1).default(1),
    limit: Joi.number().integer().min(1).max(200).default(20),
    branchId: Joi.string().uuid(),
    customerId: Joi.string().uuid(),
    saleType: Joi.string().valid('pos', 'credit', 'online', 'reservation'),
    status: Joi.string().valid('completed', 'returned', 'voided'),
    from: Joi.date().iso(),
    to: Joi.date().iso(),
    q: Joi.string().max(100).allow(''),
  }),
}), wrap(async (req, res) => {
  const result = await salesService.listSales(req.user.pharmacyId, req.query);
  return ok(res, result.items, result.meta);
}));

router.get('/invoices', requirePerm('sales:view'), validate({
  query: Joi.object({
    page: Joi.number().integer().min(1).default(1),
    limit: Joi.number().integer().min(1).max(200).default(20),
    customerId: Joi.string().uuid(),
    status: Joi.string().valid('unpaid', 'partial', 'paid', 'cancelled'),
    from: Joi.date().iso(),
    to: Joi.date().iso(),
  }),
}), wrap(async (req, res) => {
  const result = await salesService.listInvoices(req.user.pharmacyId, req.query);
  return ok(res, result.items, result.meta);
}));

// ---------------- Réservations clients ----------------
router.get('/reservations', requirePerm('sales:view'), validate({
  query: Joi.object({
    page: Joi.number().integer().min(1).default(1),
    limit: Joi.number().integer().min(1).max(200).default(20),
    status: Joi.string().valid('pending', 'ready', 'fulfilled', 'cancelled', 'expired'),
    branchId: Joi.string().uuid(),
    customerId: Joi.string().uuid(),
  }),
}), wrap(async (req, res) => {
  const result = await salesService.listReservations(req.user.pharmacyId, req.query);
  return ok(res, result.items, result.meta);
}));

router.post('/reservations', requirePerm('sales:create'), validate({
  body: Joi.object({
    branchId: Joi.string().uuid().required(),
    customerId: Joi.string().uuid().allow(null),
    medicationId: Joi.string().uuid().required(),
    quantity: Joi.number().positive().required(),
    expiresAt: Joi.date().iso().allow(null),
  }),
}), wrap(async (req, res) => {
  const reservation = await salesService.createReservation(req.user.pharmacyId, req.body, req.user);
  return created(res, reservation);
}));

router.post('/reservations/:id/release', requirePerm('sales:edit'), wrap(async (req, res) => {
  const reservation = await salesService.releaseReservation(req.user.pharmacyId, req.params.id, req.user);
  return ok(res, reservation);
}));

router.get('/:id', requirePerm('sales:view'), wrap(async (req, res) => {
  const sale = await salesService.getSale(req.user.pharmacyId, req.params.id);
  return ok(res, sale);
}));

// ---------------- Retours / remboursements ----------------
router.post('/returns', requirePerm('sales:create'), validate({
  body: Joi.object({
    saleId: Joi.string().uuid().required(),
    branchId: Joi.string().uuid().required(),
    reason: Joi.string().max(500).allow(null, ''),
    returnType: Joi.string().valid('refund', 'exchange', 'credit').default('refund'),
    items: Joi.array().items(Joi.object({
      medication_id: Joi.string().uuid().required(),
      quantity: Joi.number().positive().required(),
    })).min(1).max(200).required(),
  }),
}), wrap(async (req, res) => {
  const result = await salesService.returnSale(req.user.pharmacyId, req.body, req.user);
  return created(res, result);
}));

// ---------------- Paiements ----------------
router.post('/payments', requirePerm('sales:create'), validate({
  body: Joi.object({
    invoiceId: Joi.string().uuid().allow(null),
    saleId: Joi.string().uuid().allow(null),
    customerId: Joi.string().uuid().allow(null),
    method: Joi.string().valid('cash', 'card', 'mobile', 'credit').required(),
    amount: Joi.number().positive().required(),
    reference: Joi.string().max(100).allow(null, ''),
  }),
}), wrap(async (req, res) => {
  const payment = await salesService.recordPayment(req.user.pharmacyId, req.body, req.user);
  return created(res, payment);
}));

export const salesRouter = router;
