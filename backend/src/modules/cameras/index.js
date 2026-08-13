import { Router } from 'express';
import Joi from 'joi';
import { validate } from '../../middleware/validate.js';
import { requireAuth, requirePerm } from '../../middleware/auth.js';
import { wrap } from '../../middleware/error.js';
import { ok, created } from '../../utils/response.js';
import { cameraService } from './service.js';

const router = Router();
router.use(requireAuth);

const cameraSchema = Joi.object({
  branch_id: Joi.string().uuid().allow(null),
  name: Joi.string().min(1).max(80).required(),
  location: Joi.string().max(160).allow(null, ''),
  stream_url: Joi.string().max(500).allow(null, ''),
  snapshot_url: Joi.string().max(500).allow(null, ''),
  position_x: Joi.number().min(0).max(100).default(0),
  position_y: Joi.number().min(0).max(100).default(0),
  status: Joi.string().valid('online', 'offline', 'recording').default('offline'),
  is_enabled: Joi.boolean().default(true),
});

const cameraPatchSchema = Joi.object({
  branch_id: Joi.string().uuid().allow(null),
  name: Joi.string().min(1).max(80),
  location: Joi.string().max(160).allow(null, ''),
  stream_url: Joi.string().max(500).allow(null, ''),
  snapshot_url: Joi.string().max(500).allow(null, ''),
  position_x: Joi.number().min(0).max(100),
  position_y: Joi.number().min(0).max(100),
  status: Joi.string().valid('online', 'offline', 'recording'),
  is_enabled: Joi.boolean(),
}).min(1);

// ------------------------------------------------------------
// Caméras
// ------------------------------------------------------------
router.get('/', requirePerm('cameras:view'), validate({
  query: Joi.object({ branch_id: Joi.string().uuid().allow(null, '') }),
}), wrap(async (req, res) => {
  const cameras = await cameraService.list(req.user.pharmacyId, { branchId: req.query.branch_id });
  return ok(res, cameras);
}));

router.post('/', requirePerm('cameras:create'), validate({ body: cameraSchema }), wrap(async (req, res) => {
  const camera = await cameraService.create(req.user.pharmacyId, req.body, req.user);
  return created(res, camera);
}));

router.get('/:id', requirePerm('cameras:view'), wrap(async (req, res) => {
  const camera = await cameraService.get(req.user.pharmacyId, req.params.id);
  return ok(res, camera);
}));

router.patch('/:id', requirePerm('cameras:edit'), validate({
  params: Joi.object({ id: Joi.string().uuid().required() }),
  body: cameraPatchSchema,
}), wrap(async (req, res) => {
  const camera = await cameraService.update(req.user.pharmacyId, req.params.id, req.body, req.user);
  return ok(res, camera);
}));

router.delete('/:id', requirePerm('cameras:delete'), wrap(async (req, res) => {
  await cameraService.remove(req.user.pharmacyId, req.params.id, req.user);
  return ok(res, { deleted: true });
}));

// ------------------------------------------------------------
// Enregistrements
// ------------------------------------------------------------
router.post('/:id/recordings/start', requirePerm('cameras:edit'), wrap(async (req, res) => {
  const rec = await cameraService.startRecording(req.user.pharmacyId, req.params.id, req.user);
  return created(res, rec);
}));

router.post('/:id/recordings/stop', requirePerm('cameras:edit'), wrap(async (req, res) => {
  const rec = await cameraService.stopRecording(req.user.pharmacyId, req.params.id, req.user);
  return ok(res, rec);
}));

router.get('/:id/recordings', requirePerm('cameras:view'), validate({
  query: Joi.object({ limit: Joi.number().integer().min(1).max(100).default(30) }),
}), wrap(async (req, res) => {
  const recordings = await cameraService.recordings(req.user.pharmacyId, req.params.id, req.query);
  return ok(res, recordings);
}));

export const camerasRouter = router;
