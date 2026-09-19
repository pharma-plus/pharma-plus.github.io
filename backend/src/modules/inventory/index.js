import { Router } from 'express';
import Joi from 'joi';
import { query, withTransaction } from '../../db/pool.js';
import { validate } from '../../middleware/validate.js';
import { requireAuth, requirePerm } from '../../middleware/auth.js';
import { wrap } from '../../middleware/error.js';
import { ok, created } from '../../utils/response.js';
import { auditLog } from '../../middleware/audit.js';
import { NotFoundError, AppError } from '../../utils/errors.js';
import { uuid } from '../../utils/crypto.js';
import { insertMovement } from '../stock/service.js';
import { paginate } from '../../utils/response.js';

const router = Router();
router.use(requireAuth);

/* ------------------------------------------------------------------ */
/* Audit STOCK (inventaire physique) — sessions inventaire réelles.    */
/* Comparaison stock système vs stock physique. AUCUNE modification    */
/* automatique du stock : la correction n'est appliquée qu'après la    */
/* validation explicite du pharmacien (permission inventory:approve).  */
/* ------------------------------------------------------------------ */

router.get('/sessions', requirePerm('inventory:view'), validate({
  query: Joi.object({
    page: Joi.number().integer().min(1).default(1),
    limit: Joi.number().integer().min(1).max(200).default(20),
    branchId: Joi.string().uuid(),
    status: Joi.string().valid('open', 'closed', 'cancelled'),
  }),
}), wrap(async (req, res) => {
  const pg = paginate(req.query.page, req.query.limit);
  const where = ['s.pharmacy_id = $1'];
  const params = [req.user.pharmacyId];
  let i = 2;
  if (req.query.branchId) { where.push(`s.branch_id = $${i}`); params.push(req.query.branchId); i++; }
  if (req.query.status) { where.push(`s.status = $${i}`); params.push(req.query.status); i++; }
  const count = await query(
    `SELECT count(*)::int AS total FROM inventory_sessions s WHERE ${where.join(' AND ')}`, params);
  const { rows } = await query(
    `SELECT s.*, b.name AS branch_name, u1.first_name || ' ' || u1.last_name AS started_by_name,
            u2.first_name || ' ' || u2.last_name AS closed_by_name,
            (SELECT count(*)::int FROM inventory_items it WHERE it.session_id = s.id) AS items_count,
            (SELECT count(*)::int FROM inventory_items it WHERE it.session_id = s.id AND it.difference <> 0) AS gaps_count
       FROM inventory_sessions s
       JOIN branches b ON b.id = s.branch_id
       LEFT JOIN users u1 ON u1.id = s.started_by
       LEFT JOIN users u2 ON u2.id = s.closed_by
      WHERE ${where.join(' AND ')}
      ORDER BY s.started_at DESC
      LIMIT $${i} OFFSET $${i + 1}`,
    [...params, pg.limit, pg.offset]);
  return ok(res, rows, { ...pg, total: count.rows[0].total });
}));

router.post('/sessions', requirePerm('inventory:create'), validate({
  body: Joi.object({
    branchId: Joi.string().uuid().required(),
    notes: Joi.string().max(500).allow(null, ''),
    withItems: Joi.boolean().default(true),
  }),
}), wrap(async (req, res) => {
  const { branchId, notes, withItems } = req.body;
  const id = await withTransaction(req.user.pharmacyId, async (client) => {
    const sessionId = uuid();
    await client.query(
      `INSERT INTO inventory_sessions (id, pharmacy_id, branch_id, started_by, notes)
       VALUES ($1,$2,$3,$4,$5)`,
      [sessionId, req.user.pharmacyId, branchId, req.user.id, notes ?? null],
    );
    if (withItems) {
      // Instantané du stock SYSTÈME à l'ouverture : les écarts sont ensuite
      // saisis (comptage physique), jamais déduits automatiquement ici.
      await client.query(
        `INSERT INTO inventory_items
           (pharmacy_id, session_id, medication_id, lot_id, system_qty, counted_qty)
         SELECT $1, $2, sb.medication_id, sb.lot_id, sb.quantity, sb.quantity
           FROM stock_balances sb
          WHERE sb.pharmacy_id = $1 AND sb.branch_id = $3 AND sb.quantity > 0`,
        [req.user.pharmacyId, sessionId, branchId],
      );
    }
    await auditLog({
      pharmacyId: req.user.pharmacyId, userId: req.user.id, action: 'create',
      module: 'inventory', entity: 'inventory_session', entityId: sessionId,
      newValues: { branchId },
    });
    return sessionId;
  });
  return created(res, { id });
}));

