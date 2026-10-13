-- ============================================================
-- 20261012180000_ai_insights_functions.sql
-- Port des 3 routes IA du backend Node vers des fonctions RPC
-- PostgreSQL (l'assistant « insights », « reorder-plan » et
-- « sales-analysis »). PostgREST ne sait pas exécuter generate_series
-- ni les sous-requêtes scalaires correlées : on crée 3 fonctions
-- SECURITY DEFINER retournant jsonb, appelées via sb.rpc() côté Edge.
-- Chaque fonction filtre EXPLICITEMENT par p_pharmacy (le client Edge
-- est service_role et contourne la RLS).
-- Lecture seule : AUCUNE écriture, AUCUNE suppression.
-- ============================================================

-- ── 1. Insights : stock bas, péremption, sans vente, top ventes,
--       marge faible, unités périmées. ──────────────────────────────
CREATE OR REPLACE FUNCTION public.ai_insights(p_pharmacy uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
SELECT json_build_object(
  'reorder_soon', (
    SELECT COALESCE(json_agg(q), '[]'::json) FROM (
      SELECT m.id, m.name, m.barcode_ean13,
             COALESCE(SUM(sb.quantity - sb.reserved_quantity), 0)::numeric(12,3) AS current_stock,
             m.reorder_level, m.min_stock,
             (SELECT COALESCE(SUM(oi.quantity), 0)::numeric(12,3)
                FROM sale_items oi JOIN sales s2 ON s2.id = oi.sale_id
               WHERE oi.medication_id = m.id AND s2.pharmacy_id = p_pharmacy
                 AND s2.status = 'completed'
                 AND s2.created_at >= now() - INTERVAL '30 days') AS monthly_demand
        FROM medications m
        LEFT JOIN stock_balances sb ON sb.medication_id = m.id AND sb.pharmacy_id = p_pharmacy
       WHERE m.pharmacy_id = p_pharmacy AND m.status = 'available'
       GROUP BY m.id
      HAVING COALESCE(SUM(sb.quantity - sb.reserved_quantity), 0) <= m.reorder_level
       ORDER BY COALESCE(SUM(sb.quantity - sb.reserved_quantity), 0) - m.reorder_level
       LIMIT 20) q),
  'expiring_within_60d', (
    SELECT COALESCE(json_agg(q), '[]'::json) FROM (
      SELECT m.id, m.name, l.lot_number, l.expiry_date,
             COALESCE(b.quantity, 0)::numeric(12,3) AS quantity
        FROM lots l JOIN medications m ON m.id = l.medication_id
        LEFT JOIN stock_balances b ON b.lot_id = l.id AND b.pharmacy_id = p_pharmacy
       WHERE l.pharmacy_id = p_pharmacy
         AND l.expiry_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '60 days'
         AND COALESCE(b.quantity, 0) > 0
       ORDER BY l.expiry_date LIMIT 20) q),
  'no_sales_30d', (
    SELECT COALESCE(json_agg(q), '[]'::json) FROM (
      SELECT m.id, m.name, COALESCE(SUM(si.quantity), 0)::numeric(12,3) AS sold_30d,
             COALESCE(SUM(b.quantity), 0)::numeric(12,3) AS current_stock
        FROM medications m
        LEFT JOIN sale_items si ON si.medication_id = m.id
        LEFT JOIN sales s ON s.id = si.sale_id AND s.pharmacy_id = p_pharmacy
          AND s.status = 'completed' AND s.created_at >= now() - INTERVAL '30 days'
        LEFT JOIN stock_balances b ON b.medication_id = m.id AND b.pharmacy_id = p_pharmacy
       WHERE m.pharmacy_id = p_pharmacy
       GROUP BY m.id
      HAVING COALESCE(SUM(si.quantity), 0) = 0
       ORDER BY m.name LIMIT 20) q),
  'top_sellers_30d', (
    SELECT COALESCE(json_agg(q), '[]'::json) FROM (
      SELECT m.id, m.name, COALESCE(SUM(si.quantity), 0)::numeric(12,3) AS sold_30d,
             COALESCE(SUM(si.line_total), 0)::numeric(14,2) AS revenue_30d
        FROM medications m
        LEFT JOIN sale_items si ON si.medication_id = m.id
        LEFT JOIN sales s ON s.id = si.sale_id AND s.pharmacy_id = p_pharmacy
          AND s.status = 'completed' AND s.created_at >= now() - INTERVAL '30 days'
       WHERE m.pharmacy_id = p_pharmacy
       GROUP BY m.id
       ORDER BY revenue_30d DESC LIMIT 10) q),
  'low_margin_30d', (
    SELECT COALESCE(json_agg(q), '[]'::json) FROM (
      SELECT m.id, m.name,
             COALESCE(SUM(si.line_total), 0)::numeric(14,2) AS revenue_30d,
             CASE WHEN COALESCE(SUM(si.line_total), 0) > 0
                  THEN (1 - SUM(si.quantity * si.unit_cost) / SUM(si.line_total)) * 100
                  ELSE NULL END::numeric(6,2) AS margin_pct
        FROM medications m
        JOIN sale_items si ON si.medication_id = m.id
        JOIN sales s ON s.id = si.sale_id AND s.pharmacy_id = p_pharmacy
          AND s.status = 'completed' AND s.created_at >= now() - INTERVAL '30 days'
       WHERE m.pharmacy_id = p_pharmacy
       GROUP BY m.id
      HAVING COALESCE(SUM(si.line_total), 0) > 0
         AND (1 - SUM(si.quantity * si.unit_cost) / SUM(si.line_total)) < 0.15
       ORDER BY revenue_30d DESC LIMIT 10) q),
  'expired_units', (
    SELECT COALESCE(SUM(b.quantity), 0)::numeric(12,3)
      FROM lots l LEFT JOIN stock_balances b ON b.lot_id = l.id AND b.pharmacy_id = p_pharmacy
     WHERE l.pharmacy_id = p_pharmacy
       AND l.expiry_date < CURRENT_DATE AND COALESCE(b.quantity, 0) > 0)
)::jsonb;
$$;

-- ── 2. Plan de réassort : lignes brutes sous le seuil (le calcul de
--       vélocité/priorité/coût se fait côté Edge en TS). ───────────
CREATE OR REPLACE FUNCTION public.ai_reorder_plan(p_pharmacy uuid, p_branch uuid, p_days_cover int)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
SELECT COALESCE(json_agg(t), '[]'::json)::jsonb
FROM (
  SELECT u.* FROM (
    SELECT m.id, m.name, m.dci, m.barcode_ean13, m.reorder_level,
         (SELECT COALESCE(SUM(sb.quantity - sb.reserved_quantity), 0)
            FROM stock_balances sb
           WHERE sb.medication_id = m.id AND sb.pharmacy_id = p_pharmacy
             AND (sb.branch_id = p_branch OR p_branch IS NULL))::numeric(12,3) AS stock,
         (SELECT COALESCE(SUM(si.quantity), 0)
            FROM sale_items si JOIN sales s ON s.id = si.sale_id
             AND s.pharmacy_id = p_pharmacy AND s.status = 'completed'
             AND s.created_at >= now() - INTERVAL '30 days'
           WHERE si.medication_id = m.id
             AND (p_branch IS NULL OR s.branch_id = p_branch))::numeric(12,3) AS sold_30d,
         (SELECT COALESCE(SUM(si.quantity), 0)
            FROM sale_items si JOIN sales s ON s.id = si.sale_id
             AND s.pharmacy_id = p_pharmacy AND s.status = 'completed'
             AND s.created_at >= now() - INTERVAL '60 days'
           WHERE si.medication_id = m.id
             AND (p_branch IS NULL OR s.branch_id = p_branch))::numeric(12,3) AS sold_60d,
         (SELECT COALESCE(SUM(poi.quantity_ordered - poi.quantity_received), 0)
            FROM purchase_order_items poi JOIN purchase_orders po ON po.id = poi.purchase_order_id
           WHERE poi.medication_id = m.id AND po.pharmacy_id = p_pharmacy
             AND po.status IN ('draft', 'sent', 'confirmed'))::numeric(12,3) AS on_order,
         (SELECT poi.unit_cost
            FROM purchase_order_items poi JOIN purchase_orders po ON po.id = poi.purchase_order_id
           WHERE poi.medication_id = m.id AND po.pharmacy_id = p_pharmacy
             AND po.status IN ('received', 'partial')
             AND poi.quantity_received > 0 AND poi.unit_cost IS NOT NULL
           ORDER BY po.received_date DESC NULLS LAST, poi.id DESC LIMIT 1) AS last_cost,
         (SELECT sm.unit_cost
            FROM stock_movements sm
           WHERE sm.medication_id = m.id AND sm.pharmacy_id = p_pharmacy
             AND sm.movement_type = 'purchase_receipt' AND sm.unit_cost IS NOT NULL
           ORDER BY sm.created_at DESC LIMIT 1) AS lot_cost,
         (SELECT s2.name
            FROM medication_suppliers ms JOIN suppliers s2 ON s2.id = ms.supplier_id
           WHERE ms.medication_id = m.id AND ms.pharmacy_id = p_pharmacy
           ORDER BY ms.is_primary DESC NULLS LAST, ms.price ASC NULLS LAST LIMIT 1) AS supplier_name
    FROM medications m
   WHERE m.pharmacy_id = p_pharmacy AND m.status = 'available'
) u
WHERE u.stock <= u.reorder_level
LIMIT 200
) t;
$$;

-- ── 3. Analyse des ventes : série, comparaison, catégories, heures,
--       jours, top produits (prévision/tendance côté Edge). ────────
CREATE OR REPLACE FUNCTION public.ai_sales_analysis(p_pharmacy uuid, p_branch uuid, p_days int)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
SELECT json_build_object(
  'series',     (
    SELECT COALESCE(json_agg(row_to_json(x)), '[]'::json) FROM (
      SELECT d::date AS day,
             COALESCE(sum(s.total), 0)::numeric(14,2) AS revenue,
             COALESCE(count(s.id), 0)::int AS nb_sales,
             COALESCE(sum(s.total - s.cost_total), 0)::numeric(14,2) AS profit
        FROM generate_series((CURRENT_DATE - (p_days - 1))::timestamp, CURRENT_DATE::timestamp, INTERVAL '1 day') d
        LEFT JOIN sales s ON s.pharmacy_id = p_pharmacy AND s.status = 'completed'
          AND s.created_at >= d AND s.created_at < d + INTERVAL '1 day'
          AND (p_branch IS NULL OR s.branch_id = p_branch)
       GROUP BY d ORDER BY d) x),
  'compare',    (
    SELECT row_to_json(c) FROM (
      SELECT
        (SELECT COALESCE(sum(total), 0) FROM sales WHERE pharmacy_id = p_pharmacy AND status = 'completed'
           AND created_at >= now() - (p_days * INTERVAL '1 day')
           AND (p_branch IS NULL OR branch_id = p_branch))::numeric(14,2) AS revenue,
        (SELECT COALESCE(sum(total), 0) FROM sales WHERE pharmacy_id = p_pharmacy AND status = 'completed'
           AND created_at >= now() - (2 * p_days * INTERVAL '1 day')
           AND created_at <  now() - (p_days * INTERVAL '1 day')
           AND (p_branch IS NULL OR branch_id = p_branch))::numeric(14,2) AS revenue_prev,
        (SELECT count(*) FROM sales WHERE pharmacy_id = p_pharmacy AND status = 'completed'
           AND created_at >= now() - (p_days * INTERVAL '1 day')
           AND (p_branch IS NULL OR branch_id = p_branch))::int AS nb_sales,
        (SELECT count(*) FROM sales WHERE pharmacy_id = p_pharmacy AND status = 'completed'
           AND created_at >= now() - (2 * p_days * INTERVAL '1 day')
           AND created_at <  now() - (p_days * INTERVAL '1 day')
           AND (p_branch IS NULL OR branch_id = p_branch))::int AS nb_sales_prev,
        (SELECT COALESCE(sum(total - cost_total), 0) FROM sales WHERE pharmacy_id = p_pharmacy AND status = 'completed'
           AND created_at >= now() - (p_days * INTERVAL '1 day')
           AND (p_branch IS NULL OR branch_id = p_branch))::numeric(14,2) AS profit,
        (SELECT COALESCE(sum(cost_total), 0) FROM sales WHERE pharmacy_id = p_pharmacy AND status = 'completed'
           AND created_at >= now() - (p_days * INTERVAL '1 day')
           AND (p_branch IS NULL OR branch_id = p_branch))::numeric(14,2) AS cost) c),
  'categories', (
    SELECT COALESCE(json_agg(row_to_json(c)), '[]'::json) FROM (
      SELECT cat.id, COALESCE(cat.name, 'Sans catégorie') AS name,
             COALESCE(sum(si.line_total), 0)::numeric(14,2) AS revenue,
             COALESCE(sum(si.quantity), 0)::numeric(12,3) AS qty
        FROM sale_items si
        JOIN sales s ON s.id = si.sale_id AND s.status = 'completed'
        JOIN medications m ON m.id = si.medication_id
        LEFT JOIN categories cat ON cat.id = m.category_id
       WHERE s.pharmacy_id = p_pharmacy
         AND s.created_at >= now() - (p_days * INTERVAL '1 day')
         AND (p_branch IS NULL OR s.branch_id = p_branch)
       GROUP BY cat.id, cat.name ORDER BY revenue DESC LIMIT 8) c),
  'hours',      (
    SELECT COALESCE(json_agg(row_to_json(h)), '[]'::json) FROM (
      SELECT EXTRACT(HOUR FROM s.created_at)::int AS hour,
             COALESCE(sum(s.total), 0)::numeric(14,2) AS revenue, count(*)::int AS nb_sales
        FROM sales s
       WHERE s.pharmacy_id = p_pharmacy AND s.status = 'completed'
         AND s.created_at >= now() - (p_days * INTERVAL '1 day')
         AND (p_branch IS NULL OR s.branch_id = p_branch)
       GROUP BY 1 ORDER BY 1) h),
  'weekdays',   (
    SELECT COALESCE(json_agg(row_to_json(w)), '[]'::json) FROM (
      SELECT EXTRACT(DOW FROM s.created_at)::int AS dow,
             COALESCE(sum(s.total), 0)::numeric(14,2) AS revenue, count(*)::int AS nb_sales
        FROM sales s
       WHERE s.pharmacy_id = p_pharmacy AND s.status = 'completed'
         AND s.created_at >= now() - (p_days * INTERVAL '1 day')
         AND (p_branch IS NULL OR s.branch_id = p_branch)
       GROUP BY 1 ORDER BY 1) w),
  'products',   (
    SELECT COALESCE(json_agg(row_to_json(p)), '[]'::json) FROM (
      SELECT m.id, m.name,
             COALESCE(sum(si.quantity), 0)::numeric(12,3) AS qty_sold,
             COALESCE(sum(si.line_total), 0)::numeric(14,2) AS revenue
        FROM sale_items si
        JOIN sales s ON s.id = si.sale_id AND s.status = 'completed'
        JOIN medications m ON m.id = si.medication_id
       WHERE s.pharmacy_id = p_pharmacy
         AND s.created_at >= now() - (p_days * INTERVAL '1 day')
         AND (p_branch IS NULL OR s.branch_id = p_branch)
       GROUP BY m.id ORDER BY revenue DESC LIMIT 5) p)
)::jsonb;
$$;

GRANT EXECUTE ON FUNCTION public.ai_insights(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.ai_reorder_plan(uuid, uuid, int) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.ai_sales_analysis(uuid, uuid, int) TO authenticated, service_role;
