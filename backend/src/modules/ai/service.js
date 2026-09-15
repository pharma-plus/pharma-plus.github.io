import { query } from '../../db/pool.js';
import { auditLog } from '../../middleware/audit.js';
import {
  dailyVelocity, daysOfCover, suggestedQty, stockPriority,
  pctChange, weekdayForecast, summarizeReorder, sortReorderItems, round2,
} from './math.js';

/**
 * Assistant intelligent (v2) : règles métier déterministes sur les données
 * réelles (ventes, stock, achats). Une intégration LLM optionnelle pourra
 * remplacer le moteur de réponses sans changer le contrat d'API.
 */
export const aiService = {
  async insights(pharmacyId) {
    const [reorders, expiring, slowMovers, topSellers, lowMargin, expiredUnits] = await Promise.all([
      query(
        `SELECT m.id, m.name, m.barcode_ean13,
                COALESCE(SUM(sb.quantity - sb.reserved_quantity), 0)::numeric(12,3) AS current_stock,
                m.reorder_level, m.min_stock,
                (SELECT COALESCE(SUM(oi.quantity), 0)::numeric(12,3)
                   FROM sale_items oi JOIN sales s2 ON s2.id = oi.sale_id
                  WHERE oi.medication_id = m.id AND s2.pharmacy_id = $1
                    AND s2.status = 'completed'
                    AND s2.created_at >= now() - INTERVAL '30 days') AS monthly_demand
           FROM medications m
           LEFT JOIN stock_balances sb ON sb.medication_id = m.id AND sb.pharmacy_id = $1
          WHERE m.pharmacy_id = $1 AND m.status = 'available'
          GROUP BY m.id
          HAVING COALESCE(SUM(sb.quantity - sb.reserved_quantity), 0) <= m.reorder_level
          ORDER BY COALESCE(SUM(sb.quantity - sb.reserved_quantity), 0) - m.reorder_level
          LIMIT 20`,
        [pharmacyId],
      ),
      query(
        `SELECT m.id, m.name, l.lot_number, l.expiry_date,
                COALESCE(b.quantity, 0)::numeric(12,3) AS quantity
           FROM lots l JOIN medications m ON m.id = l.medication_id
           LEFT JOIN stock_balances b ON b.lot_id = l.id AND b.pharmacy_id = $1
          WHERE l.pharmacy_id = $1
            AND l.expiry_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '60 days'
            AND COALESCE(b.quantity, 0) > 0
          ORDER BY l.expiry_date LIMIT 20`,
        [pharmacyId],
      ),
      query(
        `SELECT m.id, m.name, COALESCE(SUM(si.quantity), 0)::numeric(12,3) AS sold_30d,
                COALESCE(SUM(b.quantity), 0)::numeric(12,3) AS current_stock
           FROM medications m
           LEFT JOIN sale_items si ON si.medication_id = m.id
           LEFT JOIN sales s ON s.id = si.sale_id AND s.pharmacy_id = $1
             AND s.status = 'completed' AND s.created_at >= now() - INTERVAL '30 days'
           LEFT JOIN stock_balances b ON b.medication_id = m.id AND b.pharmacy_id = $1
          WHERE m.pharmacy_id = $1
          GROUP BY m.id
          HAVING COALESCE(SUM(si.quantity), 0) = 0
          ORDER BY m.name LIMIT 20`,
        [pharmacyId],
      ),
      query(
        `SELECT m.id, m.name, COALESCE(SUM(si.quantity), 0)::numeric(12,3) AS sold_30d,
                COALESCE(SUM(si.line_total), 0)::numeric(14,2) AS revenue_30d
           FROM medications m
           LEFT JOIN sale_items si ON si.medication_id = m.id
           LEFT JOIN sales s ON s.id = si.sale_id AND s.pharmacy_id = $1
             AND s.status = 'completed' AND s.created_at >= now() - INTERVAL '30 days'
          WHERE m.pharmacy_id = $1
          GROUP BY m.id
          ORDER BY revenue_30d DESC LIMIT 10`,
        [pharmacyId],
      ),
      query(
        `SELECT m.id, m.name,
                COALESCE(SUM(si.line_total), 0)::numeric(14,2) AS revenue_30d,
                CASE WHEN COALESCE(SUM(si.line_total), 0) > 0
                     THEN (1 - SUM(si.quantity * si.unit_cost) / SUM(si.line_total)) * 100
                     ELSE NULL END::numeric(6,2) AS margin_pct
           FROM medications m
           JOIN sale_items si ON si.medication_id = m.id
           JOIN sales s ON s.id = si.sale_id AND s.pharmacy_id = $1
             AND s.status = 'completed' AND s.created_at >= now() - INTERVAL '30 days'
          WHERE m.pharmacy_id = $1
          GROUP BY m.id
          HAVING COALESCE(SUM(si.line_total), 0) > 0
             AND (1 - SUM(si.quantity * si.unit_cost) / SUM(si.line_total)) < 0.15
          ORDER BY revenue_30d DESC LIMIT 10`,
        [pharmacyId],
      ),
      query(
        `SELECT COALESCE(SUM(b.quantity), 0)::numeric(12,3) AS qty
           FROM lots l LEFT JOIN stock_balances b ON b.lot_id = l.id AND b.pharmacy_id = $1
          WHERE l.pharmacy_id = $1
            AND l.expiry_date < CURRENT_DATE AND COALESCE(b.quantity, 0) > 0`,
        [pharmacyId],
      ),
    ]);

    return {
      generated_at: new Date().toISOString(),
      reorder_soon: reorders.rows,
      expiring_within_60d: expiring.rows,
      no_sales_30d: slowMovers.rows,
      top_sellers_30d: topSellers.rows,
      low_margin_30d: lowMargin.rows,
      expired_units: Number(expiredUnits.rows[0]?.qty ?? 0),
    };
  },

  /**
   * Plan de réassort : pour chaque référence sous le seuil, calcule la vitesse
   * de vente, la couverture en jours, la quantité à commander (en tenant
   * compte des commandes ouvertes), le coût estimé et le fournisseur.
   */
  async reorderPlan(pharmacyId, { branchId = null, daysCover = 14 } = {}) {
    const params = [pharmacyId, branchId];
    const branchSb = ' AND (sb.branch_id = $2 OR $2::uuid IS NULL) ';
    const branchSales = ' AND ($2::uuid IS NULL OR s.branch_id = $2) ';

    const { rows } = await query(
      `SELECT * FROM (
        SELECT m.id, m.name, m.dci, m.barcode_ean13, m.reorder_level,
               (SELECT COALESCE(SUM(sb.quantity - sb.reserved_quantity), 0)
                  FROM stock_balances sb
                 WHERE sb.medication_id = m.id AND sb.pharmacy_id = $1${branchSb}
               )::numeric(12,3) AS stock,
               (SELECT COALESCE(SUM(si.quantity), 0)
                  FROM sale_items si
                  JOIN sales s ON s.id = si.sale_id
                      AND s.pharmacy_id = $1 AND s.status = 'completed'
                      AND s.created_at >= now() - INTERVAL '30 days'
                 WHERE si.medication_id = m.id${branchSales}
               )::numeric(12,3) AS sold_30d,
               (SELECT COALESCE(SUM(si.quantity), 0)
                  FROM sale_items si
                  JOIN sales s ON s.id = si.sale_id
                      AND s.pharmacy_id = $1 AND s.status = 'completed'
                      AND s.created_at >= now() - INTERVAL '60 days'
                 WHERE si.medication_id = m.id${branchSales}
               )::numeric(12,3) AS sold_60d,
               (SELECT COALESCE(SUM(poi.quantity_ordered - poi.quantity_received), 0)
                  FROM purchase_order_items poi
                  JOIN purchase_orders po ON po.id = poi.purchase_order_id
                 WHERE poi.medication_id = m.id AND po.pharmacy_id = $1
                   AND po.status IN ('draft', 'sent', 'confirmed')
               )::numeric(12,3) AS on_order,
               (SELECT poi.unit_cost
                  FROM purchase_order_items poi
                  JOIN purchase_orders po ON po.id = poi.purchase_order_id
                 WHERE poi.medication_id = m.id AND po.pharmacy_id = $1
                   AND po.status IN ('received', 'partial')
                   AND poi.quantity_received > 0 AND poi.unit_cost IS NOT NULL
                 ORDER BY po.received_date DESC NULLS LAST, poi.id DESC
                 LIMIT 1) AS last_cost,
               (SELECT sm.unit_cost
                  FROM stock_movements sm
                 WHERE sm.medication_id = m.id AND sm.pharmacy_id = $1
                   AND sm.movement_type = 'purchase_receipt'
                   AND sm.unit_cost IS NOT NULL
                 ORDER BY sm.created_at DESC
                 LIMIT 1) AS lot_cost,
               (SELECT s2.name
                  FROM medication_suppliers ms
                  JOIN suppliers s2 ON s2.id = ms.supplier_id
                 WHERE ms.medication_id = m.id AND ms.pharmacy_id = $1
                 ORDER BY ms.is_primary DESC NULLS LAST, ms.price ASC NULLS LAST
                 LIMIT 1) AS supplier_name
          FROM medications m
         WHERE m.pharmacy_id = $1 AND m.status = 'available'
       ) t
       WHERE t.stock <= t.reorder_level
       LIMIT 200`,
      params,
    );

    const items = sortReorderItems(rows.map((r) => {
      const stock = Number(r.stock ?? 0);
      const velocity = dailyVelocity(r.sold_30d, r.sold_60d);
      const cover = daysOfCover(stock, velocity);
      const qty = suggestedQty({
        stock, velocity, daysCoverTarget: daysCover, reorderLevel: r.reorder_level, onOrder: r.on_order,
      });
      const unitCost = Number(r.last_cost ?? r.lot_cost ?? 0) || null;
      return {
        medication_id: r.id,
        name: r.name,
        dci: r.dci,
        barcode: r.barcode_ean13,
        stock,
        reorder_level: Number(r.reorder_level ?? 0),
        sold_30d: Number(r.sold_30d ?? 0),
        daily_velocity: round2(velocity * 1000) / 1000,
        days_of_cover: cover == null ? null : round2(cover),
        on_order: Number(r.on_order ?? 0),
        suggested_qty: qty,
        unit_cost: unitCost == null ? null : round2(unitCost),
        estimated_cost: unitCost == null ? null : round2(unitCost * qty),
        supplier_name: r.supplier_name ?? null,
        priority: stockPriority({ stock, coverDays: cover, daysCoverTarget: daysCover }),
      };
    }));

    return {
      generated_at: new Date().toISOString(),
      days_cover_target: daysCover,
      branch_id: branchId,
      items,
      ...summarizeReorder(items),
    };
  },

  /**
   * Analyse des ventes : série journalière, comparaison avec la période
   * précédente, top catégories/produits, heures de pointe et prévision 7 j.
   */
  async salesAnalysis(pharmacyId, { branchId = null, days = 30 } = {}) {
    const win = `s.created_at >= now() - ($2::int * INTERVAL '1 day')
                    AND ($3::uuid IS NULL OR s.branch_id = $3)`;
    const p = [pharmacyId, days, branchId];

    const [seriesRes, compareRes, categoriesRes, hoursRes, weekdayRes, productsRes] = await Promise.all([
      query(
        `SELECT d::date AS day,
                COALESCE(sum(s.total), 0)::numeric(14,2) AS revenue,
                COALESCE(count(s.id), 0)::int AS nb_sales,
                COALESCE(sum(s.total - s.cost_total), 0)::numeric(14,2) AS profit
           FROM generate_series((CURRENT_DATE - ($2::int - 1))::timestamp, CURRENT_DATE::timestamp, INTERVAL '1 day') d
           LEFT JOIN sales s ON s.pharmacy_id = $1 AND s.status = 'completed'
                AND s.created_at >= d AND s.created_at < d + INTERVAL '1 day'
                AND ($3::uuid IS NULL OR s.branch_id = $3)
          GROUP BY d ORDER BY d`,
        p,
      ),
      query(
        `SELECT
           (SELECT COALESCE(sum(total), 0) FROM sales
             WHERE pharmacy_id = $1 AND status = 'completed'
               AND created_at >= now() - ($2::int * INTERVAL '1 day')
               AND ($3::uuid IS NULL OR branch_id = $3))::numeric(14,2) AS revenue,
           (SELECT COALESCE(sum(total), 0) FROM sales
             WHERE pharmacy_id = $1 AND status = 'completed'
               AND created_at >= now() - (2 * $2::int * INTERVAL '1 day')
               AND created_at <  now() - ($2::int * INTERVAL '1 day')
               AND ($3::uuid IS NULL OR branch_id = $3))::numeric(14,2) AS revenue_prev,
           (SELECT count(*) FROM sales
             WHERE pharmacy_id = $1 AND status = 'completed'
               AND created_at >= now() - ($2::int * INTERVAL '1 day')
               AND ($3::uuid IS NULL OR branch_id = $3))::int AS nb_sales,
           (SELECT count(*) FROM sales
             WHERE pharmacy_id = $1 AND status = 'completed'
               AND created_at >= now() - (2 * $2::int * INTERVAL '1 day')
               AND created_at <  now() - ($2::int * INTERVAL '1 day')
               AND ($3::uuid IS NULL OR branch_id = $3))::int AS nb_sales_prev,
           (SELECT COALESCE(sum(total - cost_total), 0) FROM sales
             WHERE pharmacy_id = $1 AND status = 'completed'
               AND created_at >= now() - ($2::int * INTERVAL '1 day')
               AND ($3::uuid IS NULL OR branch_id = $3))::numeric(14,2) AS profit,
           (SELECT COALESCE(sum(cost_total), 0) FROM sales
             WHERE pharmacy_id = $1 AND status = 'completed'
               AND created_at >= now() - ($2::int * INTERVAL '1 day')
               AND ($3::uuid IS NULL OR branch_id = $3))::numeric(14,2) AS cost`,
        p,
      ),
      query(
        `SELECT c.id, COALESCE(c.name, 'Sans catégorie') AS name,
                COALESCE(sum(si.line_total), 0)::numeric(14,2) AS revenue,
                COALESCE(sum(si.quantity), 0)::numeric(12,3) AS qty
           FROM sale_items si
           JOIN sales s ON s.id = si.sale_id AND s.status = 'completed'
           JOIN medications m ON m.id = si.medication_id
           LEFT JOIN categories c ON c.id = m.category_id
          WHERE s.pharmacy_id = $1 AND ${win}
          GROUP BY c.id, c.name
          ORDER BY revenue DESC
          LIMIT 8`,
        p,
      ),
      query(
        `SELECT EXTRACT(HOUR FROM s.created_at)::int AS hour,
                COALESCE(sum(s.total), 0)::numeric(14,2) AS revenue,
                count(*)::int AS nb_sales
           FROM sales s
          WHERE s.pharmacy_id = $1 AND s.status = 'completed' AND ${win}
          GROUP BY 1 ORDER BY 1`,
        p,
      ),
      query(
        `SELECT EXTRACT(DOW FROM s.created_at)::int AS dow,
                COALESCE(sum(s.total), 0)::numeric(14,2) AS revenue,
                count(*)::int AS nb_sales
           FROM sales s
          WHERE s.pharmacy_id = $1 AND s.status = 'completed' AND ${win}
          GROUP BY 1 ORDER BY 1`,
        p,
      ),
      query(
        `SELECT m.id, m.name,
                COALESCE(sum(si.quantity), 0)::numeric(12,3) AS qty_sold,
                COALESCE(sum(si.line_total), 0)::numeric(14,2) AS revenue
           FROM sale_items si
           JOIN sales s ON s.id = si.sale_id AND s.status = 'completed'
           JOIN medications m ON m.id = si.medication_id
          WHERE s.pharmacy_id = $1 AND ${win}
          GROUP BY m.id
          ORDER BY revenue DESC
          LIMIT 5`,
        p,
      ),
    ]);

    const series = seriesRes.rows.map((r) => ({
      date: new Date(r.day).toISOString().slice(0, 10),
      revenue: Number(r.revenue ?? 0),
      nb_sales: Number(r.nb_sales ?? 0),
      profit: Number(r.profit ?? 0),
    }));

    const cmp = compareRes.rows[0] || {};
    const revenue = Number(cmp.revenue ?? 0);
    const revenuePrev = Number(cmp.revenue_prev ?? 0);
    const nbSales = Number(cmp.nb_sales ?? 0);
    const nbSalesPrev = Number(cmp.nb_sales_prev ?? 0);
    const profit = Number(cmp.profit ?? 0);
    const cost = Number(cmp.cost ?? 0);

    const forecast = weekdayForecast(series, 7);
    const revenueByDow = weekdayRes.rows.map((r) => ({
      dow: Number(r.dow),
      avg_daily_revenue: round2(Number(r.revenue ?? 0) / Math.max(1, days / 7)),
      nb_sales: Number(r.nb_sales ?? 0),
    }));

    return {
      generated_at: new Date().toISOString(),
      window_days: days,
      branch_id: branchId,
      series,
      summary: {
        revenue: round2(revenue),
        revenue_prev: round2(revenuePrev),
        revenue_change_pct: pctChange(revenue, revenuePrev),
        nb_sales: nbSales,
        nb_sales_prev: nbSalesPrev,
        sales_change_pct: pctChange(nbSales, nbSalesPrev),
        avg_basket: nbSales > 0 ? round2(revenue / nbSales) : 0,
        avg_basket_prev: nbSalesPrev > 0 ? round2(revenuePrev / nbSalesPrev) : 0,
        profit: round2(profit),
        margin_pct: revenue > 0 ? round2(((revenue - cost) / revenue) * 100) : null,
      },
      forecast_7d: forecast,
      top_categories: categoriesRes.rows,
      top_products: productsRes.rows,
      peak_hours: hoursRes.rows
        .map((r) => ({ hour: Number(r.hour), revenue: Number(r.revenue ?? 0), nb_sales: Number(r.nb_sales ?? 0) }))
        .sort((a, b) => b.revenue - a.revenue),
      revenue_by_weekday: revenueByDow,
    };
  },

  /** Fiches de réponses contextuelles de l'assistant. */
  _helpReply() {
    return {
      reply: 'Je peux analyser vos ventes et votre stock. Essayez : « CA du mois ? », « plan de réassort », '
        + '« ruptures de stock ? », « produits à péremption », « top produits », « heures de pointe », '
        + '« prévision semaine », « marge du mois », « clients débiteurs », « meilleurs vendeurs », '
        + '« liste des médicaments », « stock [nom du produit] », '
        + 'ou « prix [nom du produit] ».',
      intent: 'help',
    };
  },

  /** Détection de la période évoquée dans la question (en jours). */
  _detectPeriod(lower) {
    if (/(aujourd|today|du jour|hier|yesterday)/.test(lower)) return 1;
    if (/(semaine|week|7 ?j\b)/.test(lower)) return 7;
    if (/(mois|month|30 ?j\b)/.test(lower)) return 30;
    if (/(trimestre|quarter|90 ?j\b)/.test(lower)) return 90;
    return 30;
  },

  _fmtMoney(n) {
    return `${Number(n ?? 0).toLocaleString('fr-FR', { maximumFractionDigits: 2 })} MAD`;
  },

  /** Réponses de l'assistant : intentions métier sans LLM. */
  async chat(pharmacyId, userId, { query: text }) {
    const lower = (text || '').toLowerCase();
    let result;

    if (/(bonjour|salut|hello|salam|bonsoir|ahlan)/.test(lower)) {
      result = {
        reply: 'Bonjour ! Je suis l’assistant PHARMA MAROC GOLD. Demandez-moi vos ventes, votre stock, '
          + 'un plan de réassort ou une prévision de CA.',
        intent: 'greeting',
      };
    } else if (/(aide|help|que peux|que savez|comment ça)/.test(lower)) {
      result = this._helpReply();
    } else if (/(réassort|reassort|reorder|commander|approvisionn|rappro)/.test(lower)) {
      result = await this._chatReorder(pharmacyId);
    } else if (/(liste.*(médicament|produit|référence|catalogue)|catalogue|catalog|tous les (médicaments|produits)|mes (produits|références|médicaments))/i.test(lower)) {
      result = await this._chatCatalog(pharmacyId);
    } else if (/(rupture|stock|inventaire|épuisé)/.test(lower)) {
      result = await this._chatStock(pharmacyId, text);
    } else if (/(prévision|prevision|forecast|demain|semaine prochaine|tendance)/.test(lower)) {
      result = await this._chatForecast(pharmacyId);
    } else if (/(marge|profit|bénéfice|benefice|rentab)/.test(lower)) {
      result = await this._chatMargin(pharmacyId, this._detectPeriod(lower));
    } else if (/(périm|perim|expir|perte)/.test(lower)) {
      result = await this._chatExpiry(pharmacyId);
    } else if (/(pointe|affluence|heure|pic)/.test(lower)) {
      result = await this._chatPeakHours(pharmacyId);
    } else if (/(top|meilleur|star)/.test(lower)) {
      result = await this._chatTopProducts(pharmacyId);
    } else if (/(dette|débiteur|debiteur|créance|creance|crédit|impayé)/.test(lower)) {
      result = await this._chatDebtors(pharmacyId);
    } else if (/(vendeur|employé|employe|caissier|equipe)/.test(lower)) {
      result = await this._chatSellers(pharmacyId);
    } else if (/(^prix\b|prix de|prix du|quel est le prix|donne le prix|combien coûte|combien coute|coûte combien|coute combien)/.test(lower)) {
      result = await this._chatPrice(pharmacyId, text);
    } else if (/(vente|ca\b|chiffre|revenue|vendu|panier)/.test(lower)) {
      result = await this._chatRevenue(pharmacyId, this._detectPeriod(lower));
    } else if (/(merci|shokran|choukran|thanks)/.test(lower)) {
      result = { reply: 'Avec plaisir ! N’hésitez pas si vous avez d’autres questions.', intent: 'thanks' };
    } else {
      result = { ...this._helpReply(), reply: `Je n’ai pas compris cette question. ${this._helpReply().reply}` };
    }

    await auditLog({
      pharmacyId, userId, action: 'chat', module: 'ai', entity: 'assistant',
      newValues: { query: text, intent: result.intent },
    });
    return result;
  },

  /** « Plan de réassort » → top 5 des produits à commander. */
  async _chatReorder(pharmacyId) {
    const plan = await this.reorderPlan(pharmacyId, { daysCover: 14 });
    if (plan.items.length === 0) {
      return { reply: 'Aucun produit n’est sous son seuil de réapprovisionnement. Votre stock est bien tenu !', intent: 'reorder', data: plan };
    }
    const top = plan.items.slice(0, 5);
    const lines = top.map((i) => `• ${i.name} : commander ~${i.suggested_qty} u.`
      + (i.supplier_name ? ` (${i.supplier_name})` : ''));
    const more = plan.items.length > top.length ? `\n… et ${plan.items.length - top.length} autre(s).` : '';
    return {
      reply: `${plan.items.length} produit(s) à réapprovisionner, coût estimé ${this._fmtMoney(plan.total_estimated_cost)} :\n${lines.join('\n')}${more}`,
      intent: 'reorder',
      data: plan,
    };
  },

  /** « Ruptures / stock » → compteurs sous-seuil ou relevé d'un produit précis. */
  async _chatStock(pharmacyId, rawText = '') {
    // Si la question cite un nom de produit du catalogue, répondre produit par produit.
    if (rawText && typeof rawText === 'string') {
      const named = await this._matchCatalogProduct(pharmacyId, rawText);
      if (named) return named;
    }
    const { rows } = await query(
      `SELECT count(*) FILTER (WHERE t.stock <= t.reorder_level)::int AS low_count,
              count(*) FILTER (WHERE t.stock <= 0)::int AS out_count
         FROM (
           SELECT m.reorder_level,
                  COALESCE((SELECT SUM(sb.quantity - sb.reserved_quantity)
                              FROM stock_balances sb
                             WHERE sb.medication_id = m.id AND sb.pharmacy_id = $1), 0) AS stock
             FROM medications m
            WHERE m.pharmacy_id = $1 AND m.status = 'available'
         ) t`,
      [pharmacyId],
    );
    const low = rows[0]?.low_count ?? 0;
    const out = rows[0]?.out_count ?? 0;
    return {
      reply: `${low} référence(s) sous le seuil de réapprovisionnement, dont ${out} en rupture totale. `
        + 'Tapez « plan de réassort » pour la liste priorisée.',
      intent: 'stock',
      data: rows[0],
    };
  },

  /** Essaie de faire correspondre un nom de produit présent dans la question. */
  async _matchCatalogProduct(pharmacyId, text) {
    const q = (text || '').toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '');
    const { rows } = await query(
      `SELECT name FROM medications
        WHERE pharmacy_id = $1 AND status = 'available'
        ORDER BY name LIMIT 200`,
      [pharmacyId],
    );
    // Tokens significatifs de la question (mots de >3 lettres, hors mots outils).
    const stop = new Set(["combien", "avoir", "est", "sont", "il", "en", "de", "du", "des", "les", "dans", "niveau", "quand", "quel", "quelle", "stock", "rupture", "inventaire", "épuisé", "epuise", "j'ai", "mon", "mes", "ma"]);
    const qTokens = q.split(/[^a-z0-9]/)
      .map((t) => t.trim())
      .filter((t) => t.length >= 4 && !stop.has(t));
    if (qTokens.length === 0) return null;

    let best = null;
    let bestScore = 0;
    for (const r of rows) {
      const norm = String(r.name).toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '');
      const nameTokens = new Set(norm.split(/[^a-z0-9]/).filter((t) => t.length >= 4));
      // Le nom complet est présent dans la question → match parfait.
      if (q.includes(norm)) {
        if (norm.length > bestScore) { best = r.name; bestScore = norm.length; }
        continue;
      }
      // Score = nombre de tokens distincts du nom présents dans la question.
      let score = 0;
      for (const t of nameTokens) {
        if (qTokens.includes(t)) score++;
      }
      if (score > 0 && score > bestScore) {
        best = r.name;
        bestScore = score;
      }
    }
    if (!best) return null;
    const { rows: found } = await query(
      `SELECT m.name AS name, m.reorder_level,
              COALESCE((SELECT SUM(sb.quantity - sb.reserved_quantity)
                          FROM stock_balances sb
                         WHERE sb.medication_id = m.id AND sb.pharmacy_id = $1), 0)::numeric(12,3) AS stock
         FROM medications m
        WHERE m.pharmacy_id = $1 AND m.status = 'available' AND lower(m.name) = lower($2)
        LIMIT 1`,
      [pharmacyId, best],
    );
    if (found.length === 0) return null;
    const r = found[0];
    return {
      reply: `• ${r.name} : ${Number(r.stock)} u. en stock (seuil ${Number(r.reorder_level)} u.)`,
      intent: 'stock',
      data: r,
    };
  },

  /** « Catalogue / liste » → synthèse des médicaments disponibles. */
  async _chatCatalog(pharmacyId) {
    const { rows } = await query(
      `SELECT m.name,
              COALESCE((SELECT SUM(sb.quantity - sb.reserved_quantity)
                          FROM stock_balances sb
                         WHERE sb.medication_id = m.id AND sb.pharmacy_id = $1), 0)::numeric(12,3) AS stock,
              m.price_sale
         FROM medications m
        WHERE m.pharmacy_id = $1 AND m.status = 'available'
        ORDER BY m.name LIMIT 25`,
      [pharmacyId],
    );
    if (rows.length === 0) {
      return { reply: 'Votre catalogue est vide : aucune référence disponible dans cette pharmacie.', intent: 'catalog', data: [] };
    }
    const names = rows.map((r) => `• ${r.name} (${Number(r.stock)} u. — ${this._fmtMoney(r.price_sale)})`);
    const more = rows.length === 25 ? `\n… et plus de références (demandez « prix [nom] »).` : '';
    return {
      reply: `Catalogue (${rows.length} référence(s) disponibles) :\n${names.join('\n')}${more}`,
      intent: 'catalog',
      data: rows,
    };
  },

  /** « CA / ventes » → chiffre d'affaires de la période + panier moyen. */
  async _chatRevenue(pharmacyId, days) {
    const { rows } = await query(
      `SELECT COALESCE(SUM(total), 0)::numeric(14,2) AS revenue,
              count(*)::int AS nb_sales
         FROM sales
        WHERE pharmacy_id = $1 AND status = 'completed'
          AND created_at >= now() - ($2::int * INTERVAL '1 day')`,
      [pharmacyId, days],
    );
    const revenue = Number(rows[0]?.revenue ?? 0);
    const nb = rows[0]?.nb_sales ?? 0;
    const label = days === 1 ? "aujourd'hui" : `${days} derniers jours`;
    const basket = nb > 0 ? ` Panier moyen : ${this._fmtMoney(revenue / nb)}.` : '';
    return {
      reply: `Chiffre d'affaires ${label} : ${this._fmtMoney(revenue)} (${nb} vente(s)).${basket}`,
      intent: 'revenue',
      data: { days, ...rows[0] },
    };
  },

  /** « Marge / profit » → CA, coût, marge et taux. */
  async _chatMargin(pharmacyId, days) {
    const { rows } = await query(
      `SELECT COALESCE(SUM(total), 0)::numeric(14,2) AS revenue,
              COALESCE(SUM(cost_total), 0)::numeric(14,2) AS cost,
              COALESCE(SUM(total - cost_total), 0)::numeric(14,2) AS profit
         FROM sales
        WHERE pharmacy_id = $1 AND status = 'completed'
          AND created_at >= now() - ($2::int * INTERVAL '1 day')`,
      [pharmacyId, days],
    );
    const r = rows[0] || {};
    const revenue = Number(r.revenue ?? 0);
    const profit = Number(r.profit ?? 0);
    const pct = revenue > 0 ? ` soit ${round2((profit / revenue) * 100)} %` : '';
    return {
      reply: `Sur les ${days} derniers jours : CA ${this._fmtMoney(revenue)}, marge brute ${this._fmtMoney(profit)}${pct}.`,
      intent: 'margin',
      data: { days, ...r },
    };
  },

  /** « Péremptions » → unités expirées et lots à écouler sous 60 j. */
  async _chatExpiry(pharmacyId) {
    const { rows } = await query(
      `SELECT
         (SELECT COALESCE(SUM(b.quantity), 0) FROM lots l
            LEFT JOIN stock_balances b ON b.lot_id = l.id AND b.pharmacy_id = $1
           WHERE l.pharmacy_id = $1 AND l.expiry_date < CURRENT_DATE
             AND COALESCE(b.quantity, 0) > 0)::numeric(12,3) AS expired_qty,
         (SELECT count(*) FROM lots l
           WHERE l.pharmacy_id = $1 AND l.expiry_date BETWEEN CURRENT_DATE AND CURRENT_DATE + 60)::int AS soon_lots`,
      [pharmacyId],
    );
    const r = rows[0] || {};
    return {
      reply: `Unités déjà périmées : ${Number(r.expired_qty ?? 0)}. `
        + `${Number(r.soon_lots ?? 0)} lot(s) expirent dans les 60 prochains jours — pensez à les mettre en avant ou en promotion.`,
      intent: 'expiry',
      data: r,
    };
  },

  /** « Heures de pointe » → top 3 tranches horaires par CA (30 j). */
  async _chatPeakHours(pharmacyId) {
    const { rows } = await query(
      `SELECT EXTRACT(HOUR FROM s.created_at)::int AS hour,
              COALESCE(sum(s.total), 0)::numeric(14,2) AS revenue
         FROM sales s
        WHERE s.pharmacy_id = $1 AND s.status = 'completed'
          AND s.created_at >= now() - INTERVAL '30 days'
        GROUP BY 1 ORDER BY 2 DESC LIMIT 3`,
      [pharmacyId],
    );
    if (rows.length === 0) {
      return { reply: 'Pas encore assez de ventes sur 30 jours pour identifier vos heures de pointe.', intent: 'peak_hours' };
    }
    const lines = rows.map((r) => `• ${String(r.hour).padStart(2, '0')}h : ${this._fmtMoney(r.revenue)}`);
    return { reply: `Vos heures de pointe (30 jours) :\n${lines.join('\n')}`, intent: 'peak_hours', data: rows };
  },

  /** « Top produits » → 5 meilleures références par CA (30 j). */
  async _chatTopProducts(pharmacyId) {
    const { rows } = await query(
      `SELECT m.name,
              COALESCE(sum(si.quantity), 0)::numeric(12,3) AS qty_sold,
              COALESCE(sum(si.line_total), 0)::numeric(14,2) AS revenue
         FROM sale_items si
         JOIN sales s ON s.id = si.sale_id AND s.status = 'completed'
         JOIN medications m ON m.id = si.medication_id
        WHERE s.pharmacy_id = $1 AND s.created_at >= now() - INTERVAL '30 days'
        GROUP BY m.id ORDER BY revenue DESC LIMIT 5`,
      [pharmacyId],
    );
    if (rows.length === 0) {
      return { reply: 'Aucune vente enregistrée sur les 30 derniers jours.', intent: 'top_products' };
    }
    const lines = rows.map((r, idx) => `${idx + 1}. ${r.name} — ${this._fmtMoney(r.revenue)} (${Number(r.qty_sold)} u.)`);
    return { reply: `Top produits (30 jours) :\n${lines.join('\n')}`, intent: 'top_products', data: rows };
  },

  /** « Clients débiteurs » → encours clients. */
  async _chatDebtors(pharmacyId) {
    const { rows } = await query(
      `SELECT count(*) FILTER (WHERE credit_balance > 0)::int AS debtors,
              COALESCE(sum(credit_balance) FILTER (WHERE credit_balance > 0), 0)::numeric(14,2) AS total_due
         FROM customers WHERE pharmacy_id = $1`,
      [pharmacyId],
    );
    const r = rows[0] || {};
    return {
      reply: `${Number(r.debtors ?? 0)} client(s) avec un solde créditeur, pour un total de ${this._fmtMoney(r.total_due)}.`,
      intent: 'debtors',
      data: r,
    };
  },

  /** « Meilleurs vendeurs » → CA par utilisateur (30 j). */
  async _chatSellers(pharmacyId) {
    const { rows } = await query(
      `SELECT u.first_name || ' ' || u.last_name AS name,
              COALESCE(sum(s.total), 0)::numeric(14,2) AS revenue,
              count(*)::int AS nb_sales
         FROM sales s JOIN users u ON u.id = s.user_id
        WHERE s.pharmacy_id = $1 AND s.status = 'completed'
          AND s.created_at >= now() - INTERVAL '30 days'
        GROUP BY u.id ORDER BY revenue DESC LIMIT 5`,
      [pharmacyId],
    );
    if (rows.length === 0) {
      return { reply: 'Aucune vente attribuée sur les 30 derniers jours.', intent: 'sellers' };
    }
    const lines = rows.map((r) => `• ${r.name} : ${this._fmtMoney(r.revenue)} (${r.nb_sales} vente(s))`);
    return { reply: `Performance de l'équipe (30 jours) :\n${lines.join('\n')}`, intent: 'sellers', data: rows };
  },

  /** « Prix <produit> » → recherche par nom et renvoi du prix/stock. */
  async _chatPrice(pharmacyId, text) {
    const term = (text || '')
      .replace(/^(?:quel est|qu' est|donne moi|donnez moi|donne-moi)?\s*(?:le\s+)?prix\s+(?:de|du|des|d'|)\b|prix (?:de|du|des|d') *|combien coûte|combien coute|coûte combien|coute combien|\?/gi, '')
      .trim().slice(0, 60);
    if (!term) return this._helpReply();
    const { rows } = await query(
      `SELECT m.name, m.price_sale,
              COALESCE((SELECT SUM(sb.quantity - sb.reserved_quantity)
                          FROM stock_balances sb
                         WHERE sb.medication_id = m.id AND sb.pharmacy_id = $1), 0)::numeric(12,3) AS stock
         FROM medications m
        WHERE m.pharmacy_id = $1 AND m.status = 'available' AND m.name ILIKE $2
        ORDER BY m.name LIMIT 3`,
      [pharmacyId, `%${term}%`],
    );
    if (rows.length === 0) {
      return { reply: `Aucun produit trouvé pour « ${term} » dans votre catalogue.`, intent: 'price' };
    }
    const lines = rows.map((r) => `• ${r.name} : ${this._fmtMoney(r.price_sale)} — stock ${Number(r.stock)} u.`);
    return { reply: lines.join('\n'), intent: 'price', data: rows };
  },

  /** « Prévision » → CA attendu sur 7 jours. */
  async _chatForecast(pharmacyId) {
    const { rows } = await query(
      `SELECT d::date AS day, COALESCE(sum(s.total), 0)::numeric(14,2) AS revenue
         FROM generate_series((CURRENT_DATE - 29)::timestamp, CURRENT_DATE::timestamp, INTERVAL '1 day') d
         LEFT JOIN sales s ON s.pharmacy_id = $1 AND s.status = 'completed'
              AND s.created_at >= d AND s.created_at < d + INTERVAL '1 day'
        GROUP BY d ORDER BY d`,
      [pharmacyId],
    );
    const series = rows.map((r) => ({ date: new Date(r.day).toISOString().slice(0, 10), revenue: Number(r.revenue ?? 0) }));
    const forecast = weekdayForecast(series, 7);
    if (forecast.items.length === 0) {
      return { reply: 'Pas encore assez d’historique (30 jours) pour établir une prévision fiable.', intent: 'forecast' };
    }
    const avg = forecast.total / forecast.items.length;
    return {
      reply: `Prévision de CA sur les 7 prochains jours : ${this._fmtMoney(forecast.total)} `
        + `(≈ ${this._fmtMoney(avg)} / jour), basée sur vos 4 dernières semaines.`,
      intent: 'forecast',
      data: forecast,
    };
  },
};
