import { Router } from 'express';
import Joi from 'joi';
import { validate } from '../../middleware/validate.js';
import { requireAuth, requirePerm } from '../../middleware/auth.js';
import { wrap } from '../../middleware/error.js';
import { ok, created, noContent } from '../../utils/response.js';
import { prescriptionsService } from './service.js';

const router = Router();
router.use(requireAuth);

const itemSchema = Joi.object({
  medicationId: Joi.string().uuid().allow(null),
  dosage: Joi.string().max(80).allow(null, ''),
  frequency: Joi.string().max(80).allow(null, ''),
  duration: Joi.string().max(80).allow(null, ''),
  quantity: Joi.number().min(0),
  isDispensed: Joi.boolean(),
  notes: Joi.string().max(300).allow(null, ''),
});

const prescriptionBody = Joi.object({
  customerId: Joi.string().uuid().allow(null),
  patientName: Joi.string().max(200).allow(null, ''),
  doctorName: Joi.string().max(200).allow(null, ''),
  source: Joi.string().valid('camera', 'pdf', 'manual', 'client_web').default('manual'),
  fileUrl: Joi.string().max(500).allow(null, ''),
  notes: Joi.string().max(500).allow(null, ''),
  items: Joi.array().items(itemSchema),
});

router.get('/', requirePerm('prescriptions:view'), validate({
  query: Joi.object({
    page: Joi.number().integer().min(1).default(1),
    limit: Joi.number().integer().min(1).max(200).default(20),
    status: Joi.string().valid('received', 'processing', 'filled', 'rejected', 'archived'),
    q: Joi.string().max(100).allow(''),
    from: Joi.date().iso(),
    to: Joi.date().iso(),
  }),
}), wrap(async (req, res) => {
  const result = await prescriptionsService.list(req.user.pharmacyId, req.query);
  return ok(res, result.items, result.meta);
}));

router.get('/:id', requirePerm('prescriptions:view'), wrap(async (req, res) => {
  const prescription = await prescriptionsService.get(req.user.pharmacyId, req.params.id);
  return ok(res, prescription);
}));

router.post('/', requirePerm('prescriptions:create'), validate({ body: prescriptionBody }),
  wrap(async (req, res) => {
    const prescription = await prescriptionsService.create(req.user.pharmacyId, req.body, req.user);
    return created(res, prescription);
  }));

router.put('/:id', requirePerm('prescriptions:edit'), validate({
  body: Joi.object({
    customerId: Joi.string().uuid().allow(null),
    patientName: Joi.string().max(200).allow(null, ''),
    doctorName: Joi.string().max(200).allow(null, ''),
    fileUrl: Joi.string().max(500).allow(null, ''),
    notes: Joi.string().max(500).allow(null, ''),
    items: Joi.array().items(itemSchema),
  }),
}), wrap(async (req, res) => {
  const prescription = await prescriptionsService.update(req.user.pharmacyId, req.params.id, req.body, req.user);
  return ok(res, prescription);
}));

router.post('/:id/dispense', requirePerm('prescriptions:edit'), validate({
  body: Joi.object({ itemIds: Joi.array().items(Joi.string().uuid()).min(1) }),
}), wrap(async (req, res) => {
  const prescription = await prescriptionsService.markDispensed(
    req.user.pharmacyId, req.params.id, req.body.itemIds, req.user,
  );
  return ok(res, prescription);
}));

router.post('/:id/status', requirePerm('prescriptions:edit'), validate({
  body: Joi.object({ status: Joi.string().valid('received', 'processing', 'filled', 'rejected', 'archived').required() }),
}), wrap(async (req, res) => {
  const prescription = await prescriptionsService.updateStatus(
    req.user.pharmacyId, req.params.id, req.body.status, req.user,
  );
  return ok(res, prescription);
}));

router.delete('/:id', requirePerm('prescriptions:delete'), wrap(async (req, res) => {
  await prescriptionsService.remove(req.user.pharmacyId, req.params.id, req.user);
  return noContent(res);
}));

export const prescriptionsRouter = router;
