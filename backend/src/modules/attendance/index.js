import { Router } from 'express';
import Joi from 'joi';
import { validate } from '../../middleware/validate.js';
import { requireAuth, requirePerm } from '../../middleware/auth.js';
import { wrap } from '../../middleware/error.js';
import { ok, created } from '../../utils/response.js';
import { attendanceService } from './service.js';

const router = Router();
router.use(requireAuth);

router.get('/', requirePerm('attendance:view'), validate({
  query: Joi.object({
    page: Joi.number().integer().min(1).default(1),
    limit: Joi.number().integer().min(1).max(200).default(20),
    from: Joi.date(),
    to: Joi.date(),
    status: Joi.string().valid('present', 'late', 'absent', 'half_day', 'leave'),
    branchId: Joi.string().uuid(),
    employeeId: Joi.string().uuid(),
  }),
}), wrap(async (req, res) => {
  const result = await attendanceService.list(req.user.pharmacyId, req.query);
  return ok(res, result.items, result.meta);
}));

router.post('/clock-in', requirePerm('attendance:edit'), validate({
  body: Joi.object({
    employeeId: Joi.string().uuid().required(),
    branchId: Joi.string().uuid().allow(null),
    method: Joi.string().valid('pin', 'qr', 'biometric', 'face', 'manual').default('pin'),
    at: Joi.date(),
  }),
}), wrap(async (req, res) => {
  const record = await attendanceService.clockIn(req.user.pharmacyId, req.body.employeeId, req.body, req.user);
  return ok(res, record);
}));

router.post('/clock-out', requirePerm('attendance:edit'), validate({
  body: Joi.object({
    employeeId: Joi.string().uuid().required(),
    at: Joi.date(),
  }),
}), wrap(async (req, res) => {
  const record = await attendanceService.clockOut(req.user.pharmacyId, req.body.employeeId, req.body, req.user);
  return ok(res, record);
}));

router.post('/manual', requirePerm('attendance:edit'), validate({
  body: Joi.object({
    employeeId: Joi.string().uuid().required(),
    branchId: Joi.string().uuid().allow(null),
    date: Joi.date().required(),
    clockIn: Joi.date().allow(null),
    clockOut: Joi.date().allow(null),
    breakStart: Joi.date().allow(null),
    breakEnd: Joi.date().allow(null),
    status: Joi.string().valid('present', 'late', 'absent', 'half_day', 'leave'),
    lateMinutes: Joi.number().integer().min(0),
    overtimeMinutes: Joi.number().integer().min(0),
    hoursWorked: Joi.number().min(0),
    notes: Joi.string().max(300).allow(null, ''),
  }),
}), wrap(async (req, res) => {
  const record = await attendanceService.upsertManual(req.user.pharmacyId, req.body, req.user);
  return ok(res, record);
}));

router.get('/leaves', requirePerm('attendance:view'), validate({
  query: Joi.object({
    page: Joi.number().integer().min(1).default(1),
    limit: Joi.number().integer().min(1).max(200).default(20),
    status: Joi.string().valid('pending', 'approved', 'rejected', 'cancelled'),
    employeeId: Joi.string().uuid(),
  }),
}), wrap(async (req, res) => {
  const result = await attendanceService.leaves(req.user.pharmacyId, req.query);
  return ok(res, result.items, result.meta);
}));

router.post('/leaves', requirePerm('attendance:create'), validate({
  body: Joi.object({
    employeeId: Joi.string().uuid().required(),
    leaveType: Joi.string().valid('annual', 'sick', 'maternity', 'unpaid', 'other').required(),
    startDate: Joi.date().required(),
    endDate: Joi.date().required(),
    reason: Joi.string().max(500).allow(null, ''),
  }),
}), wrap(async (req, res) => {
  const leave = await attendanceService.requestLeave(req.user.pharmacyId, req.body, req.user);
  return created(res, leave);
}));

router.post('/leaves/:id/decide', requirePerm('attendance:approve'), validate({
  body: Joi.object({ decision: Joi.string().valid('approved', 'rejected', 'cancelled').required() }),
}), wrap(async (req, res) => {
  const leave = await attendanceService.decideLeave(req.user.pharmacyId, req.params.id, req.body.decision, req.user);
  return ok(res, leave);
}));

router.put('/schedules', requirePerm('attendance:edit'), validate({
  body: Joi.object({
    employeeId: Joi.string().uuid().required(),
    dayOfWeek: Joi.number().integer().min(0).max(6).required(),
    startTime: Joi.string().pattern(/^\d{2}:\d{2}(:\d{2})?$/).required(),
    endTime: Joi.string().pattern(/^\d{2}:\d{2}(:\d{2})?$/).required(),
  }),
}), wrap(async (req, res) => {
  const schedule = await attendanceService.setSchedule(req.user.pharmacyId, req.body, req.user);
  return ok(res, schedule);
}));

router.get('/employees/:employeeId/schedule', requirePerm('attendance:view'), wrap(async (req, res) => {
  const schedule = await attendanceService.employeeSchedule(req.user.pharmacyId, req.params.employeeId);
  return ok(res, schedule);
}));

router.get('/summary', requirePerm('attendance:view'), validate({
  query: Joi.object({ month: Joi.string().pattern(/^\d{4}-\d{2}$/) }),
}), wrap(async (req, res) => {
  const summary = await attendanceService.monthlySummary(req.user.pharmacyId, req.query.month);
  return ok(res, summary);
}));

export const attendanceRouter = router;
