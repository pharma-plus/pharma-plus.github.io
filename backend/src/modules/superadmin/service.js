import { query, withTransaction } from '../../db/pool.js';
import { auditLog } from '../../middleware/audit.js';
import { AppError, NotFoundError } from '../../utils/errors.js';
import { ok, created } from '../../utils/response.js';
import { paginate } from '../../utils/response.js';

/**
 * Plan d'abonnement défini par PHARMA+.
 * Les différences entre BASIC et GOLD sont fonctionnelles (features, limites),
 * pas seulement tarifaires.
 */
const SUBSCRIPTION_PLANS = {
  basic: {
    id: 'basic',
    name: 'BASIC',
    nameFr: 'Basic',
    nameAr: 'باسيك',
    description: 'Offre d’entrée pour officine indépendante',
    priceMonthly: 499,   // MAD
    priceAnnual: 4990,   // MAD (2 mois offerts)
    maxUsers: 3,
    maxBranches: 1,
    features: [
      'catalog:view',
      'sales:view',
      'sales:create',
      'stock:view',
      'customers:view',
      'reports:view',
      'settings:view',
    ],
    featuresLocked: [
      'stock:create', 'stock:edit',
      'purchases:create', 'purchases:edit',
      'employees:create', 'employees:edit',
      'users:create', 'users:edit',
      'catalog:create', 'catalog:edit',
      'whatsapp:send',
      'chatbot:send',
      'ai:use',
      'reports:export',
      'multi_branch',
    ],
  },
  gold: {
    id: 'gold',
    name: 'GOLD',
    nameFr: 'Gold',
    nameAr: 'غولد',
    description: 'Offre complète pour groupe et grande officine',
    priceMonthly: 1299,  // MAD
    priceAnnual: 12990,  // MAD (2 mois offerts)
    maxUsers: 20,
    maxBranches: 10,
    features: [
      'catalog:view', 'catalog:create', 'catalog:edit',
      'sales:view', 'sales:create', 'sales:edit',
      'stock:view', 'stock:create', 'stock:edit',
      'customers:view', 'customers:create', 'customers:edit',
      'purchases:view', 'purchases:create', 'purchases:edit',
      'suppliers:view', 'suppliers:create', 'suppliers:edit',
      'employees:view', 'employees:create', 'employees:edit',
      'users:view', 'users:create', 'users:edit',
      'reports:view', 'reports:export',
      'settings:view', 'settings:edit',
      'whatsapp:view', 'whatsapp:send',
      'chatbot:view', 'chatbot:send',
      'ai:use',
      'multi_branch',
    ],
    featuresLocked: [],
  },
};

