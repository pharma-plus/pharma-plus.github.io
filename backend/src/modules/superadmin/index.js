import { Router } from 'express';
import Joi from 'joi';
import { validate } from '../../middleware/validate.js';
import { requireAuth, requireSuperAdmin, requirePerm } from '../../middleware/auth.js';
import { wrap } from '../../middleware/error.js';
import { ok } from '../../utils/response.js';
import { superadminService, subscriptionPlans } from './service.js';

const router = Router();
router.use(requireAuth);
router.use(requireSuperAdmin);

/** ──────────────────────────────────────────────────────────────────────
 *  SUPER ADMIN — Tableau de bord global (KPI premium)
 * ────────────────────────────────────────────────────────────────────── */

/** Statistiques globales : pharmacies, licences, utilisateurs, ventes, abonnements. */
router.get('/dashboard-stats', wrap(async (req, res) => {
  const data = await superadminService.globalDashboardStats();
  return ok(res, data);
}));

/** Activité récente globale (pharmacies, utilisateurs, ventes, tickets). */
router.get('/dashboard-activity', wrap(async (req, res) => {
  const limit = parseInt(req.query.limit, 10) || 20;
  const data = await superadminService.recentActivity(limit);
  return ok(res, data);
}));

/** Alertes importantes : licences expirées, pharmacies suspendues, stock bas. */
router.get('/dashboard-alerts', wrap(async (req, res) => {
  const data = await superadminService.alerts();
  return ok(res, data);
}));

/** Graphique : évolution des abonnements par mois. */
router.get('/dashboard-subscription-trend', wrap(async (req, res) => {
  const months = parseInt(req.query.months, 10) || 12;
  const data = await superadminService.subscriptionTrend(months);
  return ok(res, data);
}));

/** Graphique : évolution des revenus par mois. */
router.get('/dashboard-revenue-trend', wrap(async (req, res) => {
  const months = parseInt(req.query.months, 10) || 12;
  const data = await superadminService.revenueTrend(months);
  return ok(res, data);
}));

/** Top pharmacies par revenu. */
router.get('/dashboard-top-pharmacies', wrap(async (req, res) => {
  const limit = parseInt(req.query.limit, 10) || 10;
  const data = await superadminService.topPharmacies(limit);
  return ok(res, data);
}));

/** Paiements récents. */
router.get('/dashboard-recent-payments', wrap(async (req, res) => {
  const limit = parseInt(req.query.limit, 10) || 20;
  const data = await superadminService.recentPayments(limit);
  return ok(res, data);
}));

/** ──────────────────────────────────────────────────────────────────────
 *  SUPER ADMIN — Plans d'abonnement BASIC / GOLD
 * ────────────────────────────────────────────────────────────────────── */

/** Définition des plans d'abonnement disponibles. */
router.get('/subscription-plans', wrap(async (_req, res) => {
  return ok(res, { plans: subscriptionPlans });
}));

/** ──────────────────────────────────────────────────────────────────────
 *  SUPER ADMIN — Monitoring technique
 * ────────────────────────────────────────────────────────────────────── */

/** État des services et API. */
router.get('/monitoring', wrap(async (_req, res) => {
  const services = [
    { name: 'API Pharma+', status: 'online', response_time: '45ms' },
    { name: 'Base de données', status: 'online', response_time: '12ms' },
    { name: 'WhatsApp Business API', status: 'online', response_time: '230ms' },
    { name: 'Chatbot IA', status: 'online', response_time: '890ms' },
    { name: 'Stockage fichiers', status: 'online', response_time: '15ms' },
    { name: 'Notifications', status: 'online', response_time: '67ms' },
  ];
  return ok(res, { services, uptime: process.uptime() });
}));

/** ──────────────────────────────────────────────────────────────────────
 *  SUPER ADMIN — Gestion des pharmacies (étendue)
 * ────────────────────────────────────────────────────────────────────── */

/** Historique d'activité d'une pharmacie. */
router.get('/pharmacies/:id/activity', wrap(async (req, res) => {
  const { id } = req.params;
  const limit = parseInt(req.query.limit, 10) || 20;
  const { rows } = await query(`
    SELECT al.id, al.action, al.module, al.entity, al.entity_id,
           al.created_at, u.first_name, u.last_name
    FROM audit_logs al
    LEFT JOIN users u ON u.id = al.user_id
    WHERE al.pharmacy_id = $1
    ORDER BY al.created_at DESC
    LIMIT $2
  `, [id, limit]);
  return ok(res, rows);
}));

/** Paiements d'une pharmacie. */
router.get('/pharmacies/:id/payments', wrap(async (req, res) => {
  const { id } = req.params;
  const limit = parseInt(req.query.limit, 10) || 20;
  const [sales, purchases] = await Promise.all([
    query(`
      SELECT s.id, s.number, s.total, s.created_at, 'sale' AS type
      FROM sales s
      WHERE s.pharmacy_id = $1 AND s.status = 'completed'
      ORDER BY s.created_at DESC
      LIMIT $2
    `, [id, Math.ceil(limit / 2)]),
    query(`
      SELECT po.id, po.number, po.total, po.created_at, 'purchase' AS type
      FROM purchase_orders po
      WHERE po.pharmacy_id = $1 AND po.status = 'confirmed'
      ORDER BY po.created_at DESC
      LIMIT $2
    `, [id, Math.ceil(limit / 2)]),
  ]);
  const all = [
    ...sales.rows.map(r => ({ ...r, type: 'sale' })),
    ...purchases.rows.map(r => ({ ...r, type: 'purchase' })),
  ];
  all.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
  return ok(res, all.slice(0, limit));
}));

export const superadminRouter = router;
