/**
 * Moteur de calcul de l'assistant IA — fonctions pures (testables sans base).
 *
 * Le module IA reste déterministe (règles métier sur les données réelles).
 * Toute intégration LLM ultérieure pourra réutiliser ces fonctions comme
 * « outils » sans changer le contrat d'API.
 */

/** Arrondi monétaire à 2 décimales (évite les artefacts flottants). */
export function round2(n) {
  return Math.round((Number(n) + Number.EPSILON) * 100) / 100;
}

/**
 * Vitesse de vente quotidienne pondérée :
 * 70 % des 30 derniers jours + 30 % des 30 jours précédents, ramenée à un jour.
 * Renvoie toujours >= 0.
 */
export function dailyVelocity(sold30, sold60) {
  const s30 = Math.max(0, Number(sold30) || 0);
  const s60 = Math.max(0, Number(sold60) || 0);
  const prev30 = Math.max(0, s60 - s30); // le 60j inclut le 30j
  const velocity = (0.7 * s30 + 0.3 * prev30) / 30;
  return Math.max(0, velocity);
}

/** Couverture en jours du stock restant. `null` si vitesse nulle (pas de prévision). */
export function daysOfCover(stock, velocity) {
  if (!(velocity > 0)) return null;
  return Math.max(0, Number(stock) || 0) / velocity;
}

/**
 * Quantité suggérée à commander :
 *   couverture cible × vitesse + seuil de réappro (sécurité) − stock − déjà commandé
 * Arrondie au-dessus, jamais négative.
 */
export function suggestedQty({ stock, velocity, daysCoverTarget, reorderLevel, onOrder }) {
  const target = Math.max(0, Number(daysCoverTarget) || 0);
  const level = Math.max(0, Number(reorderLevel) || 0);
  const ordered = Math.max(0, Number(onOrder) || 0);
  const raw = (velocity || 0) * target + level - (Number(stock) || 0) - ordered;
  return Math.max(0, Math.ceil(raw - 1e-9));
}

/**
 * Priorité de réapprovisionnement :
 *  - `rupture`  : stock <= 0
 *  - `critique` : couverture < 7 jours
 *  - `haute`    : couverture < jours cibles
 *  - `normale`  : simplement sous le seuil (vitesse nulle ou faible)
 */
export function stockPriority({ stock, coverDays, daysCoverTarget = 14 }) {
  const target = Math.max(1, Number(daysCoverTarget) || 14);
  if ((Number(stock) || 0) <= 0) return 'rupture';
  if (coverDays == null) return 'normale';
  if (coverDays < 7) return 'critique';
  if (coverDays < target) return 'haute';
  return 'normale';
}

/** Variation en % entre deux périodes. `null` si la référence est nulle. */

/**
 * Prévision journalière sur `horizon` jours, basée sur les mêmes jours de
 * semaine des 4 semaines précédentes (moyenne pondérée 4,3,2,1) et un facteur
 * de tendance global (14 derniers jours vs 14 précédents, borné à ±30 %).
 *
 * @param {Array<{date: string, revenue: number}>} series  série journalière complète (au moins 29 jours)
 * @param {number} horizon nombre de jours à prévoir
 * @returns {{items: Array<{date: string, revenue: number}>, total: number}}
 */
export function weekdayForecast(series, horizon = 7) {
  const rows = (series || [])
    .map((r) => ({ date: String(r.date), revenue: Math.max(0, Number(r.revenue) || 0) }))
    .sort((a, b) => a.date.localeCompare(b.date));
  if (rows.length < 29 || horizon < 1) return { items: [], total: 0 };

  // Facteur de tendance : 14 derniers jours vs 14 précédents (borné 0.7 – 1.3).
  const last14 = rows.slice(-14).reduce((acc, r) => acc + r.revenue, 0);
  const prev14 = rows.slice(-28, -14).reduce((acc, r) => acc + r.revenue, 0);
  const trend = prev14 > 0 ? Math.min(1.3, Math.max(0.7, last14 / prev14)) : 1;

  const byWeekday = new Map();
  for (const row of rows) {
    const dow = new Date(`${row.date}T00:00:00Z`).getUTCDay();
    if (!byWeekday.has(dow)) byWeekday.set(dow, []);
    byWeekday.get(dow).push(row.revenue);
  }

  const weights = [4, 3, 2, 1];
  const last = new Date(`${rows[rows.length - 1].date}T00:00:00Z`);
  const items = [];
  for (let i = 1; i <= horizon; i++) {
    const day = new Date(last.getTime() + i * 86_400_000);
    const iso = day.toISOString().slice(0, 10);
    const history = (byWeekday.get(day.getUTCDay()) || []).slice(-4).reverse();
    if (history.length === 0) continue;
    let weighted = 0;
    let weightSum = 0;
    history.forEach((value, idx) => {
      const w = weights[idx] ?? 1;
      weighted += value * w;
      weightSum += w;
    });
    const forecast = round2((weighted / weightSum) * trend);
    items.push({ date: iso, revenue: forecast });
  }
  return { items, total: round2(items.reduce((acc, r) => acc + r.revenue, 0)) };
}

/**
 * Synthèse d'un plan de réassort : coût total estimé et regroupement par
 * fournisseur (les items sans fournisseur connu sont regroupés sous `Autres`).
 */
export function summarizeReorder(items) {
  const bySupplier = new Map();
  let totalCost = 0;
  let totalQty = 0;
  for (const item of items || []) {
    const qty = Math.max(0, Number(item.suggested_qty) || 0);
    const cost = Number(item.estimated_cost) || 0;
    totalQty += qty;
    totalCost += cost;
    const name = item.supplier_name || 'Autres';
    const bucket = bySupplier.get(name) || { supplier_name: name, items_count: 0, total_qty: 0, total_cost: 0 };
    bucket.items_count += 1;
    bucket.total_qty += qty;
    bucket.total_cost = round2(bucket.total_cost + cost);
    bySupplier.set(name, bucket);
  }
  const list = [...bySupplier.values()].sort((a, b) => b.total_cost - a.total_cost);
  return {
    total_estimated_cost: round2(totalCost),
    total_suggested_qty: round2(totalQty),
    by_supplier: list,
  };
}

const PRIORITY_ORDER = { rupture: 0, critique: 1, haute: 2, normale: 3 };

/** Tri d'un plan de réassort : priorité puis couverture croissante. */
export function sortReorderItems(items) {
  return [...(items || [])].sort((a, b) => {
    const pa = PRIORITY_ORDER[a.priority] ?? 9;
    const pb = PRIORITY_ORDER[b.priority] ?? 9;
    if (pa !== pb) return pa - pb;
    const ca = a.days_of_cover == null ? Number.MAX_SAFE_INTEGER : a.days_of_cover;
    const cb = b.days_of_cover == null ? Number.MAX_SAFE_INTEGER : b.days_of_cover;
    return ca - cb;
  });
}

export function pctChange(current, previous) {
  const prev = Number(previous) || 0;
  const cur = Number(current) || 0;
  if (prev === 0) return null;
  return round2(((cur - prev) / prev) * 100);
}
