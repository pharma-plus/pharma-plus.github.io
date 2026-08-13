import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import Joi from 'joi';
import { validate } from '../../middleware/validate.js';
import { requireAuth } from '../../middleware/auth.js';
import { wrap } from '../../middleware/error.js';
import { ok, noContent } from '../../utils/response.js';
import { authService } from './service.js';

const router = Router();

const deviceSchema = Joi.object({
  name: Joi.string().max(120).allow(null, ''),
  type: Joi.string().max(40).allow(null, ''),
  userAgent: Joi.string().max(300).allow(null, ''),
});

const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, error: { code: 'RATE_LIMIT', message: 'Trop de tentatives. Réessayez dans 15 minutes.' } },
});

const buildDevice = (req) => ({
  name: req.body?.device?.name ?? null,
  type: req.body?.device?.type ?? null,
  userAgent: req.body?.device?.userAgent ?? req.get('user-agent'),
  ip: req.ip,
});

router.post('/login', loginLimiter, validate({
  body: Joi.object({
    email: Joi.string().email().required(),
    password: Joi.string().min(8).required(),
    device: deviceSchema,
  }),
}), wrap(async (req, res) => {
  const result = await authService.login(
    req.body.email, req.body.password, buildDevice(req),
  );
  return ok(res, result);
}));

router.post('/2fa/verify', validate({
  body: Joi.object({
    twoFactorToken: Joi.string().required(),
    code: Joi.string().pattern(/^\d{6}$/).required(),
    device: deviceSchema,
  }),
}), wrap(async (req, res) => {
  const result = await authService.verifyTwoFactor(
    req.body.twoFactorToken, req.body.code, buildDevice(req),
  );
  return ok(res, result);
}));

router.post('/refresh', validate({
  body: Joi.object({
    refreshToken: Joi.string().required(),
    device: deviceSchema,
  }),
}), wrap(async (req, res) => {
  const result = await authService.refresh(req.body.refreshToken, buildDevice(req));
  return ok(res, result);
}));

router.post('/logout', requireAuth, wrap(async (req, res) => {
  await authService.logout(req.sessionId);
  return noContent(res);
}));

router.get('/me', requireAuth, wrap(async (req, res) => {
  const me = await authService.me(req.user.id);
  return ok(res, me);
}));

router.post('/change-password', requireAuth, validate({
  body: Joi.object({
    currentPassword: Joi.string().required(),
    newPassword: Joi.string().min(8).max(128).required(),
  }),
}), wrap(async (req, res) => {
  await authService.changePassword(req.user.id, req.body.currentPassword, req.body.newPassword);
  return ok(res, { message: 'Mot de passe mis à jour' });
}));

router.get('/2fa/setup', requireAuth, wrap(async (req, res) => {
  const setup = await authService.setupTwoFactor(req.user.id);
  return ok(res, setup);
}));

router.post('/2fa/confirm', requireAuth, validate({
  body: Joi.object({ code: Joi.string().pattern(/^\d{6}$/).required() }),
}), wrap(async (req, res) => {
  await authService.confirmTwoFactor(req.user.id, req.body.code);
  return ok(res, { enabled: true });
}));

router.post('/2fa/disable', requireAuth, validate({
  body: Joi.object({ code: Joi.string().pattern(/^\d{6}$/).required() }),
}), wrap(async (req, res) => {
  await authService.disableTwoFactor(req.user.id, req.body.code);
  return ok(res, { enabled: false });
}));

export const authRouter = router;