router.get('/sessions/:id', requirePerm('inventory:view'), wrap(async (req, res) => {
  const s = (await query(
    `SELECT s.*, b.name AS branch_name, u1.first_name || ' ' || u1.last_name AS started_by_name,
            u2.first_name || ' ' || u2.last_name AS closed_by_name
       FROM inventory_sessions s
       JOIN branches b ON b.id = s.branch_id
       LEFT JOIN users u1 ON u1.id = s.started_by
       LEFT JOIN users u2 ON u2.id = s.closed_by
      WHERE s.id = $1 AND s.pharmacy_id = $2`,
    [req.params.id, req.user.pharmacyId])).rows[0];
  if (!s) throw new NotFoundError('Session introuvable');
  const { rows } = await query(
    `SELECT it.*, m.name AS medication_name, m.barcode_ean13, m.price_sale,
            l.lot_number, l.expiry_date, l.cost_price,
            (it.counted_qty - it.system_qty) AS gap,
            ((it.counted_qty - it.system_qty) * COALESCE(l.cost_price, 0)) AS gap_value
       FROM inventory_items it
       JOIN medications m ON m.id = it.medication_id
       LEFT JOIN lots l ON l.id = it.lot_id
      WHERE it.session_id = $1
      ORDER BY m.name`,
    [req.params.id]);
  return ok(res, { ...s, items: rows });
}));

/** Comptage / scan : enregistre la quantité physique SAISIE (aucun effet stock). */
router.post('/sessions/:id/count', requirePerm('inventory:create'), validate({
  body: Joi.object({
    itemId: Joi.string().uuid().required(),
    countedQty: Joi.number().min(0).required(),
  }),
}), wrap(async (req, res) => {
  const r = await query(
    `UPDATE inventory_items SET counted_qty = $1
      WHERE id = $2 AND pharmacy_id = $3 AND is_adjusted = false
      RETURNING id`,
    [req.body.countedQty, req.body.itemId, req.user.pharmacyId]);
  if (!r.rows[0]) throw new NotFoundError('Ligne introuvable ou déjà corrigée');
  return ok(res, { id: r.rows[0].id });
}));

/**
 * VALIDATION de l'inventaire : applique les corrections d'écarts sous forme
 * de mouvements réels (inventory_in / inventory_out + is_adjusted).
 * Réservée au pharmacien (inventory:approve). Journalisée (audit).
 */
router.post('/sessions/:id/close', requirePerm('inventory:approve'), validate({
  body: Joi.object({ notes: Joi.string().max(500).allow(null, '') }),
}), wrap(async (req, res) => {
  const result = await withTransaction(req.user.pharmacyId, async (client) => {
    const s = (await client.query(
      `SELECT * FROM inventory_sessions WHERE id = $1 AND pharmacy_id = $2 FOR UPDATE`,
      [req.params.id, req.user.pharmacyId])).rows[0];
    if (!s) throw new NotFoundError('Session introuvable');
    if (s.status !== 'open') throw new AppError('Session déjà clôturée', 409, 'CLOSED');

    const items = (await client.query(
      `SELECT it.*, l.cost_price
         FROM inventory_items it
         LEFT JOIN lots l ON l.id = it.lot_id
        WHERE it.session_id = $1 AND it.difference <> 0 AND it.is_adjusted = false
        FOR UPDATE OF it`,
      [req.params.id])).rows;

    let corrections = 0;
    for (const it of items) {
      const diff = Number(it.difference);
      // Mouvement signé : entrée si positif, sortie si négatif.
      await insertMovement(client, {
        pharmacyId: req.user.pharmacyId, branchId: s.branch_id,
        medicationId: it.medication_id, lotId: it.lot_id,
        type: diff > 0 ? 'inventory_in' : 'inventory_out',
        quantity: Math.abs(diff),
        unitCost: Number(it.cost_price ?? 0),
        referenceType: 'inventory_session', referenceId: s.id,
        userId: req.user.id, notes: 'Correction inventaire validée',
      });
      await client.query(
        `UPDATE inventory_items SET is_adjusted = true WHERE id = $1`, [it.id]);
      corrections++;
    }

    const done = (await client.query(
      `UPDATE inventory_sessions
          SET status = 'closed', closed_by = $2, closed_at = now(),
              notes = COALESCE($3, notes)
        WHERE id = $1 RETURNING *`,
      [req.params.id, req.user.id, req.body.notes ?? null])).rows[0];

    await auditLog({
      pharmacyId: req.user.pharmacyId, userId: req.user.id, action: 'close',
      module: 'inventory', entity: 'inventory_session', entityId: req.params.id,
      newValues: { corrections },
    });
    return { session: done, corrections };
  });
  return ok(res, result);
}));

/* ------------------------------------------------------------------ */
/* Audit CAISSE — comparaison attendu (système) vs compté (physique).  */
/* Aucune écriture comptable automatique : historique d'audit seul.    */
/* ------------------------------------------------------------------ */

/** Table additive, idempotente — garantie au premier appel. */
async function ensureCashAuditsTable(client) {
  await client.query(`CREATE TABLE IF NOT EXISTS cash_audits (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    pharmacy_id    uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
    branch_id      uuid NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    audit_date     date NOT NULL DEFAULT CURRENT_DATE,
    expected_cash  numeric(14,2) NOT NULL DEFAULT 0,
    counted_cash   numeric(14,2) NOT NULL DEFAULT 0,
    difference     numeric(14,2) NOT NULL DEFAULT 0,
    sales_total    numeric(14,2) NOT NULL DEFAULT 0,
    payments_cash  numeric(14,2) NOT NULL DEFAULT 0,
    payments_card  numeric(14,2) NOT NULL DEFAULT 0,
    payments_other numeric(14,2) NOT NULL DEFAULT 0,
    notes          text,
    user_id        uuid REFERENCES users(id) ON DELETE SET NULL,
    created_at     timestamptz NOT NULL DEFAULT now()
  )`);
}

