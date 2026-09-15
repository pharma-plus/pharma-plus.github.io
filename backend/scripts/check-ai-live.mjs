// Validation en direct des requ├¬tes SQL du module AI (lecture seule).
import 'dotenv/config';
import { pool } from '../src/db/pool.js';
import { aiService } from '../src/modules/ai/service.js';

const { rows: pharmacies } = await pool.query(
  `SELECT p.id, p.name,
          (SELECT count(*)::int FROM sales s WHERE s.pharmacy_id = p.id AND s.status = 'completed') AS nb_sales
     FROM pharmacies p
    ORDER BY nb_sales DESC, p.created_at NULLS LAST
    LIMIT 5`,
);
if (pharmacies.length === 0) {
  console.log('Aucune pharmacie en base ÔÇö rien ├á valider.');
  process.exit(0);
}
console.log('Pharmacies (top ventes) :', pharmacies.map((p) => `${p.name}=${p.nb_sales}`).join(', '));
const ph = pharmacies[0];
console.log(`Pharmacie test├®e : ${ph.name} (${ph.id})`);

const insights = await aiService.insights(ph.id);
console.log(`insights        : reorder=${insights.reorder_soon.length}, expiring=${insights.expiring_within_60d.length}, no_sales=${insights.no_sales_30d.length}, top=${insights.top_sellers_30d.length}, low_margin=${insights.low_margin_30d.length}, expired_units=${insights.expired_units}`);

const plan = await aiService.reorderPlan(ph.id, { daysCover: 14 });
console.log(`reorder-plan    : ${plan.items.length} produit(s), qty totale=${plan.total_suggested_qty}, co├╗t estim├®=${plan.total_estimated_cost}, fournisseurs=${plan.by_supplier.length}`);
console.log(`   top 3 : ${plan.items.slice(0, 3).map((i) => `${i.name} (prio=${i.priority}, qty=${i.suggested_qty}, couv=${i.days_of_cover ?? 'Ôê×'}j)`).join(' | ')}`);

const analysis = await aiService.salesAnalysis(ph.id, { days: 30 });
console.log(`sales-analysis  : s├®rie=${analysis.series.length} j, CA=${analysis.summary.revenue}, variation=${analysis.summary.revenue_change_pct}%, panier moyen=${analysis.summary.avg_basket}, marge=${analysis.summary.margin_pct}%`);
console.log(`   pr├®vision 7j=${analysis.forecast_7d.total} (${analysis.forecast_7d.items.length} jours), heures de pointe=${analysis.peak_hours.slice(0, 3).map((h) => `${h.hour}h`).join(', ')}`);
console.log(`   top cat├®gories=${analysis.top_categories.slice(0, 3).map((c) => `${c.name}:${c.revenue}`).join(' | ')}`);

const chat = await aiService.chat(ph.id, null, { query: 'plan de r├®assort' });
console.log(`chat (r├®assort) : intent=${chat.intent}, reply="${chat.reply.slice(0, 120)}ÔÇª"`);
const chat2 = await aiService.chat(ph.id, null, { query: 'CA du mois ?' });
console.log(`chat (CA)       : intent=${chat2.intent}, reply="${chat2.reply.slice(0, 120)}"`);
const chat3 = await aiService.chat(ph.id, null, { query: 'pr├®vision semaine' });
console.log(`chat (pr├®vision): intent=${chat3.intent}, reply="${chat3.reply.slice(0, 120)}"`);
const chat4 = await aiService.chat(ph.id, null, { query: 'prix doliprane' });
console.log(`chat (prix)     : intent=${chat4.intent}, reply="${chat4.reply.slice(0, 120)}"`);

await pool.end();
console.log('\nVALIDATION LIVE OK');
process.exit(0);
