import { query } from '../../db/pool.js';
import { auditLog } from '../../middleware/audit.js';
import { NotFoundError, ConflictError, ValidationError } from '../../utils/errors.js';
import { uuid } from '../../utils/crypto.js';

const EVENT_TYPES = ['entry', 'exit', 'refund', 'correction'];

const sumBy = (rows, fn) => rows.reduce((s, r) => s + Number(fn(r) ?? 0), 0);

const cardSplit = (payRows) => {
  const cash = sumBy(payRows.filter((p) => p.method === 'cash'), (p) => p.amount);
  const visa = sumBy(
    payRows.filter((p) => p.method === 'card' && String(p.card_type ?? '').toLowerCase() === 'visa'),
    (p) => p.amount,
  );
  const mastercard = sumBy(
    payRows.filter((p) => p.method === 'card' && String(p.card_type ?? '').toLowerCase() === 'mastercard'),
    (p) => p.amount,
  );
  const other = sumBy(payRows.filter((p) => p.method !== 'cash' && p.method !== 'card'), (p) => p.amount);
  return { cash, visa, mastercard, other };
};

export const cashSessionService = {
  async getOpenSession(pharmacyId, branchId) {
    const params = [pharmacyId];
    let sql = `SELECT cs.*, b.name AS branch_name, u.first_name, u.last_name
                 FROM cash_sessions cs
                 LEFT JOIN branches b ON b.id = cs.branch_id
                 LEFT JOIN users u ON u.id = cs.user_id
                WHERE cs.pharmacy_id = $1 AND cs.status = 'OUVERTE'`;
    if (branchId) {
      params.push(branchId);
      sql += ` AND cs.branch_id = $${params.length}`;
    }
    sql += ' ORDER BY cs.opened_at DESC LIMIT 1';
    const { rows } = await query(sql, params);
    const session = rows[0];
    if (!session) return null;

    const { rows: salesRows } = await query(
      'SELECT id, total, payment_method FROM sales WHERE cash_session_id = $1',
      [session.id],
    );
    const saleIds = salesRows.map((s) => s.id);
    let payRows = [];
    if (saleIds.length) {
      const { rows } = await query(
        'SELECT method, card_type, amount FROM payments WHERE sale_id = ANY($1::uuid[])',
        [saleIds],
      );
      payRows = rows;
    }
    const { rows: events } = await query(
      `SELECT event_type, amount, method, note, created_at
         FROM cash_session_events WHERE session_id = $1
        ORDER BY created_at DESC LIMIT 100`,
      [session.id],
    );

    const { cash, visa, mastercard, other } = cardSplit(payRows);
    const entries = sumBy(events.filter((e) => e.event_type === 'entry'), (e) => e.amount);
    const exits = sumBy(events.filter((e) => e.event_type === 'exit'), (e) => e.amount);
    const refunds = sumBy(events.filter((e) => e.event_type === 'refund'), (e) => e.amount);
    const expected = Number(session.initial_cash ?? 0) + cash + entries - exits - refunds;

    return {
      session,
      salesCount: salesRows.length,
      salesTotal: sumBy(salesRows, (s) => s.total),
      cashSales: Number(cash.toFixed(2)),
      cardVisa: Number(visa.toFixed(2)),
      cardMastercard: Number(mastercard.toFixed(2)),
      otherPayments: Number(other.toFixed(2)),
      entries: Number(entries.toFixed(2)),
      exits: Number(exits.toFixed(2)),
      refunds: Number(refunds.toFixed(2)),
      expectedCash: Number(expected.toFixed(2)),
      events,
    };
  },

  async openSession(pharmacyId, data, actor) {
    const { rows: open } = await query(
      `SELECT id FROM cash_sessions
        WHERE pharmacy_id = $1 AND branch_id = $2 AND status = 'OUVERTE'`,
      [pharmacyId, data.branchId],
    );
    if (open[0]) throw new ConflictError('Une caisse est déjà ouverte pour ce point de vente');

    const { rows: numRow } = await query(
      `SELECT fn_next_number($1, 'CAISSE') AS number`,
      [pharmacyId],
    );
    const initialCash = data.initialCash ?? data.initialBalance ?? 0;
    const id = uuid();
    const { rows } = await query(
      `INSERT INTO cash_sessions (id, pharmacy_id, branch_id, user_id, number, initial_cash, notes)
       VALUES ($1,$2,$3,$4,$5,$6,$7)
       RETURNING *`,
      [id, pharmacyId, data.branchId, actor?.id,
        numRow[0]?.number ?? `CAISSE-${Date.now()}`, initialCash, data.notes ?? null],
    );
    await auditLog({
      pharmacyId, userId: actor?.id, action: 'cash_session_open', module: 'cash',
      entity: 'cash_sessions', entityId: id,
      newValues: { branchId: data.branchId, initial_cash: initialCash },
    });
    return rows[0];
  },

  async addEvent(sessionId, data, actor) {
    const eventType = data.eventType ?? data.event_type;
    if (!EVENT_TYPES.includes(eventType)) {
      throw new ValidationError([{ field: 'eventType', message: 'Type d\'événement invalide' }]);
    }
    const { rows } = await query(
      `SELECT id, pharmacy_id FROM cash_sessions WHERE id = $1`,
      [sessionId],
    );
    const session = rows[0];
    if (!session) throw new NotFoundError('Session de caisse introuvable');
    if (session.status !== 'OUVERTE') throw new ConflictError('Caisse déjà fermée');

    const { rows: events } = await query(
      `INSERT INTO cash_session_events (id, pharmacy_id, session_id, event_type, amount, method, note, user_id)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
       RETURNING *`,
      [uuid(), session.pharmacy_id, sessionId, eventType, data.amount ?? 0,
        data.method ?? 'cash', data.note ?? data.notes ?? null, actor?.id],
    );
    await auditLog({
      pharmacyId: session.pharmacy_id, userId: actor?.id, action: 'cash_event',
      module: 'cash', entity: 'cash_session_events', entityId: events[0].id,
      newValues: { eventType, amount: data.amount ?? 0 },
    });
    return events[0];
  },

  async closeSession(sessionId, data, actor) {
    const { rows } = await query('SELECT * FROM cash_sessions WHERE id = $1', [sessionId]);
    const session = rows[0];
    if (!session) throw new NotFoundError('Session de caisse introuvable');
    if (session.status !== 'OUVERTE') throw new ConflictError('Caisse déjà fermée');

    const { rows: salesRows } = await query(
      'SELECT id, total, payment_method FROM sales WHERE cash_session_id = $1',
      [sessionId],
    );
    const saleIds = salesRows.map((s) => s.id);
    let payRows = [];
    if (saleIds.length) {
      const { rows: pr } = await query(
        'SELECT method, card_type, amount FROM payments WHERE sale_id = ANY($1::uuid[])',
        [saleIds],
      );
      payRows = pr;
    }
    const { rows: events } = await query(
      'SELECT event_type, amount FROM cash_session_events WHERE session_id = $1',
      [sessionId],
    );

    const { cash, visa, mastercard, other } = cardSplit(payRows);
    const entries = sumBy(events.filter((e) => e.event_type === 'entry'), (e) => e.amount);
    const exits = sumBy(events.filter((e) => e.event_type === 'exit'), (e) => e.amount);
    const refunds = sumBy(events.filter((e) => e.event_type === 'refund'), (e) => e.amount);
    const expected = Number(session.initial_cash ?? 0) + cash + entries - exits - refunds;
    const counted = Number(data.countedCash ?? data.finalBalance ?? 0);
    const difference = Number((counted - expected).toFixed(2));

    const { rows: closed } = await query(
      `UPDATE cash_sessions
          SET status = 'FERMEE', closed_at = now(), closed_by = $1,
              expected_cash = $2, counted_cash = $3, difference = $4,
              totals_cash = $5, totals_card_visa = $6, totals_card_mastercard = $7,
              totals_other = $8, notes = COALESCE($9, notes)
        WHERE id = $10 AND status = 'OUVERTE'
        RETURNING *`,
      [actor?.id, Number(expected.toFixed(2)), counted, difference,
        Number(cash.toFixed(2)), Number(visa.toFixed(2)),
        Number(mastercard.toFixed(2)), Number(other.toFixed(2)),
        data.notes ?? null, sessionId],
    );
    if (!closed[0]) throw new NotFoundError('Caisse ouverte introuvable');

    await query(
      `INSERT INTO cash_audits (pharmacy_id, branch_id, expected_cash, counted_cash, difference,
                                sales_total, payments_cash, payments_card, payments_other, notes,
                                user_id, cash_session_id)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)`,
      [session.pharmacy_id, session.branch_id, Number(expected.toFixed(2)), counted, difference,
        sumBy(salesRows, (s) => s.total), Number(cash.toFixed(2)),
        Number((visa + mastercard).toFixed(2)), Number(other.toFixed(2)),
        `Fermeture caisse ${session.number ?? ''}`.trim(), actor?.id, sessionId],
    );
    await auditLog({
      pharmacyId: session.pharmacy_id, userId: actor?.id, action: 'cash_session_close',
      module: 'cash', entity: 'cash_sessions', entityId: sessionId,
      oldValues: { status: 'OUVERTE' },
      newValues: { status: 'FERMEE', expected, counted, difference },
    });
    return closed[0];
  },

  async getGlobalStats(pharmacyId) {
    const { rows } = await query(
      `SELECT status, count(*)::int AS sessions,
              COALESCE(sum(counted_cash), 0)::numeric(14,2) AS counted_total,
              COALESCE(sum(difference), 0)::numeric(14,2) AS difference_total
         FROM cash_sessions
        WHERE pharmacy_id = $1
        GROUP BY status
        ORDER BY status`,
      [pharmacyId],
    );
    const byStatus = Object.fromEntries(rows.map((r) => [r.status, r]));
    return {
      open: byStatus.OUVERTE ?? { status: 'OUVERTE', sessions: 0, counted_total: 0, difference_total: 0 },
      closed: byStatus.FERMEE ?? { status: 'FERMEE', sessions: 0, counted_total: 0, difference_total: 0 },
      rows,
    };
  },
};
