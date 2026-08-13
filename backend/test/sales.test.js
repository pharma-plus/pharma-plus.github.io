import { test } from 'node:test';
import assert from 'node:assert/strict';
import { computeLine } from '../src/modules/sales/service.js';

test('computeLine : calcul des totaux simple (TVA 20%)', () => {
  const r = computeLine({ quantity: 2, unit_price: 10, discount: 0, tva_rate: 20 });
  assert.equal(r.net, 20);
  assert.equal(r.tax, 4);
  assert.equal(r.discountAmount, 0);
});

test('computeLine : remise en pourcentage', () => {
  const r = computeLine({ quantity: 3, unit_price: 50, discount: 10, tva_rate: 20 });
  // gross = 150 ; remise 10% = 15 ; net = 135 ; taxe = 27
  assert.equal(r.net, 135);
  assert.equal(r.discountAmount, 15);
  assert.equal(r.tax, 27);
});

test('computeLine : remise de 100% → net nul', () => {
  const r = computeLine({ quantity: 1, unit_price: 40, discount: 100, tva_rate: 20 });
  assert.equal(r.net, 0);
  assert.equal(r.tax, 0);
});

test('computeLine : arrondis flottants maîtrisés', () => {
  const r = computeLine({ quantity: 1, unit_price: 0.1, discount: 0, tva_rate: 20 });
  assert.equal(Math.round(r.net * 100) / 100, 0.1);
  assert.equal(Math.round(r.tax * 100) / 100, 0.02);
});
