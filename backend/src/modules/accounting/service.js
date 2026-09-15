import { query } from '../../db/pool.js';
import { auditLog } from '../../middleware/audit.js';
import { NotFoundError, ValidationError } from '../../utils/errors.js';
import { uuid } from '../../utils/crypto.js';
import { paginate } from '../../utils/response.js';

export const accountingService = {
  // ---- Plan comptable ----
  async accounts(pharmacyId) {
    const { rows } = await query(
      `SELECT id, code, name, type, parent_id, is_system, created_at
         FROM accounts WHERE pharmacy_id = $1
        ORDER BY code`,
      [pharmacyId],
    );
    return rows;
  },

  async createAccount(pharmacyId, data, actor) {
    const id = uuid();
    await query(
      `INSERT INTO accounts (id, pharmacy_id, code, name, type, parent_id, is_system)
       VALUES ($1,$2,$3,$4,$5,$6,false)`,
      [id, pharmacyId, data.code, data.name, data.type, data.parentId ?? null],
    );
    await auditLog({ pharmacyId, userId: actor?.id, action: 'create', module: 'accounting', entity: 'account', entityId: id, newValues: { code: data.code, name: data.name } });
    return this.getAccount(pharmacyId, id);
  },

  async getAccount(pharmacyId, id) {
    const { rows } = await query(
      'SELECT * FROM accounts WHERE id = $1 AND pharmacy_id = $2',
      [id, pharmacyId],
    );
    if (!rows[0]) throw new NotFoundError('Compte comptable introuvable');
    return rows[0];
  },

  // ---- Écritures ----
  async listEntries(pharmacyId, { page = 1, limit = 20, from, to, journalType }) {
    const pg = paginate(page, limit);
    const where = ['je.pharmacy_id = $1'];
    const params = [pharmacyId];
    let i = 2;
    if (from) { where.push(`je.entry_date >= $${i}`); params.push(from); i++; }
    if (to) { where.push(`je.entry_date <= $${i}`); params.push(to); i++; }
    if (journalType) { where.push(`je.journal_type = $${i}`); params.push(journalType); i++; }
    const count = await query(`SELECT count(*)::int AS total FROM journal_entries je WHERE ${where.join(' AND ')}`, params);
    const { rows } = await query(
      `SELECT je.id, je.entry_number, je.entry_date, je.journal_type, je.description,
              je.source_module, je.is_posted, je.posted_at,
              (SELECT COALESCE(sum(jl.debit),0)::numeric(14,2) FROM journal_lines jl WHERE jl.entry_id = je.id) AS debit_total,
              (SELECT COALESCE(sum(jl.credit),0)::numeric(14,2) FROM journal_lines jl WHERE jl.entry_id = je.id) AS credit_total
         FROM journal_entries je
        WHERE ${where.join(' AND ')}
        ORDER BY je.entry_date DESC, je.posted_at DESC
        LIMIT $${i} OFFSET $${i + 1}`,
      [...params, pg.limit, pg.offset],
    );
    return { items: rows, meta: { ...pg, total: count.rows[0].total } };
  },

  async getEntry(pharmacyId, id) {
    const { rows } = await query(
      'SELECT * FROM journal_entries WHERE id = $1 AND pharmacy_id = $2',
      [id, pharmacyId],
    );
    if (!rows[0]) throw new NotFoundError('Écriture introuvable');
    const { rows: lines } = await query(
      `SELECT jl.id, jl.account_id, a.code, a.name, jl.label, jl.debit, jl.credit
         FROM journal_lines jl JOIN accounts a ON a.id = jl.account_id
        WHERE jl.entry_id = $1
        ORDER BY jl.id`,
      [id],
    );
    return { ...rows[0], lines };
  },

  /** Écriture équilibrée : débits = crédits obligatoire. */
  async createEntry(pharmacyId, data, actor) {
    const debit = data.lines.reduce((s, l) => s + (l.debit || 0), 0);
    const credit = data.lines.reduce((s, l) => s + (l.credit || 0), 0);
    if (Math.abs(debit - credit) > 0.005) {
      throw new ValidationError([{ field: 'lines', message: 'L’écriture doit être équilibrée (débits = crédits)' }]);
    }
    const entryNumber = await nextEntryNumber(pharmacyId, data.journalType);
    const entryId = uuid();
    await query(
      `INSERT INTO journal_entries (id, pharmacy_id, branch_id, entry_number, entry_date,
                                    journal_type, description, source_module, source_id, created_by)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
      [entryId, pharmacyId, data.branchId ?? null, entryNumber, data.entryDate ?? new Date().toISOString().slice(0, 10),
       data.journalType ?? 'general', data.description ?? null, data.sourceModule ?? null,
       data.sourceId ?? null, actor?.id],
    );
    for (const line of data.lines) {
      await query(
        `INSERT INTO journal_lines (entry_id, pharmacy_id, account_id, label, debit, credit)
         VALUES ($1,$2,$3,$4,$5,$6)`,
        [entryId, pharmacyId, line.accountId, line.label ?? null, line.debit ?? 0, line.credit ?? 0],
      );
    }
    await auditLog({ pharmacyId, userId: actor?.id, action: 'create', module: 'accounting', entity: 'journal_entry', entityId: entryId, newValues: { entryNumber, debit, credit } });
    return this.getEntry(pharmacyId, entryId);
  },

  // ---- Caisse ----
  async openRegister(pharmacyId, data, actor) {
    const { rows: open } = await query(
      'SELECT id FROM cash_registers WHERE branch_id = $1 AND status = $2',
      [data.branchId, 'open'],
    );
    if (open[0]) throw new ValidationError([{ field: 'branchId', message: 'Une caisse est déjà ouverte pour ce point de vente' }]);
    const id = uuid();
    const { rows } = await query(
      `INSERT INTO cash_registers (id, pharmacy_id, branch_id, user_id, opening_balance, notes)
       VALUES ($1,$2,$3,$4,$5,$6)
       RETURNING *`,
      [id, pharmacyId, data.branchId, actor?.id, data.openingBalance ?? 0, data.notes ?? null],
    );
    await auditLog({ pharmacyId, userId: actor?.id, action: 'open', module: 'accounting', entity: 'cash_register', entityId: id, newValues: { openingBalance: data.openingBalance } });
    return rows[0];
  },

  async getOpenRegister(pharmacyId, branchId) {
    const { rows } = await query(
      `SELECT cr.*, u.first_name, u.last_name
         FROM cash_registers cr LEFT JOIN users u ON u.id = cr.user_id
        WHERE cr.pharmacy_id = $1 AND cr.branch_id = $2 AND cr.status = 'open'`,
      [pharmacyId, branchId],
    );
    if (!rows[0]) throw new NotFoundError('Aucune caisse ouverte pour ce point de vente');
    const { rows: movements } = await query(
      `SELECT id, movement_type, amount, reason, reference_id, created_by, created_at
         FROM cash_register_movements WHERE register_id = $1 ORDER BY created_at`,
      [rows[0].id],
    );
    return { ...rows[0], movements, total_in: sumMovements(movements, 'in', 'sale'), total_out: sumMovements(movements, 'out', 'expense', 'refund') };
  },

  async addMovement(pharmacyId, registerId, data, actor) {
    const { rows } = await query(
      `INSERT INTO cash_register_movements (id, pharmacy_id, register_id, movement_type, amount, reason, reference_id, created_by)
       VALUES (gen_random_uuid(),$1,$2,$3,$4,$5,$6,$7)
       RETURNING *`,
      [pharmacyId, registerId, data.movementType, data.amount, data.reason ?? null, data.referenceId ?? null, actor?.id],
    );
    await auditLog({ pharmacyId, userId: actor?.id, action: data.movementType, module: 'accounting', entity: 'cash_register_movement', entityId: rows[0].id, newValues: { amount: data.amount } });
    return rows[0];
  },

  async closeRegister(pharmacyId, id, data, actor) {
    const { rows } = await query(
      `UPDATE cash_registers
          SET status = 'closed', closed_at = now(),
              counted_balance = $1, difference = $1 - expected_balance,
              validated_by = $2, notes = COALESCE($3, notes)
        WHERE id = $4 AND pharmacy_id = $5 AND status = 'open'
        RETURNING *`,
      [data.countedBalance, actor?.id, data.notes ?? null, id, pharmacyId],
    );
    if (!rows[0]) throw new NotFoundError('Caisse ouverte introuvable');
    await auditLog({ pharmacyId, userId: actor?.id, action: 'close', module: 'accounting', entity: 'cash_register', entityId: id, newValues: { countedBalance: data.countedBalance } });
    return rows[0];
  },

  // ---- Dépenses ----
  async expenseCategories(pharmacyId) {
    const { rows } = await query(
      'SELECT id, name FROM expense_categories WHERE pharmacy_id = $1 ORDER BY name',
      [pharmacyId],
    );
    return rows;
  },

  async createExpenseCategory(pharmacyId, data, actor) {
    const { rows } = await query(
      `INSERT INTO expense_categories (id, pharmacy_id, name)
       VALUES (gen_random_uuid(), $1, $2) RETURNING *`,
      [pharmacyId, data.name],
    );
    await auditLog({ pharmacyId, userId: actor?.id, action: 'create', module: 'accounting', entity: 'expense_category', entityId: rows[0].id, newValues: { name: data.name } });
    return rows[0];
  },

  async listExpenses(pharmacyId, { page = 1, limit = 20, from, to, categoryId, branchId }) {
    const pg = paginate(page, limit);
    const where = ['e.pharmacy_id = $1'];
    const params = [pharmacyId];
    let i = 2;
    if (from) { where.push(`e.expense_date >= $${i}`); params.push(from); i++; }
    if (to) { where.push(`e.expense_date <= $${i}`); params.push(to); i++; }
    if (categoryId) { where.push(`e.category_id = $${i}`); params.push(categoryId); i++; }
    if (branchId) { where.push(`e.branch_id = $${i}`); params.push(branchId); i++; }
    const count = await query(`SELECT count(*)::int AS total FROM expenses e WHERE ${where.join(' AND ')}`, params);
    const { rows } = await query(
      `SELECT e.*, ec.name AS category_name, b.name AS branch_name
         FROM expenses e
         LEFT JOIN expense_categories ec ON ec.id = e.category_id
         LEFT JOIN branches b ON b.id = e.branch_id
        WHERE ${where.join(' AND ')}
        ORDER BY e.expense_date DESC, e.created_at DESC
        LIMIT $${i} OFFSET $${i + 1}`,
      [...params, pg.limit, pg.offset],
    );
    return { items: rows, meta: { ...pg, total: count.rows[0].total } };
  },

  async createExpense(pharmacyId, data, actor) {
    const id = uuid();
    await query(
      `INSERT INTO expenses (id, pharmacy_id, branch_id, category_id, amount, expense_date, description, supplier_id, receipt_url, created_by)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
      [id, pharmacyId, data.branchId ?? null, data.categoryId ?? null, data.amount,
       data.expenseDate ?? new Date().toISOString().slice(0, 10), data.description ?? null,
       data.supplierId ?? null, data.receiptUrl ?? null, actor?.id],
    );
    await auditLog({ pharmacyId, userId: actor?.id, action: 'create', module: 'accounting', entity: 'expense', entityId: id, newValues: { amount: data.amount, description: data.description } });
    const { rows } = await query(
      `SELECT e.*, ec.name AS category_name FROM expenses e
        LEFT JOIN expense_categories ec ON ec.id = e.category_id
        WHERE e.id = $1 AND e.pharmacy_id = $2`,
      [id, pharmacyId],
    );
    return rows[0];
  },

  // ---- Clôtures ----
  async closePeriod(pharmacyId, data, actor) {
    const { rows } = await query(
      `INSERT INTO closing_periods (pharmacy_id, period_type, period_key, closed_by)
       VALUES ($1,$2,$3,$4)
       ON CONFLICT (pharmacy_id, period_type, period_key) DO NOTHING
       RETURNING *`,
      [pharmacyId, data.periodType, data.periodKey, actor?.id],
    );
    await auditLog({ pharmacyId, userId: actor?.id, action: 'close_period', module: 'accounting', entity: 'closing_period', entityId: rows[0]?.id, newValues: data });
    return rows[0] ?? { period_type: data.periodType, period_key: data.periodKey, already_closed: true };
  },

  /** Grand livre simplifié sur une période. */
  async trialBalance(pharmacyId, { from, to }) {
    const { rows } = await query(
      `SELECT a.id, a.code, a.name, a.type,
              COALESCE(sum(jl.debit),0)::numeric(14,2) AS total_debit,
              COALESCE(sum(jl.credit),0)::numeric(14,2) AS total_credit,
              (COALESCE(sum(jl.debit),0) - COALESCE(sum(jl.credit),0))::numeric(14,2) AS balance
         FROM accounts a
         LEFT JOIN journal_lines jl ON jl.account_id = a.id
         LEFT JOIN journal_entries je ON je.id = jl.entry_id AND je.is_posted
        WHERE a.pharmacy_id = $1 AND ($2::date IS NULL OR je.entry_date >= $2)
          AND ($3::date IS NULL OR je.entry_date <= $3)
        GROUP BY a.id, a.code, a.name, a.type
        ORDER BY a.code`,
      [pharmacyId, from ?? null, to ?? null],
    );
    return rows;
  },
};

async function nextEntryNumber(pharmacyId, journalType) {
  const prefix = {
    cash: 'EC', bank: 'EB', sales: 'EV', purchases: 'EA',
    general: 'EG', closing: 'CL',
  }[journalType] || 'EG';
  const { rows } = await query(
    `SELECT COALESCE(MAX(entry_number), '') AS last FROM journal_entries WHERE pharmacy_id = $1`,
    [pharmacyId],
  );
  const last = rows[0].last || '';
  const year = new Date().getFullYear();
  const re = new RegExp(`^${prefix}-${year}-(\\d+)$`);
  const match = last.match(re);
  const seq = match ? parseInt(match[1], 10) + 1 : 1;
  return `${prefix}-${year}-${String(seq).padStart(6, '0')}`;
}

function sumMovements(movements, ...types) {
  return movements
    .filter((m) => types.includes(m.movement_type))
    .reduce((s, m) => s + Number(m.amount), 0);
}