export const superadminService = {
  /** Statistiques globales Super Admin (tableau de bord premium). */
  async globalDashboardStats() {
    const [
      pharmaciesStats,
      licensesStats,
      usersStats,
      salesStats,
      revenueStats,
      purchasesStats,
      subscriptionsByType,
      recentPharmacies,
      expiredLicenses,
      pendingRenewals,
    ] = await Promise.all([
      // Pharmacies globales
      query(`
        SELECT
          count(*)::int AS total,
          count(*) FILTER (WHERE status = 'active')::int AS active,
          count(*) FILTER (WHERE status = 'suspended')::int AS suspended,
          count(*) FILTER (WHERE status = 'deleted')::int AS deleted,
          count(*) FILTER (WHERE created_at >= now() - interval '30 days')::int AS new_30d
        FROM pharmacies
      `),
      // Licences globales
      query(`
        SELECT
          count(*)::int AS total,
          count(*) FILTER (WHERE status = 'active' AND expiry_date >= now())::int AS active,
          count(*) FILTER (WHERE status = 'suspended')::int AS suspended,
          count(*) FILTER (WHERE status = 'expired')::int AS expired,
          count(*) FILTER (WHERE expiry_date >= now() AND expiry_date < now() + interval '30 days')::int AS expiring_soon
        FROM licenses
      `),
      // Utilisateurs globaux
      query(`
        SELECT
          count(*)::int AS total,
          count(*) FILTER (WHERE status = 'active')::int AS active,
          count(*) FILTER (WHERE created_at >= now() - interval '30 days')::int AS new_30d
        FROM users
      `),
      // Ventes globales
      query(`
        SELECT
          count(*)::int AS total,
          count(*) FILTER (WHERE created_at >= now() - interval '30 days')::int AS last_30d,
          COALESCE(sum(total), 0)::numeric(14,2) AS total_revenue,
          COALESCE(sum(total) FILTER (WHERE created_at >= now() - interval '30 days'), 0)::numeric(14,2) AS revenue_30d
        FROM sales WHERE status = 'completed'
      `),
      // Achats globaux
      query(`
        SELECT
          count(*)::int AS total,
          COALESCE(sum(total), 0)::numeric(14,2) AS total_amount
        FROM purchase_orders
      `),
      // Abonnements par type
      query(`
        SELECT type, count(*)::int AS count
        FROM licenses
        GROUP BY type
      `),
      // Dernières pharmacies inscrites
      query(`
        SELECT id, name, slug, city, status, created_at,
               (SELECT type FROM licenses WHERE pharmacy_id = p.id ORDER BY created_at DESC LIMIT 1) AS license_type
        FROM pharmacies p
        ORDER BY created_at DESC
        LIMIT 10
      `),
      // Licences expirées
      query(`
        SELECT l.id, l.type, l.expiry_date, p.name AS pharmacy_name, p.id AS pharmacy_id
        FROM licenses l
        JOIN pharmacies p ON p.id = l.pharmacy_id
        WHERE l.status = 'active' AND l.expiry_date < now()
        ORDER BY l.expiry_date ASC
        LIMIT 10
      `),
      // Renouvellements à venir (30 jours)
      query(`
        SELECT l.id, l.type, l.expiry_date, p.name AS pharmacy_name, p.id AS pharmacy_id
        FROM licenses l
        JOIN pharmacies p ON p.id = l.pharmacy_id
        WHERE l.status = 'active'
          AND l.expiry_date >= now()
          AND l.expiry_date < now() + interval '30 days'
        ORDER BY l.expiry_date ASC
        LIMIT 10
      `),
    ]);

    return {
      pharmacies: pharmaciesStats.rows[0],
      licenses: licensesStats.rows[0],
      users: usersStats.rows[0],
      sales: {
        ...salesStats.rows[0],
        revenue: salesStats.rows[0].total_revenue,
        revenue_30d: salesStats.rows[0].revenue_30d,
      },
      purchases: purchasesStats.rows[0],
      subscriptions_by_type: subscriptionsByType.rows,
      recent_pharmacies: recentPharmacies.rows,
      expired_licenses: expiredLicenses.rows,
      pending_renewals: pendingRenewals.rows,
    };
  },

  /** Activité récente globale (dernières inscriptions, ventes, tickets). */
  async recentActivity(limit = 20) {
    const [newPharmacies, newUsers, recentSales, recentTickets] = await Promise.all([
      query(`
        SELECT id, name, slug, city, created_at, 'pharmacy' AS activity_type
        FROM pharmacies
        ORDER BY created_at DESC
        LIMIT $1
      `, [Math.ceil(limit / 4)]),
      query(`
        SELECT u.id, u.first_name, u.last_name, u.email, p.name AS pharmacy_name,
               u.created_at, 'user' AS activity_type
        FROM users u
        JOIN pharmacies p ON p.id = u.pharmacy_id
        ORDER BY u.created_at DESC
        LIMIT $1
      `, [Math.ceil(limit / 4)]),
      query(`
        SELECT s.id, p.name AS pharmacy_name, s.total, s.created_at, 'sale' AS activity_type
        FROM sales s
        JOIN pharmacies p ON p.id = s.pharmacy_id
        WHERE s.status = 'completed'
        ORDER BY s.created_at DESC
        LIMIT $1
      `, [Math.ceil(limit / 4)]),
      query(`
        SELECT t.id, t.subject, t.status, p.name AS pharmacy_name, t.created_at, 'ticket' AS activity_type
        FROM support_tickets t
        JOIN pharmacies p ON p.id = t.pharmacy_id
        ORDER BY t.created_at DESC
        LIMIT $1
      `, [Math.ceil(limit / 4)]),
    ]);

    const all = [
      ...newPharmacies.rows.map(r => ({ ...r, type: 'pharmacy' })),
      ...newUsers.rows.map(r => ({ ...r, type: 'user' })),
      ...recentSales.rows.map(r => ({ ...r, type: 'sale' })),
      ...recentTickets.rows.map(r => ({ ...r, type: 'ticket' })),
    ];
    all.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
    return all.slice(0, limit);
  },

  /** Graphique d'évolution des abonnements par mois. */
  async subscriptionTrend(months = 12) {
    const { rows } = await query(`
      SELECT
        to_char(activation_date, 'YYYY-MM') AS month,
        type,
        count(*)::int AS count
      FROM licenses
      WHERE activation_date >= now() - interval '${months} months'
      GROUP BY to_char(activation_date, 'YYYY-MM'), type
      ORDER BY month ASC, type ASC
    `);
    return rows;
  },

  /** Graphique d'évolution des revenus (ventes) par mois. */
  async revenueTrend(months = 12) {
    const { rows } = await query(`
      SELECT
        to_char(created_at, 'YYYY-MM') AS month,
        count(*)::int AS nb_sales,
        COALESCE(sum(total), 0)::numeric(14,2) AS revenue
      FROM sales
      WHERE status = 'completed'
        AND created_at >= now() - interval '${months} months'
      GROUP BY to_char(created_at, 'YYYY-MM')
      ORDER BY month ASC
    `);
    return rows;
  },

  /** Top pharmacies par revenu. */
  async topPharmacies(limit = 10) {
    const { rows } = await query(`
      SELECT
        p.id, p.name, p.slug, p.city, p.status,
        COALESCE(sum(s.total), 0)::numeric(14,2) AS total_revenue,
        count(s.id)::int AS nb_sales,
        l.type AS license_type,
        l.expiry_date
      FROM pharmacies p
      LEFT JOIN sales s ON s.pharmacy_id = p.id AND s.status = 'completed'
      LEFT JOIN LATERAL (
        SELECT type, expiry_date FROM licenses
        WHERE pharmacy_id = p.id ORDER BY created_at DESC LIMIT 1
      ) l ON true
      GROUP BY p.id, p.name, p.slug, p.city, p.status, l.type, l.expiry_date
      ORDER BY total_revenue DESC
      LIMIT $1
    `, [limit]);
    return rows;
  },

  /** Alertes importantes pour le Super Admin. */
  async alerts() {
    const [expiredLicenses, suspendedPharmacies, lowStockAlerts] = await Promise.all([
      query(`
        SELECT l.id, l.type, l.expiry_date, p.name AS pharmacy_name, p.id AS pharmacy_id,
               'license_expired' AS alert_type,
               'Licence expirée depuis le ' || to_char(l.expiry_date, 'DD/MM/YYYY') AS message
        FROM licenses l
        JOIN pharmacies p ON p.id = l.pharmacy_id
        WHERE l.status = 'active' AND l.expiry_date < now()
        ORDER BY l.expiry_date ASC
        LIMIT 10
      `),
      query(`
        SELECT id, name, slug, 'pharmacy_suspended' AS alert_type,
               'Pharmacie suspendue : ' || name AS message
        FROM pharmacies
        WHERE status = 'suspended'
        ORDER BY updated_at DESC
        LIMIT 10
      `),
      query(`
        SELECT count(*)::int AS total
        FROM medications m
        JOIN stock_balances sb ON sb.medication_id = m.id
        WHERE m.pharmacy_id IS NOT NULL
          AND m.status = 'available'
          AND (sb.quantity - sb.reserved_quantity) <= m.reorder_level
      `),
    ]);
    return {
      expired_licenses: expiredLicenses.rows,
      suspended_pharmacies: suspendedPharmacies.rows,
      low_stock_alerts: lowStockAlerts.rows[0].total,
    };
  },

  /** Paiements récents (ventes et achats). */
  async recentPayments(limit = 20) {
    const [sales, purchases] = await Promise.all([
      query(`
        SELECT s.id, p.name AS pharmacy_name, s.total, s.created_at, 'sale' AS type
        FROM sales s
        JOIN pharmacies p ON p.id = s.pharmacy_id
        WHERE s.status = 'completed'
        ORDER BY s.created_at DESC
        LIMIT $1
      `, [Math.ceil(limit / 2)]),
      query(`
        SELECT po.id, ph.name AS pharmacy_name, po.total, po.created_at, 'purchase' AS type
        FROM purchase_orders po
        JOIN pharmacies ph ON ph.id = po.pharmacy_id
        WHERE po.status = 'confirmed'
        ORDER BY po.created_at DESC
        LIMIT $1
      `, [Math.ceil(limit / 2)]),
    ]);
    const all = [
      ...sales.rows.map(r => ({ ...r, type: 'sale' })),
      ...purchases.rows.map(r => ({ ...r, type: 'purchase' })),
    ];
    all.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
    return all.slice(0, limit);
  },
};

export const subscriptionPlans = SUBSCRIPTION_PLANS;
