import { Router } from 'express';
import Joi from 'joi';
import { validate } from '../../middleware/validate.js';
import { requireAuth, requirePerm } from '../../middleware/auth.js';
import { wrap } from '../../middleware/error.js';
import { ok, created } from '../../utils/response.js';
import { accountingService } from './service.js';

const router = Router();
router.use(requireAuth);

const periodQuery = {
  page: Joi.number().integer().min(1).default(1),
  limit: Joi.number().integer().min(1).max(200).default(20),
  from: Joi.date().iso(),
  to: Joi.date().iso(),
};

// ---- Plan comptable ----
router.get('/accounts', requirePerm('accounting:view'), wrap(async (req, res) => {
  const accounts = await accountingService.accounts(req.user.pharmacyId);
  return ok(res, accounts);
}));

router.post('/accounts', requirePerm('accounting:create'), validate({
  body: Joi.object({
    code: Joi.string().max(20).required(),
    name: Joi.string().max(200).required(),
    type: Joi.string().valid('asset', 'liability', 'equity', 'revenue', 'expense').required(),
    parentId: Joi.string().uuid().allow(null),
  }),
}), wrap(async (req, res) => {
  const account = await accountingService.createAccount(req.user.pharmacyId, req.body, req.user);
  return created(res, account);
}));

// ---- Écritures ----
router.get('/journal', requirePerm('accounting:view'), validate({
  query: Joi.object({
    ...periodQuery,
    journalType: Joi.string().valid('cash', 'bank', 'sales', 'purchases', 'general', 'closing'),
  }),
}), wrap(async (req, res) => {
  const result = await accountingService.listEntries(req.user.pharmacyId, req.query);
  return ok(res, result.items, result.meta);
}));

router.get('/journal/:id', requirePerm('accounting:view'), wrap(async (req, res) => {
  const entry = await accountingService.getEntry(req.user.pharmacyId, req.params.id);
  return ok(res, entry);
}));

router.post('/journal', requirePerm('accounting:create'), validate({
  body: Joi.object({
    branchId: Joi.string().uuid().allow(null),
    entryDate: Joi.date().allow(null),
    journalType: Joi.string().valid('cash', 'bank', 'sales', 'purchases', 'general', 'closing').default('general'),
    description: Joi.string().max(500).allow(null, ''),
    sourceModule: Joi.string().max(100).allow(null, ''),
    sourceId: Joi.string().max(100).allow(null, ''),
    lines: Joi.array().items(Joi.object({
      accountId: Joi.string().uuid().required(),
      label: Joi.string().max(300).allow(null, ''),
      debit: Joi.number().min(0).default(0),
      credit: Joi.number().min(0).default(0),
    })).min(2).required(),
  }),
}), wrap(async (req, res) => {
  const entry = await accountingService.createEntry(req.user.pharmacyId, req.body, req.user);
  return created(res, entry);
}));

router.get('/trial-balance', requirePerm('accounting:view'), validate({
  query: Joi.object({ from: Joi.date().iso(), to: Joi.date().iso() }),
}), wrap(async (req, res) => {
  const balance = await accountingService.trialBalance(req.user.pharmacyId, req.query);
  return ok(res, balance);
}));

// ---- Caisse ----
router.get('/registers/:branchId/open', requirePerm('accounting:view'), wrap(async (req, res) => {
  const register = await accountingService.getOpenRegister(req.user.pharmacyId, req.params.branchId);
  return ok(res, register);
}));

router.post('/registers', requirePerm('accounting:create'), validate({
  body: Joi.object({
    branchId: Joi.string().uuid().required(),
    openingBalance: Joi.number().min(0).default(0),
    notes: Joi.string().max(300).allow(null, ''),
  }),
}), wrap(async (req, res) => {
  const register = await accountingService.openRegister(req.user.pharmacyId, req.body, req.user);
  return created(res, register);
}));

router.post('/registers/:id/movements', requirePerm('accounting:edit'), validate({
  body: Joi.object({
    movementType: Joi.string().valid('in', 'out', 'sale', 'expense', 'refund').required(),
    amount: Joi.number().positive().required(),
    reason: Joi.string().max(300).allow(null, ''),
    referenceId: Joi.string().max(100).allow(null, ''),
  }),
}), wrap(async (req, res) => {
  const movement = await accountingService.addMovement(req.user.pharmacyId, req.params.id, req.body, req.user);
  return created(res, movement);
}));

router.post('/registers/:id/close', requirePerm('accounting:edit'), validate({
  body: Joi.object({
    countedBalance: Joi.number().min(0).required(),
    notes: Joi.string().max(300).allow(null, ''),
  }),
}), wrap(async (req, res) => {
  const register = await accountingService.closeRegister(req.user.pharmacyId, req.params.id, req.body, req.user);
  return ok(res, register);
}));

// ---- Dépenses ----
router.get('/expense-categories', requirePerm('accounting:view'), wrap(async (req, res) => {
  const categories = await accountingService.expenseCategories(req.user.pharmacyId);
  return ok(res, categories);
}));

router.post('/expense-categories', requirePerm('accounting:create'), validate({
  body: Joi.object({ name: Joi.string().max(200).required() }),
}), wrap(async (req, res) => {
  const category = await accountingService.createExpenseCategory(req.user.pharmacyId, req.body, req.user);
  return created(res, category);
}));

router.get('/expenses', requirePerm('accounting:view'), validate({
  query: Joi.object({
    ...periodQuery,
    categoryId: Joi.string().uuid(),
    branchId: Joi.string().uuid(),
  }),
}), wrap(async (req, res) => {
  const result = await accountingService.listExpenses(req.user.pharmacyId, req.query);
  return ok(res, result.items, result.meta);
}));

router.post('/expenses', requirePerm('accounting:create'), validate({
  body: Joi.object({
    branchId: Joi.string().uuid().allow(null),
    categoryId: Joi.string().uuid().allow(null),
    amount: Joi.number().positive().required(),
    expenseDate: Joi.date().allow(null),
    description: Joi.string().max(500).allow(null, ''),
    supplierId: Joi.string().uuid().allow(null),
    receiptUrl: Joi.string().max(500).allow(null, ''),
  }),
}), wrap(async (req, res) => {
  const expense = await accountingService.createExpense(req.user.pharmacyId, req.body, req.user);
  return created(res, expense);
}));

// ---- Clôtures ----
router.post('/closings', requirePerm('accounting:approve'), validate({
  body: Joi.object({
    periodType: Joi.string().valid('month', 'year').required(),
    periodKey: Joi.string().pattern(/^\d{4}(-\d{2})?$/).required(),
  }),
}), wrap(async (req, res) => {
  const closing = await accountingService.closePeriod(req.user.pharmacyId, req.body, req.user);
  return ok(res, closing);
}));

export const accountingRouter = router;
