import { query } from '../../db/pool.js';
import { auditLog } from '../../middleware/audit.js';
import { NotFoundError } from '../../utils/errors.js';
import { uuid } from '../../utils/crypto.js';
import { paginate } from '../../utils/response.js';

export const employeesService = {
  async list(pharmacyId, { page = 1, limit = 20, q, status, branchId, position }) {
    const pg = paginate(page, limit);
    const where = ['e.pharmacy_id = $1'];
    const params = [pharmacyId];
    let i = 2;
    if (q) { where.push(`(e.first_name ILIKE $${i} OR e.last_name ILIKE $${i} OR e.cin ILIKE $${i} OR e.phone ILIKE $${i})`); params.push(`%${q}%`); i++; }
    if (status) { where.push(`e.status = $${i}`); params.push(status); i++; }
    if (branchId) { where.push(`e.branch_id = $${i}`); params.push(branchId); i++; }
    if (position) { where.push(`e.position ILIKE $${i}`); params.push(`%${position}%`); i++; }

    const count = await query(`SELECT count(*)::int AS total FROM employees e WHERE ${where.join(' AND ')}`, params);
    const { rows } = await query(
      `SELECT e.*, b.name AS branch_name,
              (SELECT count(*)::int FROM employee_documents d WHERE d.employee_id = e.id) AS nb_documents,
              (SELECT COALESCE(sum(b2.amount),0)::numeric(14,2) FROM bonuses b2 WHERE b2.employee_id = e.id) AS total_bonuses
         FROM employees e
         LEFT JOIN branches b ON b.id = e.branch_id
        WHERE ${where.join(' AND ')}
        ORDER BY e.last_name, e.first_name
        LIMIT $${i} OFFSET $${i + 1}`,
      [...params, pg.limit, pg.offset],
    );
    return { items: rows, meta: { ...pg, total: count.rows[0].total } };
  },

  async get(pharmacyId, id) {
    const { rows } = await query(
      `SELECT e.*, b.name AS branch_name
         FROM employees e LEFT JOIN branches b ON b.id = e.branch_id
        WHERE e.id = $1 AND e.pharmacy_id = $2`,
      [id, pharmacyId],
    );
    if (!rows[0]) throw new NotFoundError('Employé introuvable');
    const employee = rows[0];

    const [documents, bonuses, evaluations, attendance] = await Promise.all([
      query('SELECT id, title, doc_type, file_url, uploaded_at FROM employee_documents WHERE employee_id = $1 ORDER BY uploaded_at DESC', [id]),
      query('SELECT id, amount, bonus_date, reason, created_at FROM bonuses WHERE employee_id = $1 ORDER BY bonus_date DESC', [id]),
      query('SELECT id, eval_date, score, comments, created_at FROM evaluations WHERE employee_id = $1 ORDER BY eval_date DESC', [id]),
      query(
        `SELECT date, clock_in, clock_out, status, late_minutes, overtime_minutes, hours_worked, notes
           FROM attendance WHERE employee_id = $1 AND pharmacy_id = $2
          ORDER BY date DESC LIMIT 60`, [id, pharmacyId]),
    ]);
    return { ...employee, documents: documents.rows, bonuses: bonuses.rows, evaluations: evaluations.rows, attendance: attendance.rows };
  },

  async create(pharmacyId, data, actor) {
    const id = uuid();
    await query(
      `INSERT INTO employees (id, pharmacy_id, branch_id, user_id, photo_url, first_name, last_name,
                              phone, email, cin, position, salary, hire_date, contract_type, status, notes)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16)`,
      [id, pharmacyId, data.branchId ?? null, data.userId ?? null, data.photoUrl ?? null,
       data.firstName, data.lastName, data.phone ?? null, data.email ?? null, data.cin ?? null,
       data.position, data.salary ?? 0, data.hireDate ?? null, data.contractType ?? null,
       data.status ?? 'active', data.notes ?? null],
    );
    await auditLog({ pharmacyId, userId: actor?.id, action: 'create', module: 'employees', entity: 'employee', entityId: id, newValues: { firstName: data.firstName, lastName: data.lastName } });
    return this.get(pharmacyId, id);
  },

  async update(pharmacyId, id, data, actor) {
    const existing = await this.get(pharmacyId, id);
    const fields = [];
    const params = [id, pharmacyId];
    let i = 3;
    const map = {
      branchId: 'branch_id', userId: 'user_id', photoUrl: 'photo_url', firstName: 'first_name',
      lastName: 'last_name', phone: 'phone', email: 'email', cin: 'cin', position: 'position',
      salary: 'salary', hireDate: 'hire_date', contractType: 'contract_type', status: 'status', notes: 'notes',
    };
    for (const [key, value] of Object.entries(data)) {
      if (!(key in map) || value === undefined) continue;
      fields.push(`${map[key]} = $${i}`);
      params.push(value);
      i++;
    }
    if (fields.length) {
      await query(`UPDATE employees SET ${fields.join(', ')}, updated_at = now() WHERE id = $1 AND pharmacy_id = $2`, params);
    }
    await auditLog({ pharmacyId, userId: actor?.id, action: 'edit', module: 'employees', entity: 'employee', entityId: id, oldValues: { name: `${existing.first_name} ${existing.last_name}` }, newValues: data });
    return this.get(pharmacyId, id);
  },

  async remove(pharmacyId, id, actor) {
    const existing = await this.get(pharmacyId, id);
    await query('DELETE FROM employees WHERE id = $1 AND pharmacy_id = $2', [id, pharmacyId]);
    await auditLog({ pharmacyId, userId: actor?.id, action: 'delete', module: 'employees', entity: 'employee', entityId: id, newValues: { name: `${existing.first_name} ${existing.last_name}` } });
  },

  async addDocument(pharmacyId, employeeId, data, actor) {
    await this.get(pharmacyId, employeeId);
    const id = uuid();
    await query(
      `INSERT INTO employee_documents (id, pharmacy_id, employee_id, title, doc_type, file_url)
       VALUES ($1,$2,$3,$4,$5,$6)`,
      [id, pharmacyId, employeeId, data.title, data.docType, data.fileUrl],
    );
    await auditLog({ pharmacyId, userId: actor?.id, action: 'create', module: 'employees', entity: 'employee_document', entityId: id, newValues: { title: data.title } });
    return { id, title: data.title, docType: data.docType };
  },

  async removeDocument(pharmacyId, employeeId, documentId, actor) {
    await this.get(pharmacyId, employeeId);
    await query(
      'DELETE FROM employee_documents WHERE id = $1 AND employee_id = $2',
      [documentId, employeeId],
    );
    await auditLog({ pharmacyId, userId: actor?.id, action: 'delete', module: 'employees', entity: 'employee_document', entityId: documentId });
  },

  async addBonus(pharmacyId, employeeId, data, actor) {
    await this.get(pharmacyId, employeeId);
    const id = uuid();
    await query(
      `INSERT INTO bonuses (id, pharmacy_id, employee_id, amount, bonus_date, reason, created_by)
       VALUES ($1,$2,$3,$4,$5,$6,$7)`,
      [id, pharmacyId, employeeId, data.amount, data.bonusDate ?? null, data.reason ?? null, actor?.id],
    );
    await auditLog({ pharmacyId, userId: actor?.id, action: 'create', module: 'employees', entity: 'bonus', entityId: id, newValues: { amount: data.amount } });
    return { id, amount: data.amount };
  },

  async addEvaluation(pharmacyId, employeeId, data, actor) {
    await this.get(pharmacyId, employeeId);
    const id = uuid();
    await query(
      `INSERT INTO evaluations (id, pharmacy_id, employee_id, eval_date, score, comments, by_user)
       VALUES ($1,$2,$3,$4,$5,$6,$7)`,
      [id, pharmacyId, employeeId, data.evalDate ?? null, data.score ?? null, data.comments ?? null, actor?.id],
    );
    await auditLog({ pharmacyId, userId: actor?.id, action: 'create', module: 'employees', entity: 'evaluation', entityId: id, newValues: { score: data.score } });
    return { id, score: data.score };
  },

  /** Récapitulatif RH pour la paie / les rapports. */
  async summary(pharmacyId) {
    const { rows } = await query(
      `SELECT
         count(*) FILTER (WHERE status = 'active')::int AS active_count,
         count(*)::int AS total_count,
         COALESCE(sum(salary) FILTER (WHERE status = 'active'), 0)::numeric(14,2) AS monthly_mass,
         count(*) FILTER (WHERE status = 'on_leave')::int AS on_leave_count,
         (SELECT count(*)::int FROM employees e2 WHERE e2.pharmacy_id = $1
            AND e2.hire_date >= date_trunc('month', CURRENT_DATE)) AS hired_this_month
        FROM employees WHERE pharmacy_id = $1`,
      [pharmacyId],
    );
    return rows[0];
  },
};