/** SELECT client (la fonction ensure attend un objet .query) */
const queryClient = { query: (sql, params) => query(sql, params) };

router.get('/cash-audits', requirePerm('inventory:view'), wrap(async (req, res) => {
  await ensureCashAuditsTable(queryClient);
  const { rows } = await query(
    `SELECT ca.*, b.name AS branch_name, u.first_name || ' ' || u.last_name AS user_name
       FROM cash_audits ca
       JOIN branches b ON b.id = ca.branch_id
       LEFT JOIN users u ON u.id = ca.user_id
      WHERE ca.pharmacy_id = $1
      ORDER BY ca.created_at DESC LIMIT 50`,
    [req.user.pharmacyId]);
  return ok(res, rows);
}));

router.post('/cash-audits', requirePerm('inventory:create'), validate({
  body: Joi.object({
    branchId: Joi.string().uuid().required(),
    auditDate: Joi.date().iso().allow(null),
    expectedCash: Joi.number().min(0).required(),
    countedCash: Joi.number().min(0).required(),
    salesTotal: Joi.number().min(0).default(0),
    paymentsCash: Joi.number().min(0).default(0),
    paymentsCard: Joi.number().min(0).default(0),
    paymentsOther: Joi.number().min(0).default(0),
    notes: Joi.string().max(500).allow(null, ''),
  }),
}), wrap(async (req, res) => {
  const b = req.body;
  const difference = Number(b.countedCash) - Number(b.expectedCash);
  const newId = await withTransaction(req.user.pharmacyId, async (client) => {
    await ensureCashAuditsTable(client);
    const id = uuid();
    await client.query(
      `INSERT INTO cash_audits (id, pharmacy_id, branch_id, audit_date, expected_cash,
                                counted_cash, difference, sales_total, payments_cash,
                                payments_card, payments_other, notes, user_id)
       VALUES ($1,$2,$3,COALESCE($4, CURRENT_DATE),$5,$6,$7,$8,$9,$10,$11,$12,$13)`,
      [id, req.user.pharmacyId, b.branchId, b.auditDate ?? null, b.expectedCash,
       b.countedCash, difference, b.salesTotal ?? 0, b.paymentsCash ?? 0,
       b.paymentsCard ?? 0, b.paymentsOther ?? 0, b.notes ?? null, req.user.id]);
    await auditLog({
      pharmacyId: req.user.pharmacyId, userId: req.user.id, action: 'create',
      module: 'inventory', entity: 'cash_audit', entityId: id,
      newValues: { difference },
    });
    return id;
  });
  return created(res, { id: newId, difference });
}));

/** Attendu caisse RÉEL : ventes + paiements du jour par mode (aucune invention). */
router.get('/cash-expected', requirePerm('inventory:view'), validate({
  query: Joi.object({
    branchId: Joi.string().uuid(),
    date: Joi.date().iso(),
  }),
}), wrap(async (req, res) => {
  const day = req.query.date ?? new Date().toISOString().slice(0, 10);
  const branch = req.query.branchId ?? req.user.branchId;
  const where = [`s.pharmacy_id = $1`, `s.sale_date::date = $2::date`, `s.status = 'completed'`];
  const params = [req.user.pharmacyId, day];
  if (branch) { where.push(`s.branch_id = $3`); params.push(branch); }
  const { rows } = await query(
    `SELECT COALESCE(SUM(s.total), 0) AS sales_total,
            COALESCE(SUM((p.cash)->>'amount')::numeric, 0) AS payments_cash,
            COALESCE(SUM((p.card)->>'amount')::numeric, 0) AS payments_card,
            COALESCE(SUM((p.other)->>'amount')::numeric, 0) AS payments_other
       FROM sales s
       LEFT JOIN LATERAL (
         SELECT jsonb_agg(pb) FILTER (WHERE pb->>'method' = 'cash') AS cash,
                jsonb_agg(pb) FILTER (WHERE pb->>'method' = 'card') AS card,
                jsonb_agg(pb) FILTER (WHERE pb->>'method' NOT IN ('cash','card')) AS other
           FROM jsonb_array_elements(COALESCE(s.payments::jsonb, '[]'::jsonb)) pb
       ) p ON true
      WHERE ${where.join(' AND ')}`,
    params);
  const r = rows[0] ?? {};
  return ok(res, {
    date: day,
    salesTotal: Number(r.sales_total ?? 0),
    paymentsCash: Number(r.payments_cash ?? 0),
    paymentsCard: Number(r.payments_card ?? 0),
    paymentsOther: Number(r.payments_other ?? 0),
  });
}));

export const inventoryRouter = router;



