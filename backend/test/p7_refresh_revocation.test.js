import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

/**
 * P0 — correctifs Edge 2.5.9 (prompt sécurité §4.1 / §3.1) :
 *
 *  (a) /auth/refresh : contrôle users.status AVANT toute rotation — un
 *      compte désactivé/supprimé ne peut plus prolonger son accès, et la
 *      session est révoquée sur place (refus contrôlé) ;
 *  (b) plus de « profil de secours » synthétique en fallback refresh ;
 *  (c) PUT /users (status ≠ active) et DELETE /users (soft-delete) révoquent
 *      immédiatement toutes les sessions actives du compte ;
 *  (d) GET sur tables globales (permissions, role_permissions…) n'ajoute plus
 *      le filtre pharmacy_id (colonne inexistante → 42703) — le filtre est
 *      déclaré APRES GLOBAL_TABLES et le teste.
 */

const readRel = (p) => readFileSync(fileURLToPath(new URL(p, import.meta.url)), 'utf8');
const edge = readRel('../../supabase/functions/pharma-api/index.ts');

const refreshStart = edge.indexOf('path === "auth/refresh"');
const refreshEnd = edge.indexOf('/* -----------------------------------------------', refreshStart);
const refreshBlock = edge.slice(refreshStart, refreshEnd);

const usersStart = edge.indexOf('if (path === "users"');
const usersEnd = edge.indexOf('path === "auth/refresh"', usersStart);
const usersBlock = edge.slice(usersStart, usersEnd);

test('2.5.9 : EDGE_VERSION unique et bumpée', () => {
  const defs = [...edge.matchAll(/const EDGE_VERSION = "([0-9]+\.[0-9]+\.[0-9]+)"/g)];
  assert.equal(defs.length, 1);
  assert.equal(defs[0][1], '2.5.9');
});

test('a. refresh : refus contrôlé (PROFILE_MISSING / ACCOUNT_INACTIVE) + révocation', () => {
  assert.ok(refreshBlock.includes('PROFILE_MISSING'), 'refus si pas de profil applicatif');
  assert.ok(refreshBlock.includes('ACCOUNT_INACTIVE'), 'refus si compte non actif');
  assert.ok(
    refreshBlock.includes('.update({ revoked_at:') &&
      refreshBlock.includes('.eq("refresh_token_hash"'),
    'la session correspondante est révoquée au moment du refus',
  );
  assert.ok(
    refreshBlock.includes('profile.status !== "active"'),
    'contrôle users.status sur le profil applicatif',
  );
});

test('a2. refresh : la vérification de statut précède TOUTE rotation de session', () => {
  const checkAt = refreshBlock.indexOf('profile.status !== "active"');
  const refuseAt = refreshBlock.indexOf('ACCOUNT_INACTIVE');
  const rotateAt = refreshBlock.indexOf('Rotation de session');
  const insertAt = refreshBlock.indexOf('Session non tracee');
  assert.ok(checkAt > -1 && refuseAt > -1 && rotateAt > -1, 'blocs présents');
  assert.ok(checkAt < rotateAt, 'contrôle avant rotation');
  assert.ok(refuseAt < rotateAt, 'refus avant rotation (la branche d insertion jamais atteinte)');
  assert.ok(rotateAt < insertAt, 'insertion de session dans le bloc rotation only');
});

test('b. refresh : plus de profil de secours synthétique', () => {
  assert.ok(
    !refreshBlock.includes('first_name: "Admin"'),
    'fallback "Admin Pharma" supprimé — user toujours issu du profil réel',
  );
  assert.ok(refreshBlock.includes('const user = await enrichProfile(sb, profile)'));
  assert.ok(
    refreshBlock.includes('is_super_admin, status'),
    'le select du profil inclut status',
  );
});

test('c. PUT /users : révocation des sessions quand status != active', () => {
  assert.ok(usersBlock.includes('revoke sessions (PUT)'), 'point de révocation PUT');
  assert.ok(
    usersBlock.includes('patch.status !== undefined && patch.status !== "active"'),
    'déclenchée uniquement si le patch fait sortir le compte de active',
  );
  const updateAt = usersBlock.indexOf('.update(patch)');
  const revokeAt = usersBlock.indexOf('revoke sessions (PUT)');
  assert.ok(updateAt > -1 && revokeAt > updateAt, 'révocation APRÈS la mise à jour réussie');
});

test('c2. DELETE /users : révocation après le soft-delete', () => {
  assert.ok(usersBlock.includes('revoke sessions (DELETE)'), 'point de révocation DELETE');
  const delAt = usersBlock.indexOf('update({ status: "inactive" })');
  const revokeAt = usersBlock.indexOf('revoke sessions (DELETE)');
  assert.ok(delAt > -1 && revokeAt > delAt, 'révocation après la désactivation');
  assert.ok(usersBlock.includes('DELETE_FAILED'), 'échec soft-delete géré avant révocation');
});

test('d. GET tables globales : GLOBAL_TABLES déclaré avant le filtre et utilisé', () => {
  const globalDeclAt = edge.indexOf('const GLOBAL_TABLES = new Set([');
  const getFilterAt = edge.indexOf('!GLOBAL_TABLES.has(table)');
  assert.ok(globalDeclAt > -1, 'déclaration présente');
  assert.ok(getFilterAt > -1, 'filtre GET réécrit');
  assert.ok(globalDeclAt < getFilterAt, 'GLOBAL_TABLES déclaré AVANT usage');
  const guard = edge.slice(Math.max(0, getFilterAt - 80), getFilterAt);
  assert.ok(guard.includes('method === "GET"'), 'exemption dans la branche GET');
  assert.ok(guard.includes('if ('), 'condition if');
  assert.ok(edge.includes('"pharmacies", "permissions", "role_permissions"'), 'permissions/role_permissions = globales');
  const secondUse = edge.indexOf('!GLOBAL_TABLES.has(table)', getFilterAt + 1);
  assert.ok(secondUse > -1, 'HAS_PHARMACY réutilise aussi la déclaration');
});
