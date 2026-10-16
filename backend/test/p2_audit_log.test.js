import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

/**
 * BLOCAGE 1 — `_logAction` : contrat d'audit.
 * Le helper ecrivait entity_name / performed_by / changes, colonnes
 * absentes d'audit_logs (pharmacy_id, user_id, action, module, entity,
 * entity_id, old_values, new_values, ip_address, device, created_at),
 * et l'insertion n'etait pas attendue : l'echec disparuissait.
 */

const edgePath = fileURLToPath(
  new URL('../../supabase/functions/pharma-api/index.ts', import.meta.url),
);
const edge = readFileSync(edgePath, 'utf8');

const schemaDir = fileURLToPath(new URL('../../database/schema/', import.meta.url));
const ddl = readdirSync(schemaDir)
  .filter((f) => f.endsWith('.sql'))
  .map((f) => readFileSync(`${schemaDir}${f}`, 'utf8'))
  .join('\n');
const ddlMatch = ddl.match(/CREATE TABLE audit_logs\s*\(([\s\S]*?)\);/i);
assert.ok(ddlMatch, 'DDL audit_logs introuvable dans database/schema');
const columns = [...ddlMatch[1].matchAll(/^\s*([a-z_]+)\s+/gim)].map((m) => m[1]);

const helperStart = edge.indexOf('async function _logAction(');
assert.ok(helperStart > 0, '_logAction manquant');
const helper = edge.slice(helperStart, edge.indexOf('\n/* Routes accessibles sans JWT', helperStart));

test('audit : helper asynchrone, insertion attendue, echec visible', () => {
  assert.match(helper, /await sb\.from\("audit_logs"\)\.insert\(/,
    "l'insertion doit etre attendue (pas de promesse perdue)");
  assert.ok(!/throwOnError\(\)/.test(helper) || /await[\s\S]*throwOnError/.test(helper));
  assert.ok(!/catch \(e\) \{\s*console\.error\([^)]*\);\s*\}/.test(helper),
    "aucun catch qui avale l'erreur d'audit");
  assert.match(helper, /ECHEC ECRITURE/, "l'echec doit etre journalise explicitement");
  assert.match(helper, /throw new Error\(/, "l'erreur doit remonter au caller");
});

test('audit : seules les colonnes reels d audit_logs sont ecrites', () => {
  const payload = helper.slice(
    helper.indexOf('const { error }'),
    helper.indexOf('if (error)'),
  );
  const written = [
    ...[...payload.matchAll(/^\s*([a-z_]+)\s*:/gm)].map((m) => m[1]),
    ...[...payload.matchAll(/^\s*([a-z_]+),\s*$/gm)].map((m) => m[1]),
  ];
  assert.ok(written.length >= 8, `payload d'insertion incomplet: ${written.join(',')}`);
  for (const col of written) {
    assert.ok(columns.includes(col), `colonne inexistante dans audit_logs : ${col}`);
  }
  for (const forbidden of ['entity_name', 'performed_by', 'changes']) {
    assert.ok(!written.includes(forbidden), `colonne fantome encore ecrite : ${forbidden}`);
  }
  for (const expected of ['pharmacy_id', 'user_id', 'action', 'module', 'entity', 'entity_id',
    'old_values', 'new_values']) {
    assert.ok(written.includes(expected), `colonne attendue absente : ${expected}`);
  }
});

test('audit : user_id valide (uuid) ou null, jamais "unknown"', () => {
  assert.match(helper, /UUID_RE\.test\(performedBy\)/);
  assert.ok(!helper.includes("'unknown'") && !helper.includes('"unknown"'));
});

test('audit : 10 routes + 1 delegation, tous les echecs visibles', () => {
  const calls = [...edge.matchAll(/_logAction\(sb, pid, \{/g)];
  // 10 routes (auth/lock, medications POST, medication_update,
  // suppliers POST, supplier_update, stock_adjust, user_switched,
  // user_pin_set, user_pin_cleared, user_password_reset)
  // + 1 delegation (auditAttendance).
  assert.equal(calls.length, 11, `11 appels _logAction attendus (10 routes + auditAttendance), trouves ${calls.length}`);

  let idx = 0;
  let wrapped = 0;
  while (idx > -1) {
    const at = edge.indexOf('_logAction(sb, pid, {', idx);
    if (at < 0) break;
    const before = edge.slice(Math.max(0, at - 220), at);
    if (/try \{\s*await $/s.test(before)) {
      wrapped++;
      const after = edge.slice(at, at + 900);
      assert.match(after, /AUDIT_FAILED|audit_failed/, "l'echec d'audit doit etre expose");
    }
    idx = at + 10;
  }
  // Seule la delegation auditAttendance n'est pas wrappée ici : son
  // erreur remonte via le helper (throw) et les routes appeleuses
  // sont deja protegees.
  assert.equal(wrapped, 10, `10 appels proteges par try/catch attendus, trouves ${wrapped}`);
});

test('audit : plus aucune ecriture avec le contrat ancien', () => {
  assert.ok(!edge.includes('entity_name'), 'colonnes fantome entity_name');
  assert.ok(!edge.includes('performed_by'), 'colonnes fantome performed_by');
  assert.ok(!/insert\(\{[^}]*changes:/s.test(edge), 'colonne fantome changes');
  assert.ok(!/console\.error\("\[attendance\] audit:"/.test(edge),
    'auditAttendance ne doit plus avaler ses erreurs');
});
