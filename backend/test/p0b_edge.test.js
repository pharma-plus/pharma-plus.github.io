import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

/**
 * P0-B-5 — garde-fou statique sur la Edge Function `pharma-api`.
 * Deno n'est pas exécutable ici : on vérifie donc que les 4 handlers
 * existent, sont placés AVANT le proxy générique, et qu'ils respectent
 * les colonnes réellement présentes en base (schéma Supabase).
 */

const edgePath = fileURLToPath(
  new URL('../../supabase/functions/pharma-api/index.ts', import.meta.url),
);
const edge = readFileSync(edgePath, 'utf8');

const at = (needle) => {
  const i = edge.indexOf(needle);
  assert.ok(i > 0, `introuvable dans la Edge Function : ${needle}`);
  return i;
};

test('P0-B-5 : les 4 routes sont implémentées', () => {
  at('path === "reference/categories"');
  at('path === "reference/products"');
  at('refProductMatch');
  at('path === "sync/pull/medications"');
});

test('P0-B-5 : handlers placés avant le proxy générique', () => {
  const proxy = edge.indexOf('const genericMatch = path.match(');
  assert.ok(proxy > 0, 'proxy générique introuvable');
  assert.ok(at('path === "reference/products"') < proxy, 'reference/products doit précéder le proxy');
  assert.ok(at('refProductMatch') < proxy, 'import doit précéder le proxy');
  assert.ok(at('path === "sync/pull/medications"') < proxy, 'sync/pull doit précéder le proxy');
  assert.ok(edge.indexOf('path === "reference/categories"') < proxy,
    'reference/categories doit précéder le proxy');
});

test('P0-B-5 : plus aucune requête sur les colonnes inexistantes', () => {
  assert.ok(!/from\("reference_products"\)[^\n]*pharmacy_id/.test(edge),
    'reference_products n\'a pas de colonne pharmacy_id');
  assert.ok(!/from\("reference_categories"\)[^\n]*pharmacy_id/.test(edge),
    'reference_categories n\'a pas de colonne pharmacy_id');
  assert.ok(!/update\(\{ imported: true \}\)/.test(edge),
    'reference_products n\'a pas de colonne imported');
  assert.ok(!/from\("reference_categories"\)\.select\("\*"\)\.order\("name"\)/.test(edge),
    'reference_categories n\'a pas de colonne name (name_fr/name_ar/name_en)');
});

test('P0-B-5 : les erreurs SQL sont lues (désctructuration `error`)', () => {
  for (const marker of [
    'path === "reference/products"',
    'path === "sync/pull/medications"',
    'refProductMatch',
  ]) {
    const start = edge.indexOf(marker);
    const window = edge.slice(start, start + 1200);
    assert.match(window, /const \{[^}]*\berror\b[^}]*\} = await /,
      `handler ${marker} : variable "error" non désctructurée (ReferenceError en production)`);
  }
});

test('P0-B-5 : isolation multi-pharmacie conservée (filtre pharmacy_id)', () => {
  const start = edge.indexOf('path === "sync/pull/medications"');
  const window = edge.slice(start, start + 900);
  assert.match(window, /\.eq\("pharmacy_id", pid\)/, 'sync/pull doit filtrer par pharmacy_id');

  const importStart = edge.indexOf('refProductMatch');
  const importWindow = edge.slice(importStart, importStart + 6000);
  assert.match(importWindow, /\.eq\("pharmacy_id", pid\)/,
    'l\'import doit écrire dans le catalogue de la pharmacie connectée');
});

