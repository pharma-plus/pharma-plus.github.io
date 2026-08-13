import { Router } from 'express';
import Joi from 'joi';
import { validate } from '../../middleware/validate.js';
import { requireAuth, requirePerm } from '../../middleware/auth.js';
import { wrap } from '../../middleware/error.js';
import { ok, created, noContent } from '../../utils/response.js';
import { catalogService } from './service.js';

const router = Router();
router.use(requireAuth);

const medicationSchema = {
  name: Joi.string().max(200).required(),
  dci: Joi.string().max(200).allow(null, ''),
  generic_name: Joi.string().max(200).allow(null, ''),
  dosage: Joi.string().max(100).allow(null, ''),
  form: Joi.string().max(100).allow(null, ''),
  presentation: Joi.string().max(150).allow(null, ''),
  photo_url: Joi.string().max(500).allow(null, ''),
  leaflet_url: Joi.string().max(500).allow(null, ''),
  barcode_ean13: Joi.string().pattern(/^\d{13}$/).allow(null, ''),
  category_id: Joi.string().uuid().allow(null),
  family_id: Joi.string().uuid().allow(null),
  laboratory_id: Joi.string().uuid().allow(null),
  price_purchase: Joi.number().min(0).default(0),
  price_sale: Joi.number().min(0).default(0),
  tva_rate: Joi.number().min(0).max(100).default(20),
  margin: Joi.number().allow(null),
  prescription_required: Joi.boolean().default(false),
  storage_conditions: Joi.string().max(300).allow(null, ''),
  storage_temp_min: Joi.number().allow(null),
  storage_temp_max: Joi.number().allow(null),
  reorder_level: Joi.number().min(0).default(0),
  min_stock: Joi.number().min(0).default(0),
  shelf_location: Joi.string().max(50).allow(null, ''),
  status: Joi.string().valid('available', 'out_of_stock', 'retired').default('available'),
  is_public: Joi.boolean().default(false),
  is_parapharmacie: Joi.boolean().default(false),
  equivalents: Joi.array().items(Joi.string().uuid()).optional(),
  suppliers: Joi.array().items(Joi.object({
    supplier_id: Joi.string().uuid().required(),
    reference: Joi.string().max(100).allow(null, ''),
    price: Joi.number().min(0).default(0),
    is_primary: Joi.boolean().default(false),
  })).optional(),
};

// ---------------- Catégories ----------------
router.get('/categories', requirePerm('catalog:view'), wrap(async (req, res) => {
  const rows = await catalogService.listCategories(req.user.pharmacyId);
  return ok(res, rows);
}));

router.post('/categories', requirePerm('catalog:create'), validate({
  body: Joi.object({
    name: Joi.string().max(160).required(),
    parent_id: Joi.string().uuid().allow(null),
    description: Joi.string().max(500).allow(null, ''),
    icon: Joi.string().max(50).allow(null, ''),
    color: Joi.string().max(20).allow(null, ''),
  }),
}), wrap(async (req, res) => {
  const cat = await catalogService.createCategory(req.user.pharmacyId, req.body, req.user);
  return created(res, cat);
}));

router.put('/categories/:id', requirePerm('catalog:edit'), validate({
  body: Joi.object({
    name: Joi.string().max(160),
    parent_id: Joi.string().uuid().allow(null),
    description: Joi.string().max(500).allow(null, ''),
    icon: Joi.string().max(50).allow(null, ''),
    color: Joi.string().max(20).allow(null, ''),
  }),
}), wrap(async (req, res) => {
  const cat = await catalogService.updateCategory(req.user.pharmacyId, req.params.id, req.body, req.user);
  return ok(res, cat);
}));

router.delete('/categories/:id', requirePerm('catalog:delete'), wrap(async (req, res) => {
  await catalogService.deleteCategory(req.user.pharmacyId, req.params.id, req.user);
  return noContent(res);
}));

// ---------------- Familles thérapeutiques ----------------
router.get('/families', requirePerm('catalog:view'), wrap(async (req, res) => {
  const rows = await catalogService.listFamilies(req.user.pharmacyId);
  return ok(res, rows);
}));

router.post('/families', requirePerm('catalog:create'), validate({
  body: Joi.object({
    code: Joi.string().max(50).required(),
    name: Joi.string().max(200).required(),
  }),
}), wrap(async (req, res) => {
  const fam = await catalogService.createFamily(req.user.pharmacyId, req.body, req.user);
  return created(res, fam);
}));

router.put('/families/:id', requirePerm('catalog:edit'), validate({
  body: Joi.object({
    code: Joi.string().max(50),
    name: Joi.string().max(200),
  }),
}), wrap(async (req, res) => {
  const fam = await catalogService.updateFamily(req.user.pharmacyId, req.params.id, req.body, req.user);
  return ok(res, fam);
}));

