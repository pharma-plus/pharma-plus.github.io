import { test } from 'node:test';
import assert from 'node:assert/strict';
import { accountingService } from '../src/modules/accounting/service.js';
import { slugify } from '../src/modules/website/service.js';
import { computeLateMinutes } from '../src/modules/attendance/service.js';
import { ValidationError } from '../src/utils/errors.js';

test('comptabilité : rejette une écriture déséquilibrée avant tout accès base', async () => {
  await assert.rejects(
    () => accountingService.createEntry('pharmacy', {
      journalType: 'general',
      lines: [{ accountId: 'a', debit: 100 }, { accountId: 'b', credit: 80 }],
    }),
    (err) => err instanceof ValidationError,
  );
});

test('slugify : normalise les titres d’articles', () => {
  assert.equal(slugify('Bonjour le Monde !'), 'bonjour-le-monde');
  assert.equal(slugify('Été 2026 — Actus'), 'ete-2026-actus');
  assert.equal(slugify('  Paracetamol   (500mg) '), 'paracetamol-500mg');
});

test('pointage : calcule les minutes de retard vs 9h00', () => {
  assert.equal(computeLateMinutes(new Date('2026-01-05T08:59:00')), 0);
  assert.equal(computeLateMinutes(new Date('2026-01-05T09:15:00')), 15);
  assert.equal(computeLateMinutes(new Date('2026-01-05T10:00:00')), 60);
});
