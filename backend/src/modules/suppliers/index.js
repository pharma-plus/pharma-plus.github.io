import { Router } from 'express';
import Joi from 'joi';
import { validate } from '../../middleware/validate.js';
import { requireAuth, requirePerm } from '../../middleware/auth.js';
import { wrap } from '../../middleware/error.js';
import { ok, created, noContent } from '../../utils/response.js';
import { suppliersService } from './service.js';

const router = Router();
router.use(requireAuth);

const supplierBody = Joi.object({
  name: Joi.string().max(200).required(),
  contact_name: Joi.string().max(120).allow(null, ''),
  phone: Joi.string().max(30).allow(null, ''),
  whatsapp: Joi.string().max(30).allow(null, ''),
  email: Joi.string().email().allow(null, ''),
  address: Joi.string().max(300).allow(null, ''),
  city: Joi.string().max(120).allow(null, ''),
  website: Joi.string().max(200).allow(null, ''),
  payment_terms: Joi.string().max(100).allow(null, ''),
  delivery_delay: Joi.number().integer().min(0).allow(null),
  notes: Joi.string().max(500).allow(null, ''),
});

router.get('/', requirePerm('suppliers:view'), validate({
  query: Joi.object({
    page: Joi.number().integer().min(1).default(1),
    limit: Joi.number().integer().min(1).max(200).default(20),
    q: Joi.string().max(100).allow(''),
    city: Joi.string().max(100).allow(''),
    status: Joi.string().valid('active', 'inactive'),
  }),
}), wrap(async (req, res) => {
  const result = await suppliersService.list(req.user.pharmacyId, req.query);
  return ok(res, result.items, result.meta);
}));

router.get('/performance', requirePerm('reports:view'), wrap(async (req, res) => {
  const perf = await suppliersService.performance(req.user.pharmacyId);
  return ok(res, perf);
}));

router.get('/:id', requirePerm('suppliers:view'), wrap(async (req, res) => {
  const supplier = await suppliersService.get(req.user.pharmacyId, req.params.id);
  return ok(res, supplier);
}));

router.post('/', requirePerm('suppliers:create'), validate({ body: supplierBody }),
  wrap(async (req, res) => {
    const supplier = await suppliersService.create(req.user.pharmacyId, req.body, req.user);
    return created(res, supplier);
  }));

router.put('/:id', requirePerm('suppliers:edit'), validate({
  body: Joi.object({
    name: Joi.string().max(200),
    contact_name: Joi.string().max(120).allow(null, ''),
    phone: Joi.string().max(30).allow(null, ''),
    whatsapp: Joi.string().max(30).allow(null, ''),
    email: Joi.string().email().allow(null, ''),
    address: Joi.string().max(300).allow(null, ''),
    city: Joi.string().max(120).allow(null, ''),
    website: Joi.string().max(200).allow(null, ''),
    payment_terms: Joi.string().max(100).allow(null, ''),
    delivery_delay: Joi.number().integer().min(0).allow(null),
    rating: Joi.number().min(0).max(5).allow(null),
    notes: Joi.string().max(500).allow(null, ''),
    status: Joi.string().valid('active', 'inactive'),
  }),
}), wrap(async (req, res) => {
  const supplier = await suppliersService.update(req.user.pharmacyId, req.params.id, req.body, req.user);
  return ok(res, supplier);
}));

router.post('/:id/payments', requirePerm('suppliers:edit'), validate({
  body: Joi.object({
    amount: Joi.number().positive().required(),
    paymentDate: Joi.date().allow(null),
    method: Joi.string().valid('cash', 'bank', 'check', 'mobile').default('cash'),
    reference: Joi.string().max(100).allow(null, ''),
    notes: Joi.string().max(300).allow(null, ''),
  }),
}), wrap(async (req, res) => {
  const payment = await suppliersService.addPayment(
    req.user.pharmacyId, { supplierId: req.params.id, ...req.body }, req.user,
  );
  return created(res, payment);
}));

router.delete('/:id', requirePerm('suppliers:delete'), wrap(async (req, res) => {
  await suppliersService.remove(req.user.pharmacyId, req.params.id, req.user);
  return noContent(res);
}));

export const suppliersRouter = router;
