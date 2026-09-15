import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  round2, dailyVelocity, daysOfCover, suggestedQty, stockPriority,
  pctChange, weekdayForecast, summarizeReorder, sortReorderItems,
} from '../src/modules/ai/math.js';

test('round2 : arrondi monétaire sans artefacts flottants', () => {
  assert.equal(round2(0.1 + 0.2), 0.3);
  assert.equal(round2(10.005), 10.01);
  assert.equal(round2('12.345'), 12.35);
});

test('dailyVelocity : pondération 70 % 30j / 30 % 30j précédents', () => {
  // 30 ventes sur 30 j, aucune avant → 30 * 0.7 / 30 = 0.7/j
  assert.equal(dailyVelocity(30, 30), 0.7);
  // 30 sur 30 j + 30 sur les 30 précédents → (0.7*30 + 0.3*30)/30 = 1
  assert.equal(dailyVelocity(30, 60), 1);
  // décroissance : 0 sur 30 j, 60 sur 60 j → 0.3*60/30 = 0.6
  assert.equal(dailyVelocity(0, 60), 0.6);
  // valeurs nulles / négatives bornées à 0
  assert.equal(dailyVelocity(0, 0), 0);
  assert.equal(dailyVelocity(-5, -2), 0);
});

test('daysOfCover : null si vitesse nulle, sinon stock / vitesse', () => {
  assert.equal(daysOfCover(10, 0), null);
  assert.equal(daysOfCover(10, null), null);
  assert.equal(daysOfCover(30, 1), 30);
  assert.equal(daysOfCover(0, 2), 0);
});

test('suggestedQty : couverture cible + seuil − stock − déjà commandé (ceil, >= 0)', () => {
  // vitesse 2/j, cible 14 j → 28 ; + seuil 10 ; stock 5 ; rien commandé → 33
  assert.equal(suggestedQty({ stock: 5, velocity: 2, daysCoverTarget: 14, reorderLevel: 10, onOrder: 0 }), 33);
  // déjà commandé réduit la suggestion : 33 - 20 = 13
  assert.equal(suggestedQty({ stock: 5, velocity: 2, daysCoverTarget: 14, reorderLevel: 10, onOrder: 20 }), 13);
  // sans vitesse : ramène au seuil (10 - 3 = 7)
  assert.equal(suggestedQty({ stock: 3, velocity: 0, daysCoverTarget: 14, reorderLevel: 10, onOrder: 0 }), 7);
  // jamais négatif
  assert.equal(suggestedQty({ stock: 100, velocity: 0, daysCoverTarget: 7, reorderLevel: 5, onOrder: 0 }), 0);
});

test('stockPriority : rupture → critique → haute → normale', () => {
  assert.equal(stockPriority({ stock: 0, coverDays: 0 }), 'rupture');
  assert.equal(stockPriority({ stock: -2, coverDays: null }), 'rupture');
  assert.equal(stockPriority({ stock: 4, coverDays: 3 }), 'critique');
  assert.equal(stockPriority({ stock: 10, coverDays: 10 }), 'haute');
  assert.equal(stockPriority({ stock: 20, coverDays: 20 }), 'normale');
  assert.equal(stockPriority({ stock: 8, coverDays: null }), 'normale');
});

test('pctChange : null si référence nulle, sinon variation en %', () => {
  assert.equal(pctChange(120, 100), 20);
  assert.equal(pctChange(50, 200), -75);
  assert.equal(pctChange(100, 0), null);
  assert.equal(pctChange(0, 0), null);
});

test('weekdayForecast : moyenne pondérée des mêmes jours de semaine + tendance', () => {
  // Série de 28 jours + 1 : chaque jour vaut 100 → prévision 100/j, tendance 1
  const series = [];
  const start = new Date('2026-07-01T00:00:00Z');
  for (let i = 0; i < 30; i++) {
    const d = new Date(start.getTime() + i * 86_400_000);
    series.push({ date: d.toISOString().slice(0, 10), revenue: 100 });
  }
  const forecast = weekdayForecast(series, 7);
  assert.equal(forecast.items.length, 7);
  assert.equal(forecast.total, 700);
  for (const item of forecast.items) assert.equal(item.revenue, 100);

  // historique insuffisant → vide
  assert.deepEqual(weekdayForecast(series.slice(0, 10), 7), { items: [], total: 0 });

  // tendance haussière bornée : 100 puis 300 → la prévision intègre la hausse
  // (moyenne des mêmes jours de semaine, plafonnée par le facteur ≤ 1.3)
  const growing = series.map((r) => ({ ...r }));
  growing.forEach((r, i) => { r.revenue = i < 15 ? 100 : 300; });
  const f2 = weekdayForecast(growing, 7);
  assert.ok(f2.total > 700, 'la tendance haussière doit augmenter la prévision');
  assert.ok(f2.total <= 300 * 1.3 * 7, 'la tendance est bornée à +30 %');
});

test('summarizeReorder : totaux et regroupement par fournisseur', () => {
  const summary = summarizeReorder([
    { suggested_qty: 10, estimated_cost: 100, supplier_name: 'Cooper' },
    { suggested_qty: 5, estimated_cost: 60, supplier_name: 'Cooper' },
    { suggested_qty: 8, estimated_cost: 88, supplier_name: null },
  ]);
  assert.equal(summary.total_suggested_qty, 23);
  assert.equal(summary.total_estimated_cost, 248);
  assert.equal(summary.by_supplier.length, 2);
  assert.deepEqual(summary.by_supplier[0], { supplier_name: 'Cooper', items_count: 2, total_qty: 15, total_cost: 160 });
  assert.equal(summary.by_supplier[1].supplier_name, 'Autres');
  assert.deepEqual(summarizeReorder([]), { total_estimated_cost: 0, total_suggested_qty: 0, by_supplier: [] });
});

test('sortReorderItems : ruptures d’abord, puis couverture croissante', () => {
  const sorted = sortReorderItems([
    { priority: 'normale', days_of_cover: 30 },
    { priority: 'critique', days_of_cover: 5 },
    { priority: 'rupture', days_of_cover: 0 },
    { priority: 'critique', days_of_cover: 2 },
    { priority: 'haute', days_of_cover: 12 },
  ]);
  assert.deepEqual(sorted.map((i) => i.priority), ['rupture', 'critique', 'critique', 'haute', 'normale']);
  assert.deepEqual(sorted.map((i) => i.days_of_cover), [0, 2, 5, 12, 30]);
});