router.delete('/families/:id', requirePerm('catalog:delete'), wrap(async (req, res) => {
  await catalogService.deleteFamily(req.user.pharmacyId, req.params.id, req.user);
  return noContent(res);
}));

// ---------------- Laboratoires ----------------
router.get('/laboratories', requirePerm('catalog:view'), wrap(async (req, res) => {
  const rows = await catalogService.listLaboratories(req.user.pharmacyId);
  return ok(res, rows);
}));

router.post('/laboratories', requirePerm('catalog:create'), validate({
  body: Joi.object({
    name: Joi.string().max(200).required(),
    country: Joi.string().max(100).allow(null, ''),
    phone: Joi.string().max(30).allow(null, ''),
    email: Joi.string().email().allow(null, ''),
  }),
}), wrap(async (req, res) => {
  const lab = await catalogService.createLaboratory(req.user.pharmacyId, req.body, req.user);
  return created(res, lab);
}));

router.put('/laboratories/:id', requirePerm('catalog:edit'), validate({
  body: Joi.object({
    name: Joi.string().max(200),
    country: Joi.string().max(100).allow(null, ''),
    phone: Joi.string().max(30).allow(null, ''),
    email: Joi.string().email().allow(null, ''),
  }),
}), wrap(async (req, res) => {
  const lab = await catalogService.updateLaboratory(req.user.pharmacyId, req.params.id, req.body, req.user);
  return ok(res, lab);
}));

router.delete('/laboratories/:id', requirePerm('catalog:delete'), wrap(async (req, res) => {
  await catalogService.deleteLaboratory(req.user.pharmacyId, req.params.id, req.user);
  return noContent(res);
}));

// ---------------- Médicaments ----------------
router.get('/medications', requirePerm('catalog:view'), validate({
  query: Joi.object({
    page: Joi.number().integer().min(1).default(1),
    limit: Joi.number().integer().min(1).max(200).default(20),
    q: Joi.string().max(200).allow(''),
    categoryId: Joi.string().uuid(),
    familyId: Joi.string().uuid(),
    laboratoryId: Joi.string().uuid(),
    status: Joi.string().valid('available', 'out_of_stock', 'retired'),
    branchId: Joi.string().uuid(),
    lowStock: Joi.boolean(),
    is_parapharmacie: Joi.boolean(),
  }),
}), wrap(async (req, res) => {
  const result = await catalogService.listMedications(req.user.pharmacyId, req.query);
  return ok(res, result.items, result.meta);
}));

router.get('/medications/barcode/:code', requirePerm('catalog:view'), wrap(async (req, res) => {
  const med = await catalogService.findBarcode(req.user.pharmacyId, req.params.code);
  return ok(res, med);
}));

router.get('/medications/:id/equivalents', requirePerm('catalog:view'), wrap(async (req, res) => {
  const eq = await catalogService.listEquivalents(req.user.pharmacyId, req.params.id);
  return ok(res, eq);
}));

router.post('/medications/:id/equivalents', requirePerm('catalog:edit'), validate({
  body: Joi.object({ equivalentId: Joi.string().uuid().required() }),
}), wrap(async (req, res) => {
  const eq = await catalogService.addEquivalent(req.user.pharmacyId, req.params.id, req.body.equivalentId, req.user);
  return created(res, eq);
}));

router.get('/medications/:id', requirePerm('catalog:view'), wrap(async (req, res) => {
  const med = await catalogService.getMedication(req.user.pharmacyId, req.params.id, req.query.branchId);
  return ok(res, med);
}));

router.post('/medications', requirePerm('catalog:create'), validate({
  body: Joi.object(medicationSchema),
}), wrap(async (req, res) => {
  const med = await catalogService.createMedication(req.user.pharmacyId, req.body, req.user);
  return created(res, med);
}));

router.post('/medications/bulk', requirePerm('catalog:create'), validate({
  body: Joi.object({ items: Joi.array().items(Joi.object(medicationSchema)).max(500).required() }),
}), wrap(async (req, res) => {
  const meds = await catalogService.bulkCreate(req.user.pharmacyId, req.body.items, req.user);
  return created(res, meds);
}));

router.put('/medications/:id', requirePerm('catalog:edit'), validate({
  body: Joi.object(medicationSchema),
}), wrap(async (req, res) => {
  const med = await catalogService.updateMedication(req.user.pharmacyId, req.params.id, req.body, req.user);
  return ok(res, med);
}));

router.delete('/medications/:id', requirePerm('catalog:delete'), wrap(async (req, res) => {
  await catalogService.deleteMedication(req.user.pharmacyId, req.params.id, req.user);
  return noContent(res);
}));

export const catalogRouter = router;
