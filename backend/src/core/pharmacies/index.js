import { Router } from 'express';
import Joi from 'joi';
import { validate } from '../../middleware/validate.js';
import { requireAuth, requireSuperAdmin, requirePerm } from '../../middleware/auth.js';
import { wrap } from '../../middleware/error.js';
import { ok, created } from '../../utils/response.js';
import { pharmaciesService } from './service.js';

const router = Router();
router.use(requireAuth);

// --- Super Administrateur : gestion des pharmacies ---
const pharmacyCreateSchema = Joi.object({
  slug: Joi.string().pattern(/^[a-z0-9-]+$/).required(),
  name: Joi.string().max(160).required(),
  legal_name: Joi.string().max(160),
  address: Joi.string().max(300),
  city: Joi.string().max(120),
  phone: Joi.string().max(30),
  whatsapp: Joi.string().max(30),
  email: Joi.string().email(),
  website: Joi.string().max(200),
  currency: Joi.string().max(8).default('MAD'),
  languages: Joi.array().items(Joi.string().valid('fr', 'ar', 'en')).default(['fr', 'ar', 'en']),
  default_lang: Joi.string().valid('fr', 'ar', 'en').default('fr'),
  timezone: Joi.string().default('Africa/Casablanca'),
  colors: Joi.object(),
  license_type: Joi.string().valid('trial', 'standard', 'professional', 'enterprise').default('trial'),
  billing_cycle: Joi.string().valid('monthly', 'annual').default('monthly'),
  license_duration_months: Joi.number().integer().min(1).max(120),
  max_users: Joi.number().integer().min(1).default(1),
  max_branches: Joi.number().integer().min(1).default(1),
  modules: Joi.object(),
  branch_code: Joi.string().max(20),
  admin_first_name: Joi.string().max(80),
  admin_last_name: Joi.string().max(80),
  admin_email: Joi.string().email().required(),
  admin_phone: Joi.string().max(30),
  admin_password: Joi.string().min(8).max(128),
});

router.get('/global-stats', requireSuperAdmin, wrap(async (_req, res) => {
  const stats = await pharmaciesService.globalStats();
  return ok(res, stats);
}));

router.get('/', requireSuperAdmin, validate({
  query: Joi.object({
    page: Joi.number().integer().min(1).default(1),
    limit: Joi.number().integer().min(1).max(200).default(20),
    q: Joi.string().max(100).allow(''),
    status: Joi.string().valid('active', 'suspended', 'deleted', 'trial'),
  }),
}), wrap(async (req, res) => {
  const result = await pharmaciesService.list(req.query);
  return ok(res, result.items, result.meta);
}));

router.post('/', requireSuperAdmin, validate({ body: pharmacyCreateSchema }),
  wrap(async (req, res) => {
    const result = await pharmaciesService.create(req.body, req.user);
    return created(res, result);
  }));

router.post('/:id/status', requireSuperAdmin, validate({
  body: Joi.object({ status: Joi.string().valid('active', 'suspended', 'deleted').required() }),
}), wrap(async (req, res) => {
  await pharmaciesService.setStatus(req.params.id, req.body.status, req.user);
  return ok(res, { message: 'Statut mis à jour' });
}));

// --- Pharmacie connectée : sa propre fiche & personnalisation ---
router.get('/me', wrap(async (req, res) => {
  const pharmacy = await pharmaciesService.get(req.user.pharmacyId);
  return ok(res, pharmacy);
}));

router.get('/self', wrap(async (req, res) => {
  const pharmacy = await pharmaciesService.get(req.user.pharmacyId);
  return ok(res, pharmacy);
}));

router.get('/:id', requireSuperAdmin, wrap(async (req, res) => {
  const pharmacy = await pharmaciesService.get(req.params.id);
  return ok(res, pharmacy);
}));

router.get('/:id/stats', requireSuperAdmin, wrap(async (req, res) => {
  const stats = await pharmaciesService.tenantStats(req.params.id);
  return ok(res, stats);
}));

router.put('/me', requirePerm('settings:edit'), validate({
  body: Joi.object({
    name: Joi.string().max(160),
    legal_name: Joi.string().max(160),
    logo_url: Joi.string().max(500),
    icon_url: Joi.string().max(500),
    banner_url: Joi.string().max(500),
    colors: Joi.object(),
    address: Joi.string().max(300),
    city: Joi.string().max(120),
    phone: Joi.string().max(30),
    whatsapp: Joi.string().max(30),
    email: Joi.string().email(),
    website: Joi.string().max(200),
    currency: Joi.string().max(8),
    languages: Joi.array().items(Joi.string().valid('fr', 'ar', 'en')),
    default_lang: Joi.string().valid('fr', 'ar', 'en'),
    timezone: Joi.string(),
    settings: Joi.object(),
  }),
}), wrap(async (req, res) => {
  const pharmacy = await pharmaciesService.updateSettings(req.user.pharmacyId, req.body, req.user);
  return ok(res, pharmacy);
}));

export const pharmaciesRouter = router;
