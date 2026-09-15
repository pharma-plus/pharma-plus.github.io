import { Router } from 'express';
import Joi from 'joi';
import { validate } from '../../middleware/validate.js';
import { requireAuth, requirePerm } from '../../middleware/auth.js';
import { wrap } from '../../middleware/error.js';
import { ok, created, noContent } from '../../utils/response.js';
import { websiteService } from './service.js';

// ---- Site public : aucun token requis ----
export const websitePublicRouter = Router();
websitePublicRouter.get('/:slug', wrap(async (req, res) => {
  const site = await websiteService.publicSite(req.params.slug);
  return ok(res, site);
}));
websitePublicRouter.get('/:slug/blog/:postSlug', wrap(async (req, res) => {
  const post = await websiteService.publicPost(req.params.slug, req.params.postSlug);
  return ok(res, post);
}));

// ---- Administration du site / blog : authentifié ----
const router = Router();
router.use(requireAuth);

router.get('/settings', requirePerm('website:view'), wrap(async (req, res) => {
  const settings = await websiteService.getSettings(req.user.pharmacyId);
  return ok(res, settings);
}));

router.put('/settings', requirePerm('website:edit'), validate({
  body: Joi.object({
    heroTitle: Joi.string().max(300).allow(null, ''),
    heroSubtitle: Joi.string().max(500).allow(null, ''),
    about: Joi.string().max(5000).allow(null, ''),
    services: Joi.array().items(Joi.object().unknown(true)),
    photos: Joi.array().items(Joi.string().max(500)),
    videoUrl: Joi.string().max(500).allow(null, ''),
    social: Joi.object().unknown(true),
    openingHours: Joi.array().items(Joi.object().unknown(true)),
    customCss: Joi.string().allow(null, ''),
  }),
}), wrap(async (req, res) => {
  const settings = await websiteService.saveSettings(req.user.pharmacyId, req.body, req.user);
  return ok(res, settings);
}));

router.get('/blog/categories', requirePerm('website:view'), wrap(async (req, res) => {
  const categories = await websiteService.listCategories(req.user.pharmacyId);
  return ok(res, categories);
}));

router.post('/blog/categories', requirePerm('website:create'), validate({
  body: Joi.object({
    name: Joi.string().max(200).required(),
    slug: Joi.string().max(200).allow(''),
  }),
}), wrap(async (req, res) => {
  const category = await websiteService.createCategory(req.user.pharmacyId, req.body, req.user);
  return created(res, category);
}));

router.get('/blog/posts', requirePerm('website:view'), validate({
  query: Joi.object({
    page: Joi.number().integer().min(1).default(1),
    limit: Joi.number().integer().min(1).max(200).default(20),
    isPublished: Joi.alternatives().try(Joi.boolean(), Joi.string().valid('true', 'false')),
  }),
}), wrap(async (req, res) => {
  const result = await websiteService.listPosts(req.user.pharmacyId, req.query);
  return ok(res, result.items, result.meta);
}));

router.post('/blog/posts', requirePerm('website:create'), validate({
  body: Joi.object({
    categoryId: Joi.string().uuid().allow(null),
    title: Joi.string().max(300).required(),
    slug: Joi.string().max(300).allow(''),
    excerpt: Joi.string().max(500).allow(null, ''),
    content: Joi.string().required(),
    imageUrl: Joi.string().max(500).allow(null, ''),
    isPublished: Joi.boolean().default(false),
    seo: Joi.object().unknown(true),
  }),
}), wrap(async (req, res) => {
  const post = await websiteService.createPost(req.user.pharmacyId, req.body, req.user);
  return created(res, post);
}));

router.put('/blog/posts/:id', requirePerm('website:edit'), validate({
  body: Joi.object({
    categoryId: Joi.string().uuid().allow(null),
    title: Joi.string().max(300),
    slug: Joi.string().max(300),
    excerpt: Joi.string().max(500).allow(null, ''),
    content: Joi.string(),
    imageUrl: Joi.string().max(500).allow(null, ''),
    isPublished: Joi.boolean(),
    seo: Joi.object().unknown(true),
  }),
}), wrap(async (req, res) => {
  const post = await websiteService.updatePost(req.user.pharmacyId, req.params.id, req.body, req.user);
  return ok(res, post);
}));

router.delete('/blog/posts/:id', requirePerm('website:delete'), wrap(async (req, res) => {
  await websiteService.removePost(req.user.pharmacyId, req.params.id, req.user);
  return noContent(res);
}));

export const websiteRouter = router;
