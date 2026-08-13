import { query } from '../../db/pool.js';
import { auditLog } from '../../middleware/audit.js';
import { NotFoundError } from '../../utils/errors.js';
import { paginate } from '../../utils/response.js';

export const attendanceService = {
  async list(pharmacyId, { page = 1, limit = 20, from, to, status, branchId, employeeId }) {
    const pg = paginate(page, limit);
    const where = ['a.pharmacy_id = $1'];
    const params = [pharmacyId];
    let i = 2;
    if (from) { where.push(`a.date >= $${i}`); params.push(from); i++; }
    if (to) { where.push(`a.date <= $${i}`); params.push(to); i++; }
    if (status) { where.push(`a.status = $${i}`); params.push(status); i++; }
    if (branchId) { where.push(`a.branch_id = $${i}`); params.push(branchId); i++; }
    if (employeeId) { where.push(`a.employee_id = $${i}`); params.push(employeeId); i++; }

    const count = await query(`SELECT count(*)::int AS total FROM attendance a WHERE ${where.join(' AND ')}`, params);
    const { rows } = await query(
      `SELECT a.id, a.employee_id, e.first_name, e.last_name, e.position,
              a.branch_id, b.name AS branch_name, a.date, a.clock_in, a.clock_out,
              a.break_start, a.break_end, a.method, a.status, a.late_minutes,
              a.overtime_minutes, a.hours_worked, a.notes
         FROM attendance a
         JOIN employees e ON e.id = a.employee_id
         LEFT JOIN branches b ON b.id = a.branch_id
        WHERE ${where.join(' AND ')}
        ORDER BY a.date DESC, e.last_name
        LIMIT $${i} OFFSET $${i + 1}`,
      [...params, pg.limit, pg.offset],
    );
    return { items: rows, meta: { ...pg, total: count.rows[0].total } };
  },

  /** Pointage d'entrée. Crée la ligne du jour si absente. */
  async clockIn(pharmacyId, employeeId, data, actor) {
    const { rows: emp } = await query(
      'SELECT id, branch_id FROM employees WHERE id = $1 AND pharmacy_id = $2 AND status = $3',
      [employeeId, pharmacyId, 'active'],
    );
    if (!emp[0]) throw new NotFoundError('Employé actif introuvable');

    const branchId = data.branchId ?? emp[0].branch_id;
    const { rows } = await query(
      `INSERT INTO attendance (pharmacy_id, branch_id, employee_id, date, clock_in, method)
       VALUES ($1,$2,$3,CURRENT_DATE,$4,$5)
       ON CONFLICT (employee_id, date)
       DO UPDATE SET clock_in = COALESCE(attendance.clock_in, EXCLUDED.clock_in)
       RETURNING id, date, clock_in, status`,
      [pharmacyId, branchId, employeeId, data.at ?? new Date().toISOString(), data.method ?? 'pin'],
    );
    await auditLog({ pharmacyId, userId: actor?.id, action: 'clock_in', module: 'attendance', entity: 'attendance', entityId: rows[0].id });
    return rows[0];
  },

  /** Pointage de sortie : calcule heures, retards, heures sup. */
  async clockOut(pharmacyId, employeeId, data, actor) {
    const { rows } = await query(
      `SELECT id, clock_in FROM attendance
        WHERE employee_id = $1 AND pharmacy_id = $2 AND date = CURRENT_DATE`,
      [employeeId, pharmacyId],
    );
    if (!rows[0] || !rows[0].clock_in) throw new NotFoundError('Aucun pointage d’entrée aujourd’hui');

    const out = data.at ? new Date(data.at) : new Date();
    const inMs = new Date(rows[0].clock_in).getTime();
    const workedMs = Math.max(0, out.getTime() - inMs);
    const hoursWorked = +(workedMs / 3600000).toFixed(2);
    const lateMinutes = computeLateMinutes(rows[0].clock_in);
    const overtimeMinutes = hoursWorked > 8 ? Math.round((hoursWorked - 8) * 60) : 0;

    const { rows: updated } = await query(
      `UPDATE attendance
          SET clock_out = $3, hours_worked = $4,
              late_minutes = GREATEST(late_minutes, $5),
              overtime_minutes = $6,
              status = CASE WHEN $4 >= 7 THEN 'present' ELSE 'half_day' END
        WHERE id = $1 AND pharmacy_id = $2
        RETURNING id, date, clock_in, clock_out, hours_worked, late_minutes, overtime_minutes, status`,
      [rows[0].id, pharmacyId, out.toISOString(), hoursWorked, lateMinutes, overtimeMinutes],
    );
    await auditLog({ pharmacyId, userId: actor?.id, action: 'clock_out', module: 'attendance', entity: 'attendance', entityId: rows[0].id });
    return updated[0];
  },

  /** Saisie manuelle / correction. */
  async upsertManual(pharmacyId, data, actor) {
    const { rows: emp } = await query('SELECT id FROM employees WHERE id = $1 AND pharmacy_id = $2', [data.employeeId, pharmacyId]);
    if (!emp[0]) throw new NotFoundError('Employé introuvable');

    const clockIn = data.clockIn ? new Date(data.clockIn).toISOString() : null;
    const clockOut = data.clockOut ? new Date(data.clockOut).toISOString() : null;
    let hoursWorked = data.hoursWorked ?? 0;
    if (clockIn && clockOut) {
      hoursWorked = +((new Date(clockOut) - new Date(clockIn)) / 3600000).toFixed(2);
    }
    const { rows } = await query(
      `INSERT INTO attendance (pharmacy_id, branch_id, employee_id, date, clock_in, clock_out,
                               break_start, break_end, method, status, late_minutes, overtime_minutes, hours_worked, notes)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,'manual',$9,$10,$11,$12,$13)
       ON CONFLICT (employee_id, date)
       DO UPDATE SET clock_in = EXCLUDED.clock_in, clock_out = EXCLUDED.clock_out,
                     break_start = EXCLUDED.break_start, break_end = EXCLUDED.break_end,
                     status = EXCLUDED.status, late_minutes = EXCLUDED.late_minutes,
                     overtime_minutes = EXCLUDED.overtime_minutes, hours_worked = EXCLUDED.hours_worked,
                     notes = EXCLUDED.notes
       RETURNING id, date, clock_in, clock_out, status, hours_worked`,
      [pharmacyId, data.branchId ?? null, data.employeeId, data.date, clockIn, clockOut,
       data.breakStart ? new Date(data.breakStart).toISOString() : null,
       data.breakEnd ? new Date(data.breakEnd).toISOString() : null,
       data.status ?? 'present', data.lateMinutes ?? 0, data.overtimeMinutes ?? 0, hoursWorked, data.notes ?? null],
    );
    await auditLog({ pharmacyId, userId: actor?.id, action: 'edit', module: 'attendance', entity: 'attendance', entityId: rows[0].id, newValues: data });
    return rows[0];
  },

  // ---- Congés ----
  async leaves(pharmacyId, { page = 1, limit = 20, status, employeeId }) {
    const pg = paginate(page, limit);
    const where = ['l.pharmacy_id = $1'];
    const params = [pharmacyId];
    let i = 2;
    if (status) { where.push(`l.status = $${i}`); params.push(status); i++; }
    if (employeeId) { where.push(`l.employee_id = $${i}`); params.push(employeeId); i++; }
    const count = await query(`SELECT count(*)::int AS total FROM leaves l WHERE ${where.join(' AND ')}`, params);
    const { rows } = await query(
      `SELECT l.*, e.first_name, e.last_name, e.position
         FROM leaves l JOIN employees e ON e.id = l.employee_id
        WHERE ${where.join(' AND ')}
        ORDER BY l.start_date DESC LIMIT $${i} OFFSET $${i + 1}`,
      [...params, pg.limit, pg.offset],
    );
    return { items: rows, meta: { ...pg, total: count.rows[0].total } };
  },

  async requestLeave(pharmacyId, data, actor) {
    const days = Math.round((new Date(data.endDate) - new Date(data.startDate)) / 86400000) + 1;
    const { rows } = await query(
      `INSERT INTO leaves (pharmacy_id, employee_id, leave_type, start_date, end_date, days, reason, approved_by)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
       RETURNING *`,
      [pharmacyId, data.employeeId, data.leaveType, data.startDate, data.endDate, Math.max(1, days),
       data.reason ?? null, actor?.id],
    );
    await auditLog({ pharmacyId, userId: actor?.id, action: 'create', module: 'attendance', entity: 'leave', entityId: rows[0].id, newValues: data });
    return rows[0];
  },

  async decideLeave(pharmacyId, id, decision, actor) {
    const { rows } = await query(
      `UPDATE leaves SET status = $1, approved_by = $2 WHERE id = $3 AND pharmacy_id = $4
       RETURNING *`,
      [decision, actor?.id, id, pharmacyId],
    );
    if (!rows[0]) throw new NotFoundError('Demande de congé introuvable');
    await auditLog({ pharmacyId, userId: actor?.id, action: decision, module: 'attendance', entity: 'leave', entityId: id, newValues: { decision } });
    return rows[0];
  },

  // ---- Plannings ----
  async setSchedule(pharmacyId, data, actor) {
    const { rows } = await query(
      `INSERT INTO schedules (pharmacy_id, employee_id, day_of_week, start_time, end_time)
       VALUES ($1,$2,$3,$4,$5)
       ON CONFLICT (employee_id, day_of_week)
       DO UPDATE SET start_time = EXCLUDED.start_time, end_time = EXCLUDED.end_time
       RETURNING *`,
      [pharmacyId, data.employeeId, data.dayOfWeek, data.startTime, data.endTime],
    );
    await auditLog({ pharmacyId, userId: actor?.id, action: 'edit', module: 'attendance', entity: 'schedule', entityId: rows[0].id, newValues: data });
    return rows[0];
  },

  async employeeSchedule(pharmacyId, employeeId) {
    const { rows } = await query(
      'SELECT id, day_of_week, start_time, end_time FROM schedules WHERE employee_id = $1 AND pharmacy_id = $2 ORDER BY day_of_week',
      [employeeId, pharmacyId],
    );
    return rows;
  },

  /** Synthèse mensuelle (pour la paie). */
  async monthlySummary(pharmacyId, month) {
    const key = month || new Date().toISOString().slice(0, 7);
    const { rows } = await query(
      `SELECT e.id AS employee_id, e.first_name, e.last_name,
              count(a.id) AS working_days,
              COALESCE(sum(a.hours_worked), 0)::numeric(5,2) AS total_hours,
              count(*) FILTER (WHERE a.status = 'late')::int AS late_days,
              sum(a.late_minutes)::int AS total_late_minutes,
              sum(a.overtime_minutes)::int AS total_overtime_minutes,
              count(*) FILTER (WHERE a.status = 'absent')::int AS absences,
              (SELECT count(*)::int FROM leaves l WHERE l.employee_id = e.id
                AND l.status IN ('approved','pending')
                AND to_char(l.start_date, 'YYYY-MM') = $2) AS leave_days
         FROM employees e
         LEFT JOIN attendance a ON a.employee_id = e.id
           AND to_char(a.date, 'YYYY-MM') = $2
        WHERE e.pharmacy_id = $1
        GROUP BY e.id
        ORDER BY e.last_name`,
      [pharmacyId, key],
    );
    return { month: key, rows };
  },
};

/** Retard (minutes) vs 9h00 par défaut. */
export function computeLateMinutes(clockIn) {
  const d = new Date(clockIn);
  const ref = new Date(d);
  ref.setHours(9, 0, 0, 0);
  return d > ref ? Math.round((d - ref) / 60000) : 0;
}
