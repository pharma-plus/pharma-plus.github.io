-- Migration : vue matérialisée mv_daily_sales pour le dashboard
-- Utilisée par dashboardService.salesTrend() (courbe de tendance des ventes)
-- Agrège les ventes terminées par pharmacie et par date.

CREATE MATERIALIZED VIEW IF NOT EXISTS mv_daily_sales AS
SELECT
  pharmacy_id,
  sale_date::date AS sale_date,
  count(*)::int AS nb_sales,
  COALESCE(sum(total), 0)::numeric(14,2) AS total,
  COALESCE(sum(total - cost_total), 0)::numeric(14,2) AS profit
FROM sales
WHERE status = 'completed'
GROUP BY pharmacy_id, sale_date::date;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_daily_sales_pharmacy_date
  ON mv_daily_sales (pharmacy_id, sale_date);
