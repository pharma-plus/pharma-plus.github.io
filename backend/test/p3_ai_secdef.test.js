import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

/**
 * PHASE 3 — garde-fou de l'assistant IA (insights / reorder-plan /
 * sales-analysis) porté du backend Node vers des RPC SQL.
 *
 * Postgres/Deno ne sont pas disponibles ici : on vérifie donc (a) la
 * migration des fonctions (SECURITY DEFINER, search_path épinglé,
 * filtre pharmacie), (b) la migration de moindre privilège (REVOKE
 * PUBLIC/anon/authenticated → seul service_role), et (c) que la seule
 * voie d'appel (Edge pharma-api) utilise le client service_role avec
 * p_pharmacy issu du JWT vérifié — jamais d'une saisie utilisateur.
 */

const readRel = (p) => readFileSync(fileURLToPath(new URL(p, import.meta.url)), 'utf8');
const fnsSql = readRel('../../supabase/migrations/20261012180000_ai_insights_functions.sql');
const privSql = readRel('../../supabase/migrations/20261012190000_ai_functions_least_privilege.sql');
const edge = readRel('../../supabase/functions/pharma-api/index.ts');

const AI_FNS = {
  ai_insights: 'p_pharmacy uuid',
  ai_reorder_plan: 'p_pharmacy uuid, p_branch uuid, p_days_cover int',
  ai_sales_analysis: 'p_pharmacy uuid, p_branch uuid, p_days int',
};

function fnBlock(sql, name, args) {
  const start = sql.indexOf(`CREATE OR REPLACE FUNCTION public.${name}(${args})`);
  assert.ok(start > 0, `signature absente : ${name}(${args})`);
  const end = sql.indexOf('$$;', start);
  assert.ok(end > start, `bloc $$ non fermé pour ${name}`);
  return sql.slice(start, end);
}

test('IA : migration additive — aucun DROP/UPDATE/DELETE/TRUNCATE/ALTER TABLE', () => {
  assert.ok(!/\b(DROP|DELETE|TRUNCATE)\b/i.test(fnsSql), 'aucune suppression');
  assert.ok(!/\bUPDATE\s+[a-z_]+\s+SET\b/i.test(fnsSql), 'aucune écriture de données');
  assert.ok(!/ALTER\s+TABLE/i.test(fnsSql), 'aucune altération de table');
});

test('IA : les 3 fonctions sont SECURITY DEFINER + search_path épinglé + filtre pharmacie', () => {
  for (const [name, args] of Object.entries(AI_FNS)) {
    const b = fnBlock(fnsSql, name, args);
    assert.match(b, /LANGUAGE\s+sql/i, `${name} : LANGUAGE sql`);
    assert.match(b, /SECURITY\s+DEFINER/i, `${name} : SECURITY DEFINER`);
    assert.match(b, /SET\s+search_path\s*=\s*public/i, `${name} : search_path épinglé (anti-hijack)`);
    assert.match(b, /RETURNS\s+jsonb/i, `${name} : retour jsonb`);
    // Chaque fonction doit filtrer par p_pharmacy (séparation locataire).
    assert.ok(b.includes('p_pharmacy'), `${name} : paramètre p_pharmacy`);
    assert.ok(
      /pharmacy_id\s*=\s*p_pharmacy|pharmacy_id\s*=\s*p_pharmacy\b/i.test(b) ||
      /m\.pharmacy_id\s*=\s*p_pharmacy|s\.pharmacy_id\s*=\s*p_pharmacy|l\.pharmacy_id\s*=\s*p_pharmacy/i.test(b),
      `${name} : doit filtrer pharmacy_id = p_pharmacy`,
    );
  }
});

test('IA : moindre privilège — REVOKE PUBLIC/anon/authenticated, seul service_role garde EXECUTE', () => {
  // Révocations présentes pour les 3 fonctions.
  for (const name of Object.keys(AI_FNS)) {
    assert.ok(
      new RegExp(`REVOKE\\s+EXECUTE\\s+ON\\s+FUNCTION\\s+public\\.${name}\\([^)]*\\)\\s+FROM\\s+PUBLIC,\\s*anon,\\s*authenticated`, 'i').test(privSql),
      `${name} : REVOKE PUBLIC/anon/authenticated manquant`,
    );
    assert.ok(
      new RegExp(`GRANT\\s+EXECUTE\\s+ON\\s+FUNCTION\\s+public\\.${name}\\([^)]*\\)\\s+TO\\s+service_role`, 'i').test(privSql),
      `${name} : GRANT service_role manquant`,
    );
    // Aucun ré-grant vers les rôles exposés.
    assert.ok(
      !new RegExp(`GRANT\\s+EXECUTE\\s+ON\\s+FUNCTION\\s+public\\.${name}\\([^)]*\\)\\s+TO\\s+(PUBLIC|anon|authenticated)`, 'i').test(privSql),
      `${name} : ne pas ré-granter aux rôles exposés`,
    );
  }
  // Pas de suppression dans la migration de privilèges.
  assert.ok(!/\b(DROP|DELETE|TRUNCATE|UPDATE)\b/i.test(privSql), 'migration de privilèges non destructive');
});

test('IA : Edge appelle les 3 RPC via le client service_role avec p_pharmacy = pid (JWT)', () => {
  // Les appels rpc("ai_...") doivent passer par le client service_role `sb`.
  const rpcCalls = [...edge.matchAll(/\b(\w+)\.rpc\("([a-z_0-9]+)"/g)]
    .map((m) => ({ client: m[1], fn: m[2] }));
  const aiFns = new Set(Object.keys(AI_FNS));
  const aiCalls = rpcCalls.filter((c) => aiFns.has(c.fn));
  assert.equal(aiCalls.length, aiFns.size,
    `3 appels RPC IA attendus, trouvés ${aiCalls.length}`);
  for (const c of aiCalls) {
    assert.equal(c.client, 'sb', `RPC ${c.fn} doit passer par le client service_role (sb)`);
  }
  // Aucun appel via le client anon (sbAuth).
  assert.ok(!/sbAuth\.rpc\(/.test(edge), 'aucun RPC via le client anon (sbAuth)');

  // p_pharmacy doit provenir de pid (JWT vérifié), jamais de la requête.
  for (const name of Object.keys(AI_FNS)) {
    const at = edge.indexOf(`.rpc("${name}"`);
    assert.ok(at > 0, `appel RPC manquant dans Edge : ${name}`);
    const site = edge.slice(at, at + 160);
    assert.match(site, /p_pharmacy:\s*pid\b/, `${name} : p_pharmacy doit être pid (JWT)`);
  }
  assert.ok(
    !/p_pharmacy:\s*(?:url|searchParams|body|xPharmacy|branchId)/i.test(edge),
    'aucun p_pharmacy lu dans la requête',
  );
});

test('IA : routes IA exigent la méthode GET (pas de POST/DELETE accidentel)', () => {
  assert.match(edge, /if \(path === "ai\/insights" && req\.method === "GET"\)/);
  assert.match(edge, /if \(path === "ai\/reorder-plan" && req\.method === "GET"\)/);
  assert.match(edge, /if \(path === "ai\/sales-analysis" && req\.method === "GET"\)/);
});
