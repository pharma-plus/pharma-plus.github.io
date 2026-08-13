import { Router } from 'express';
import Joi from 'joi';
import { validate } from '../../middleware/validate.js';
import { requireAuth, requirePerm } from '../../middleware/auth.js';
import { wrap } from '../../middleware/error.js';
import { ok, created, noContent } from '../../utils/response.js';
import { usersService } from './service.js';

const router = Router();
router.use(requireAuth);

const userBody = {
  first_name: Joi.string().max(80).required(),
  last_name: Joi.string().max(80).required(),
  email: Joi.string().email().required(),
  phone: Joi.string().max(30).allow(null, ''),
  photo_url: Joi.string().max(500).allow(null, ''),
  branch_id: Joi.string().uuid().allow(null),
  role_id: Joi.string().uuid().required(),
};

router.get('/', requirePerm('users:view'), validate({
  query: Joi.object({
    page: Joi.number().integer().min(1).default(1),
    limit: Joi.number().integer().min(1).max(200).default(20),
    q: Joi.string().max(100).allow(''),
    status: Joi.string().valid('active', 'inactive', 'locked'),
    roleId: Joi.string().uuid(),
    branchId: Joi.string().uuid(),
  }),
}), wrap(async (req, res) => {
  const result = await usersService.list(req.user.pharmacyId, req.query);
  return ok(res, result.items, result.meta);
}));

router.get('/:id', requirePerm('users:view'), wrap(async (req, res) => {
  const user = await usersService.get(req.user.pharmacyId, req.params.id);
  return ok(res, user);
}));

router.post('/', requirePerm('users:create'), validate({
  body: Joi.object({ ...userBody, password: Joi.string().min(8).max(128).optional() }),
}), wrap(async (req, res) => {
  const user = await usersService.create(req.user.pharmacyId, req.body, req.user);
  return created(res, user);
}));

router.put('/:id', requirePerm('users:edit'), validate({
  body: Joi.object({
    first_name: Joi.string().max(80),
    last_name: Joi.string().max(80),
    phone: Joi.string().max(30).allow(null, ''),
    photo_url: Joi.string().max(500).allow(null, ''),
    branch_id: Joi.string().uuid().allow(null),
    role_id: Joi.string().uuid(),
    status: Joi.string().valid('active', 'inactive', 'locked'),
  }),
}), wrap(async (req, res) => {
  const user = await usersService.update(req.user.pharmacyId, req.params.id, req.body, req.user);
  return ok(res, user);
}));

router.post('/:id/reset-password', requirePerm('users:edit'), validate({
  body: Joi.object({ newPassword: Joi.string().min(8).max(128).required() }),
}), wrap(async (req, res) => {
  await usersService.resetPassword(req.user.pharmacyId, req.params.id, req.body.newPassword, req.user);
  return ok(res, { message: 'Mot de passe réinitialisé' });
}));

router.post('/:id/status', requirePerm('users:edit'), validate({
  body: Joi.object({ status: Joi.string().valid('active', 'inactive', 'locked').required() }),
}), wrap(async (req, res) => {
  await usersService.setStatus(req.user.pharmacyId, req.params.id, req.body.status, req.user);
  return ok(res, { message: 'Statut mis à jour' });
}));

router.delete('/:id', requirePerm('users:delete'), wrap(async (req, res) => {
  await usersService.remove(req.user.pharmacyId, req.params.id, req.user);
  return noContent(res);
}));

export const usersRouter = router;
