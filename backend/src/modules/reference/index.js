import { Router } from 'express';
import Joi from 'joi';
import { validate } from '../../middleware/validate.js';
import { requireAuth, requirePerm } from '../../middleware/auth.js';
import { wrap } from '../../middleware/error.js';
import { ok } from '../../utils/response.js';
import { referenceService } from './service.js';

const router = Router();
router.use(requireAuth);

// ------------------------------------------------------------
// Catégories thérapeutiques
// ------------------------------------------------------------
router.get('/categories', requirePerm('reference:view'), wrap(async (_req, res) => {
  const categories = await referenceService.categories();
  return ok(res, categories);
}));

// ------------------------------------------------------------
// Produits de référence
// ------------------------------------------------------------
router.get('/products', requirePerm('reference:view'), validate({
  query: Joi.object({
    page: Joi.number().integer().min(1).default(1),
    limit: Joi.number().integer().min(1).max(100).default(20),
    q: Joi.string().max(120).allow(null, ''),
    category: Joi.string().max(60).allow(null, ''),
    status: Joi.string().max(30).allow(null, ''),
  }),
}), wrap(async (req, res) => {
  const data = await referenceService.products(req.query);
  return ok(res, data.items, data.meta);
}));

router.get('/products/:id', requirePerm('reference:view'), wrap(async (req, res) => {
  const product = await referenceService.getProduct(req.params.id);
  return ok(res, product);
}));

// ------------------------------------------------------------
// Synchronisation de la base
// ------------------------------------------------------------
router.get('/sync/status', requirePerm('reference:view'), wrap(async (_req, res) => {
  const status = await referenceService.syncStatus();
  return ok(res, status);
}));

router.post('/sync', requirePerm('reference:edit'), wrap(async (req, res) => {
  const status = await referenceService.runSync(req.user);
  return ok(res, status);
}));

router.get('/sync/history', requirePerm('reference:view'), validate({
  query: Joi.object({ limit: Joi.number().integer().min(1).max(100).default(20) }),
}), wrap(async (req, res) => {
  const history = await referenceService.syncHistory(req.query);
  return ok(res, history);
}));

router.get('/updates', requirePerm('reference:view'), validate({
  query: Joi.object({
    limit: Joi.number().integer().min(1).max(100).default(30),
    type: Joi.string().valid('new', 'modified', 'price_changed', 'status_changed', 'removed').allow(null, ''),
  }),
}), wrap(async (req, res) => {
  const updates = await referenceService.updates(req.query);
  return ok(res, updates);
}));

// ------------------------------------------------------------
// Import d'un produit vers le catalogue de la pharmacie
// ------------------------------------------------------------
router.post('/products/:id/import', requirePerm('reference:create'), validate({
  params: Joi.object({ id: Joi.string().uuid().required() }),
  body: Joi.object({
    priceSale: Joi.number().min(0).allow(null),
    pricePurchase: Joi.number().min(0).allow(null),
    reorderLevel: Joi.number().min(0).default(10),
    minStock: Joi.number().min(0).default(5),
  }),
}), wrap(async (req, res) => {
  const med = await referenceService.importToCatalog(
    req.user.pharmacyId, req.params.id, req.body, req.user,
  );
  return ok(res, med);
}));

export const referenceRouter = router;