test('P0-B-5 : autorisations (reference:view en lecture, reference:create en import)', () => {
  assert.match(edge, /hasPermission\(sb, req, "reference:view"\)/);
  assert.match(edge, /hasPermission\(sb, req, "reference:create"\)/);
  assert.match(edge, /async function hasPermission\(/);
});

/* ---- P0-B-3 : POST /sales/returns réellement porté sur la Edge ---- */

test('P0-B-3 : handler sales/returns avant le proxy générique', () => {
  const i = at('path === "sales/returns"');
  const proxy = edge.indexOf('const genericMatch = path.match(');
  assert.ok(proxy > 0, 'proxy générique introuvable');
  assert.ok(i < proxy, 'sales/returns doit précéder le proxy sinon la route tombe dedans');
});

test('P0-B-3 : le retour délègue à la fonction atomique fn_sale_return', () => {
  assert.match(edge, /sb\.rpc\("fn_sale_return"/);
  const start = edge.indexOf('path === "sales/returns"');
  const window = edge.slice(start, start + 6000);
  assert.match(window, /hasPermission\(sb, req, "sales:create"\)/, 'permission sales:create requise');
  assert.match(window, /p_pharmacy: pid/, 'isolation pharmacie');
  assert.match(window, /p_user_id: userIdRet/, 'auteur = identité JWT vérifiée');
  assert.match(window, /json\(\{ data: retData \}, 201\)/, 'réponse 201 comme created() Express');
  for (const hint of ['ALREADY_RETURNED', 'INVALID_RETURN_QTY', 'DUPLICATE_ITEM', 'SALE_NOT_FOUND', 'ITEM_NOT_FOUND', 'VALIDATION']) {
    assert.ok(window.includes(hint), `mapping d'erreur manquant : ${hint}`);
  }
});

/* ---- email -> sub : l'identité vient du JWT vérifié, jamais d'un email ---- */

test('identité : plus de payload non vérifié ni d\'email comme identité', () => {
  assert.ok(!/jwtPayload\(req\)/.test(edge), 'jwtPayload(req) ne doit plus servir (non vérifié)');
  assert.ok(!/payload\?\.email/.test(edge), 'aucun identité lue dans payload.email');
  assert.ok(!/\.ilike\("email",\s*(authEmail|authEmail[A-Z]*)/.test(edge),
    'aucun utilisateur résolu par email à partir du JWT');
});

test('identité : currentUserId s\'appuie sur la signature (verifyJWT) et le claim sub', () => {
  const start = edge.indexOf('async function currentUserId(');
  assert.ok(start > 0, 'helper currentUserId manquant');
  const window = edge.slice(start, start + 500);
  assert.match(window, /await verifyJWT\(req\)/, 'currentUserId doit vérifier la signature');
  assert.match(window, /payload\?\.sub/, 'currentUserId doit lire le claim sub');
  assert.match(window, /UUID_RE\.test\(v\)/, 'sub doit être un uuid (users.id)');
});

test('identité : les routes à risque passent par les helpers vérifiés', () => {
  const cashAudit = edge.indexOf('path === "inventory/cash-audits" && req.method === "POST"');
  assert.ok(cashAudit > 0, 'route inventory/cash-audits (POST) manquante');
  assert.match(edge.slice(cashAudit, cashAudit + 1200), /currentUserId\(req\)/);

  const maintenance = edge.indexOf('path === "maintenance/reset"');
  assert.ok(maintenance > 0, 'route maintenance/reset manquante');
  assert.match(edge.slice(maintenance, maintenance + 1200),
    /hasPermission\(\s*sb,\s*req,\s*"settings:edit"\s*,?\s*\)/);

  const inventoryClose = edge.indexOf('close$/i');
  assert.ok(inventoryClose > 0, 'route inventory close manquante');
  assert.match(edge.slice(inventoryClose, inventoryClose + 800),
    /hasPermission\(\s*sb,\s*req,\s*"inventory:approve"\s*,?\s*\)/);
});

/* ---- Correctifs P0-B-3 : barcode + vente POS ---- */

test('barcode : la variable error est déstructurée (sinon ReferenceError)', () => {
  const start = edge.indexOf('catalog/medications/barcode" || path.startsWith');
  assert.ok(start > 0, 'handler barcode manquant');
  const window = edge.slice(start, start + 700);
  assert.match(window, /const \{ data, error \} = await sb\.from\("medications"\)/);
});

test('vente POS : sale_type conforme au schéma du dépôt (pos, pas cash)', () => {
  assert.match(edge, /\{ pos: "pos", cash: "cash", credit: "credit"/,
    'le Edge doit écrire pos comme le backend Express (007_sales.sql)');
});
