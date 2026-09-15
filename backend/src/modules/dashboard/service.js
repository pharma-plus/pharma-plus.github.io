import { query } from '../../db/pool.js';

function periodClause(column, period) {
  switch (period) {
    case 'day': return `date_trunc('day', ${column})`;
    case 'week': return `date_trunc('week', ${column})`;
    case 'month': return `date_trunc('month', ${column})`;
    case 'year': return `date_trunc('year', ${column})`;
    default: return `date_trunc('day', ${column})`;
  }
}

export const dashboardService = {
  /** Indicateurs clés du tableau de bord. */
  async overview(pharmacyId, { branchId = null } = {}) {
    const branchFilter = branchId ? 'AND branch_id = $2' : '';
    const params = [pharmacyId];
    if (branchId) params.push(branchId);

    const [revRes, alerts, stock, cash] = await Promise.all([
      query(
        `SELECT
           COALESCE(sum(total) FILTER (WHERE created_at >= now() - interval '1 day'), 0)::numeric(14,2) AS revenue_today,
           COALESCE(sum(total) FILTER (WHERE created_at >= now() - interval '7 days'), 0)::numeric(14,2) AS revenue_week,
           COALESCE(sum(total) FILTER (WHERE created_at >= now() - interval '1 month'), 0)::numeric(14,2) AS revenue_month,
           COALESCE(sum(total) FILTER (WHERE created_at >= now() - interval '1 year'), 0)::numeric(14,2) AS revenue_year,
           count(*) FILTER (WHERE created_at >= now() - interval '1 day')::int AS sales_today,
           count(*) FILTER (WHERE created_at >= now() - interval '1 month')::int AS sales_month,
           COALESCE(sum(total - cost_total) FILTER (WHERE created_at >= now() - interval '1 month'), 0)::numeric(14,2) AS profit_month,
           COALESCE(sum(cost_total) FILTER (WHERE created_at >= now() - interval '1 month'), 0)::numeric(14,2) AS cost_month
         FROM sales
        WHERE pharmacy_id = $1 AND status = 'completed' ${branchFilter}`,
        params,
      ),
      query(
        `SELECT
           (SELECT count(*)::int FROM medications
             WHERE pharmacy_id = $1 AND status = 'available'
               AND COALESCE((SELECT sum(quantity - reserved_quantity) FROM stock_balances
                              WHERE medication_id = medications.id ${branchId ? 'AND branch_id = $2' : ''}), 0) <= reorder_level) AS low_stock,
           (SELECT count(*)::int FROM lots l
             JOIN stock_balances sb ON sb.lot_id = l.id AND sb.quantity > 0
            WHERE l.pharmacy_id = $1
              AND l.expiry_date >= CURRENT_DATE AND l.expiry_date <= CURRENT_DATE + 90
              ${branchId ? 'AND sb.branch_id = $2' : ''}) AS expiring,
           (SELECT count(*)::int FROM lots l
             JOIN stock_balances sb ON sb.lot_id = l.id AND sb.quantity > 0
            WHERE l.pharmacy_id = $1 AND l.expiry_date < CURRENT_DATE
              ${branchId ? 'AND sb.branch_id = $2' : ''}) AS expired,
           (SELECT count(*)::int FROM purchase_orders
             WHERE pharmacy_id = $1 AND status IN ('draft','sent','confirmed')) AS pending_orders`,
        params,
      ),
      query(
        `SELECT COALESCE(sum(quantity * price_sale), 0)::numeric(14,2) AS stock_value,
                COALESCE(sum(quantity * cost_price), 0)::numeric(14,2) AS stock_cost
           FROM (SELECT sb.medication_id, sb.quantity, m.price_sale, l.cost_price
                   FROM stock_balances sb
                   JOIN medications m ON m.id = sb.medication_id
                   LEFT JOIN lots l ON l.id = sb.lot_id
                  WHERE sb.pharmacy_id = $1 ${branchId ? 'AND sb.branch_id = $2' : ''}) sub`,
        params,
      ),
      query(
        `SELECT count(*)::int AS present
           FROM attendance
          WHERE pharmacy_id = $1 AND date = CURRENT_DATE AND clock_out IS NULL
            ${branchId ? 'AND branch_id = $2' : ''}`,
        params,
      ),
    ]);

    const rev = revRes.rows[0];
    const counts = await this.counts(pharmacyId, branchId);
    return {
      revenue: rev,
      alerts: alerts.rows[0],
      stock: stock.rows[0],
      employees_present: cash.rows[0].present,
      counts,
      top_products: await this.topProducts(pharmacyId, branchId, 5),
      sales_trend: await this.salesTrend(pharmacyId, branchId, 30),
      goals: { month_target: 0, achieved: rev.revenue_month },
      pharma_plus: await this.pharmaPlus(pharmacyId, branchId),
    };
  },

  /** Compteurs globaux pour les cartes 3D du tableau de bord. */
  async counts(pharmacyId, branchId = null) {
    const [meds, presc, cust, supp] = await Promise.all([
      query(
        `SELECT count(*) FILTER (WHERE status = 'available')::int AS available,
                count(*) FILTER (WHERE status = 'available' AND is_parapharmacie = true)::int AS parapharmacy,
                count(*)::int AS total
           FROM medications WHERE pharmacy_id = $1`, [pharmacyId]),
      query(
        `SELECT count(*) FILTER (WHERE created_at >= now() - interval '30 days')::int AS month,
                count(*) FILTER (WHERE status IN ('received','processing'))::int AS pending
           FROM prescriptions WHERE pharmacy_id = $1`, [pharmacyId]),
      query(
        `SELECT count(*) FILTER (WHERE status = 'active')::int AS active,
                count(*)::int AS total
           FROM customers WHERE pharmacy_id = $1`, [pharmacyId]),
      query(
        `SELECT count(*) FILTER (WHERE status = 'active')::int AS active,
                count(*)::int AS total
           FROM suppliers WHERE pharmacy_id = $1`, [pharmacyId]),
    ]);
    return {
      medications: meds.rows[0],
      prescriptions: presc.rows[0],
      customers: cust.rows[0],
      suppliers: supp.rows[0],
    };
  },

  /** Indicateurs PHARMA+ : parapharmacie, caméras, IA, base de référence. */
  async pharmaPlus(pharmacyId, branchId = null) {
    const params = [pharmacyId];
    if (branchId) params.push(branchId);

    const [para, cams, ai, ref] = await Promise.all([
      query(
        `SELECT
           (SELECT count(*)::int FROM medications
             WHERE pharmacy_id = $1 AND is_parapharmacie = true AND status = 'available') AS products,
           COALESCE((
             SELECT sum(si.line_total) FROM sale_items si
               JOIN sales s ON s.id = si.sale_id AND s.status = 'completed'
               JOIN medications m ON m.id = si.medication_id
              WHERE s.pharmacy_id = $1 AND m.is_parapharmacie = true
                AND s.created_at >= now() - interval '30 days'
                ${branchId ? 'AND s.branch_id = $2' : ''}
           ), 0)::numeric(14,2) AS revenue_month`,
        params,
      ),
      query(
        `SELECT count(*)::int AS total,
                count(*) FILTER (WHERE status = 'online')::int AS online,
                count(*) FILTER (WHERE status = 'recording')::int AS recording
           FROM cameras WHERE pharmacy_id = $1 AND is_enabled = true`,
        [pharmacyId],
      ),
      query(
        `SELECT
           (SELECT count(*)::int FROM audit_logs
             WHERE pharmacy_id = $1 AND module = 'ai'
               AND created_at >= now() - interval '7 days') AS requests_7d,
           (SELECT count(*)::int FROM audit_logs
             WHERE pharmacy_id = $1 AND module = 'ai' AND action IN ('chat','insights')
               AND created_at >= now() - interval '7 days') AS success_7d`,
        [pharmacyId],
      ),
      query(
        `SELECT status, source, finished_at, new_count, modified_count, price_changed_count
           FROM reference_sync_runs ORDER BY started_at DESC LIMIT 1`,
      ),
    ]);

    const c = cams.rows[0];
    const a = ai.rows[0];
    return {
      parapharmacy: para.rows[0],
      cameras: c ?? { total: 0, online: 0, recording: 0 },
      pharma_ai: { requests_7d: a?.requests_7d ?? 0, success_7d: a?.success_7d ?? 0 },
      reference: { last_sync: ref.rows[0] ?? null },
    };
  },

  /** Produits les plus vendus. */
  async topProducts(pharmacyId, branchId, limit = 5) {
    const branchFilter = branchId ? 'AND s.branch_id = $2' : '';
    const params = [pharmacyId];
    if (branchId) params.push(branchId);
    const { rows } = await query(
      `SELECT si.medication_id, m.name, m.dosage,
              sum(si.quantity)::numeric(12,3) AS qty_sold,
              sum(si.line_total)::numeric(14,2) AS revenue
         FROM sale_items si
         JOIN sales s ON s.id = si.sale_id AND s.status = 'completed'
         JOIN medications m ON m.id = si.medication_id
        WHERE s.pharmacy_id = $1
          AND s.created_at >= now() - interval '30 days'
          ${branchFilter}
        GROUP BY si.medication_id, m.name, m.dosage
        ORDER BY qty_sold DESC
        LIMIT $${params.length + 1}`,
      [...params, limit],
    );
    return rows;
  },

  /** Courbe d'évolution des ventes (CA + bénéfice par jour). */
  async salesTrend(pharmacyId, branchId, days = 30) {
    const params = [pharmacyId, days];
    let branchFilter = '';
    if (branchId) { params.push(branchId); branchFilter = 'AND branch_id = $3'; }
    const { rows } = await query(
      `SELECT sale_date, nb_sales, total, profit
         FROM mv_daily_sales
        WHERE pharmacy_id = $1 AND sale_date >= CURRENT_DATE - $2 * interval '1 day'
          ${branchFilter}
        ORDER BY sale_date`,
      params,
    );
    return rows;
  },

  /** Comparaison de périodes (pour les rapports). */
  async compare(pharmacyId, branchId, from, to, compareFrom, compareTo) {
    const params = [pharmacyId, from, to];
    let branchFilter = '';
    if (branchId) { params.push(branchId); branchFilter = 'AND branch_id = $4'; }
    const [current, previous] = await Promise.all([
      query(
        `SELECT COALESCE(sum(total),0)::numeric(14,2) AS revenue,
                count(*)::int AS sales,
                COALESCE(sum(total - cost_total),0)::numeric(14,2) AS profit
           FROM sales WHERE pharmacy_id = $1 AND status = 'completed'
             AND created_at >= $2 AND created_at <= $3 ${branchFilter}`, params),
      query(
        `SELECT COALESCE(sum(total),0)::numeric(14,2) AS revenue,
                count(*)::int AS sales,
                COALESCE(sum(total - cost_total),0)::numeric(14,2) AS profit
           FROM sales WHERE pharmacy_id = $1 AND status = 'completed'
             AND created_at >= $4 AND created_at <= $5 ${branchFilter}`, [...params, compareFrom, compareTo]),
    ]);
    const a = current.rows[0];
    const b = previous.rows[0];
    const pct = (cur, prev) => (prev === 0 ? null : Math.round(((cur - prev) / prev) * 1000) / 10);
    return {
      current: a,
      previous: b,
      variation: {
        revenue: pct(Number(a.revenue), Number(b.revenue)),
        sales: pct(a.sales, b.sales),
        profit: pct(Number(a.profit), Number(b.profit)),
      },
    };
  },
};
