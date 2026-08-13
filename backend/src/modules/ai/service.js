import { query } from '../../db/pool.js';
import { auditLog } from '../../middleware/audit.js';

/**
 * Assistant intelligent (v1) : règles métier déterministes sur les données
 * réelles (ventes, stock, achats). Une intégration LLM optionnelle pourra
 * remplacer le moteur de réponses sans changer le contrat d'API.
 */
export const aiService = {
  async insights(pharmacyId) {
    const [reorders, expiring, slowMovers, topSellers, lowMargin] = await Promise.all([
      query(
        `SELECT m.id, m.name, m.barcode_ean13,
                COALESCE(SUM(sb.quantity), 0)::numeric(12,3) AS current_stock,
                m.reorder_level, m.min_stock,
                (SELECT COALESCE(SUM(oi.quantity), 0)::numeric(12,3)
                   FROM sale_items oi JOIN sales s2 ON s2.id = oi.sale_id
                  WHERE oi.medication_id = m.id AND s2.pharmacy_id = $1
                    AND s2.created_at >= now() - INTERVAL '30 days') AS monthly_demand,
                COALESCE(avg(ms.price), 0)::numeric(14,2) AS last_purchase_price
           FROM medications m
           LEFT JOIN stock_balances sb ON sb.medication_id = m.id AND sb.pharmacy_id = $1
           LEFT JOIN medication_suppliers ms ON ms.medication_id = m.id AND ms.pharmacy_id = $1
          WHERE m.pharmacy_id = $1 AND m.status = 'available'
          GROUP BY m.id
          HAVING COALESCE(SUM(sb.quantity), 0) <= m.reorder_level
          ORDER BY COALESCE(SUM(sb.quantity), 0) - m.reorder_level
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
             AND s.created_at >= now() - INTERVAL '30 days'
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
             AND s.created_at >= now() - INTERVAL '30 days'
          WHERE m.pharmacy_id = $1
          GROUP BY m.id
          ORDER BY revenue_30d DESC LIMIT 10`,
        [pharmacyId],
      ),
    ]);

    return {
      generated_at: new Date().toISOString(),
      reorder_soon: reorders.rows,
      expiring_within_60d: expiring.rows,
      no_sales_30d: slowMovers.rows,
      top_sellers_30d: topSellers.rows,
    };
  },

  /** Réponses simples aux requêtes de l'assistant (sans LLM). */
  async chat(pharmacyId, { query: text }) {
    const lower = (text || '').toLowerCase();
    let reply;

    if (/(stock|rupture|réassort|reappro|seuil)/.test(lower)) {
      const { rows } = await query(
        `SELECT count(*)::int AS low_count FROM medications m
          LEFT JOIN stock_balances sb ON sb.medication_id = m.id AND sb.pharmacy_id = $1
         WHERE m.pharmacy_id = $1 AND m.status = 'available'
         GROUP BY m.id HAVING COALESCE(SUM(sb.quantity), 0) <= m.reorder_level`,
        [pharmacyId],
      );
      reply = `${rows[0]?.low_count ?? 0} référence(s) sous le seuil de réapprovisionnement. Consultez les alertes de stock pour les détails.`;
    } else if (/(vente|ca |chiffre|revenue|vendu)/.test(lower)) {
      const { rows } = await query(
        `SELECT COALESCE(SUM(total), 0)::numeric(14,2) AS revenue_30d,
                count(*)::int AS sales_30d
           FROM sales WHERE pharmacy_id = $1 AND created_at >= now() - INTERVAL '30 days'`,
        [pharmacyId],
      );
      reply = `Chiffre d'affaires des 30 derniers jours : ${rows[0].revenue_30d} MAD (${rows[0].sales_30d} ventes).`;
    } else if (/(expir|périm|perte)/.test(lower)) {
      const { rows } = await query(
        `SELECT COALESCE(SUM(b.quantity), 0)::numeric(12,3) AS qty
           FROM lots l LEFT JOIN stock_balances b ON b.lot_id = l.id AND b.pharmacy_id = $1
          WHERE l.pharmacy_id = $1 AND l.expiry_date < CURRENT_DATE`,
        [pharmacyId],
      );
      reply = `Il y a actuellement ${rows[0].qty} unité(s) périmée(s) en stock.`;
    } else if (/(bonjour|salut|hello|salam|bonsoir)/.test(lower)) {
      reply = 'Bonjour ! Je suis l’assistant PHARMA MAROC GOLD. Posez-moi une question sur vos ventes, votre stock ou vos alertes.';
    } else {
      reply = 'Je peux vous aider sur les ventes (CA 30 jours), le stock (sous-seuils), et les produits à péremption. Essayez : « rupture de stock ? ».';
    }

    await auditLog({ pharmacyId, userId: null, action: 'chat', module: 'ai', entity: 'assistant', newValues: { query: text, reply } });
    return { reply };
  },
};
