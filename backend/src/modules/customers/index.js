import { Router } from 'express';
import Joi from 'joi';
import { validate } from '../../middleware/validate.js';
import { requireAuth, requirePerm } from '../../middleware/auth.js';
import { wrap } from '../../middleware/error.js';
import { ok, created, noContent } from '../../utils/response.js';
import { customersService } from './service.js';

const router = Router();
router.use(requireAuth);

const customerBody = Joi.object({
  name: Joi.string().max(160).required(),
  phone: Joi.string().max(30).allow(null, ''),
  whatsapp: Joi.string().max(30).allow(null, ''),
  email: Joi.string().email().allow(null, ''),
  address: Joi.string().max(300).allow(null, ''),
  birth_date: Joi.date().allow(null),
  loyalty_points: Joi.number().min(0).default(0),
  credit_limit: Joi.number().min(0).default(0),
  notes: Joi.string().max(500).allow(null, ''),
});

router.get('/', requirePerm('customers:view'), validate({
  query: Joi.object({
    page: Joi.number().integer().min(1).default(1),
    limit: Joi.number().integer().min(1).max(200).default(20),
    q: Joi.string().max(100).allow(''),
    status: Joi.string().valid('active', 'inactive'),
    hasCredit: Joi.boolean(),
  }),
}), wrap(async (req, res) => {
  const result = await customersService.list(req.user.pharmacyId, req.query);
  return ok(res, result.items, result.meta);
}));

router.get('/:id', requirePerm('customers:view'), wrap(async (req, res) => {
  const customer = await customersService.get(req.user.pharmacyId, req.params.id);
  return ok(res, customer);
}));

router.get('/:id/history', requirePerm('customers:view'), validate({
  query: Joi.object({
    page: Joi.number().integer().min(1).default(1),
    limit: Joi.number().integer().min(1).max(100).default(20),
  }),
}), wrap(async (req, res) => {
  const history = await customersService.history(req.user.pharmacyId, req.params.id, req.query);
  return ok(res, history);
}));

router.post('/', requirePerm('customers:create'), validate({ body: customerBody }),
  wrap(async (req, res) => {
    const customer = await customersService.create(req.user.pharmacyId, req.body, req.user);
    return created(res, customer);
  }));

router.put('/:id', requirePerm('customers:edit'), validate({
  body: Joi.object({
    name: Joi.string().max(160),
    phone: Joi.string().max(30).allow(null, ''),
    whatsapp: Joi.string().max(30).allow(null, ''),
    email: Joi.string().email().allow(null, ''),
    address: Joi.string().max(300).allow(null, ''),
    birth_date: Joi.date().allow(null),
    credit_limit: Joi.number().min(0),
    notes: Joi.string().max(500).allow(null, ''),
    status: Joi.string().valid('active', 'inactive'),
  }),
}), wrap(async (req, res) => {
  const customer = await customersService.update(req.user.pharmacyId, req.params.id, req.body, req.user);
  return ok(res, customer);
}));

router.delete('/:id', requirePerm('customers:delete'), wrap(async (req, res) => {
  await customersService.remove(req.user.pharmacyId, req.params.id, req.user);
  return noContent(res);
}));

export const customersRouter = router;
