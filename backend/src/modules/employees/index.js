import { Router } from 'express';
import Joi from 'joi';
import { validate } from '../../middleware/validate.js';
import { requireAuth, requirePerm } from '../../middleware/auth.js';
import { wrap } from '../../middleware/error.js';
import { ok, created, noContent } from '../../utils/response.js';
import { employeesService } from './service.js';

const router = Router();
router.use(requireAuth);

const employeeBody = Joi.object({
  branchId: Joi.string().uuid().allow(null),
  userId: Joi.string().uuid().allow(null),
  photoUrl: Joi.string().max(500).allow(null, ''),
  firstName: Joi.string().max(120).required(),
  lastName: Joi.string().max(120).required(),
  phone: Joi.string().max(30).allow(null, ''),
  email: Joi.string().email().allow(null, ''),
  cin: Joi.string().max(30).allow(null, ''),
  position: Joi.string().max(120).required(),
  salary: Joi.number().min(0),
  hireDate: Joi.date().allow(null),
  contractType: Joi.string().valid('cdi', 'cdd', 'stage', 'interim').allow(null),
  status: Joi.string().valid('active', 'inactive', 'on_leave'),
  notes: Joi.string().max(500).allow(null, ''),
});

router.get('/', requirePerm('employees:view'), validate({
  query: Joi.object({
    page: Joi.number().integer().min(1).default(1),
    limit: Joi.number().integer().min(1).max(200).default(20),
    q: Joi.string().max(100).allow(''),
    status: Joi.string().valid('active', 'inactive', 'on_leave'),
    branchId: Joi.string().uuid(),
    position: Joi.string().max(100).allow(''),
  }),
}), wrap(async (req, res) => {
  const result = await employeesService.list(req.user.pharmacyId, req.query);
  return ok(res, result.items, result.meta);
}));

router.get('/summary', requirePerm('employees:view'), wrap(async (req, res) => {
  const summary = await employeesService.summary(req.user.pharmacyId);
  return ok(res, summary);
}));

router.get('/:id', requirePerm('employees:view'), wrap(async (req, res) => {
  const employee = await employeesService.get(req.user.pharmacyId, req.params.id);
  return ok(res, employee);
}));

router.post('/', requirePerm('employees:create'), validate({ body: employeeBody }),
  wrap(async (req, res) => {
    const employee = await employeesService.create(req.user.pharmacyId, req.body, req.user);
    return created(res, employee);
  }));

router.put('/:id', requirePerm('employees:edit'), validate({
  body: Joi.object({
    branchId: Joi.string().uuid().allow(null),
    userId: Joi.string().uuid().allow(null),
    photoUrl: Joi.string().max(500).allow(null, ''),
    firstName: Joi.string().max(120),
    lastName: Joi.string().max(120),
    phone: Joi.string().max(30).allow(null, ''),
    email: Joi.string().email().allow(null, ''),
    cin: Joi.string().max(30).allow(null, ''),
    position: Joi.string().max(120),
    salary: Joi.number().min(0),
    hireDate: Joi.date().allow(null),
    contractType: Joi.string().valid('cdi', 'cdd', 'stage', 'interim').allow(null),
    status: Joi.string().valid('active', 'inactive', 'on_leave'),
    notes: Joi.string().max(500).allow(null, ''),
  }),
}), wrap(async (req, res) => {
  const employee = await employeesService.update(req.user.pharmacyId, req.params.id, req.body, req.user);
  return ok(res, employee);
}));

router.delete('/:id', requirePerm('employees:delete'), wrap(async (req, res) => {
  await employeesService.remove(req.user.pharmacyId, req.params.id, req.user);
  return noContent(res);
}));

router.post('/:id/documents', requirePerm('employees:edit'), validate({
  body: Joi.object({
    title: Joi.string().max(200).required(),
    docType: Joi.string().valid('contract', 'cv', 'id', 'certificate', 'other').required(),
    fileUrl: Joi.string().max(500).required(),
  }),
}), wrap(async (req, res) => {
  const doc = await employeesService.addDocument(req.user.pharmacyId, req.params.id, req.body, req.user);
  return created(res, doc);
}));

router.delete('/:id/documents/:documentId', requirePerm('employees:edit'), wrap(async (req, res) => {
  await employeesService.removeDocument(req.user.pharmacyId, req.params.id, req.params.documentId, req.user);
  return noContent(res);
}));

router.post('/:id/bonuses', requirePerm('employees:edit'), validate({
  body: Joi.object({
    amount: Joi.number().positive().required(),
    bonusDate: Joi.date().allow(null),
    reason: Joi.string().max(300).allow(null, ''),
  }),
}), wrap(async (req, res) => {
  const bonus = await employeesService.addBonus(req.user.pharmacyId, req.params.id, req.body, req.user);
  return created(res, bonus);
}));

router.post('/:id/evaluations', requirePerm('employees:edit'), validate({
  body: Joi.object({
    evalDate: Joi.date().allow(null),
    score: Joi.number().min(0).max(5).required(),
    comments: Joi.string().max(1000).allow(null, ''),
  }),
}), wrap(async (req, res) => {
  const evaluation = await employeesService.addEvaluation(req.user.pharmacyId, req.params.id, req.body, req.user);
  return created(res, evaluation);
}));

export const employeesRouter = router;
