import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

/**
 * P6 — Contrat du profil d'authentification du backend local :
 *
 *  (a) /auth/me expose is_super_admin (colonne réelle de public.users,
 *      jamais déduite du rôle) et visible_modules (text[]) ;
 *  (b) /auth/refresh renvoie le profil assaini (aligné sur /auth/login
 *      et la fonction Edge) — le frontend refuse toute rotation sans
 *      profil ;
 *  (c) aucun hash ni secret (password_hash, pin_hash, two_factor_secret)
 *      n'est exposé par me() ni par sanitizeUser.
 *
 * Test statique de contrat (aucune donnée réelle n'est lue ou modifiée).
 */

const readRel = (p) => readFileSync(fileURLToPath(new URL(p, import.meta.url)), 'utf8');
const service = readRel('../../backend/src/core/auth/service.js');

const meStart = service.indexOf('async me(userId)');
const meEnd = service.indexOf('},', meStart);
const meBlock = service.slice(meStart, meEnd);

const refreshStart = service.indexOf('async refresh(refreshToken, device)');
const refreshEnd = service.indexOf('async logout(', refreshStart);
const refreshBlock = service.slice(refreshStart, refreshEnd);

test('/auth/me : le SELECT expose la colonne réelle is_super_admin', () => {
  assert.match(meBlock, /u\.is_super_admin/);
  assert.doesNotMatch(meBlock, /is_super_admin\s*=\s*(true|false)/i);
  assert.doesNotMatch(meBlock, /role_code[^;]*super/i);
});

test('/auth/me : le SELECT expose la colonne réelle visible_modules', () => {
  assert.match(meBlock, /u\.visible_modules/);
});

test('/auth/me : aucun hash ni secret dans la projection', () => {
  assert.doesNotMatch(meBlock, /password_hash|pin_hash|two_factor_secret/);
});

test('/auth/refresh : la rotation renvoie le profil assaini', () => {
  assert.match(refreshBlock, /return\s*\{\s*user:\s*sanitizeUser\(user\),\s*\.\.\.newTokens\s*\}/);
});

test('/auth/refresh : profil complet (is_super_admin + visible_modules via u.*)', () => {
  assert.match(refreshBlock, /SELECT \* FROM users WHERE id = \$1/);
});

test('sanitizeUser : aucun hash ni secret exposé (login/refresh/me)', () => {
  const suStart = service.indexOf('sanitizeUser');
  const sanitize = readRel('../../backend/src/utils/crypto.js');
  assert.ok(suStart > 0);
  assert.match(sanitize, /delete copy\.password_hash/);
  assert.match(sanitize, /delete copy\.pin_hash/);
  assert.match(sanitize, /delete copy\.two_factor_secret/);
});

test('/auth/login : profil complet (u.* conserve les colonnes du contrat)', () => {
  const loginStart = service.indexOf('async login(email, password, device)');
  const loginEnd = service.indexOf('async recordFailedAttempt', loginStart);
  const loginBlock = service.slice(loginStart, loginEnd);
  assert.match(loginBlock, /SELECT u\.\*/);
  assert.match(loginBlock, /user: sanitizeUser\(user\)/);
});

test('frontend : User.dart lit is_super_admin ET isSuperAdmin (contrat aligné)', () => {
  const userDart = readRel('../../frontend/lib/core/models/user.dart');
  assert.match(userDart, /json\['is_super_admin'\]/);
  assert.match(userDart, /json\['isSuperAdmin'\]/);
  assert.match(userDart, /bool\? isSuperAdminFlag/);
});

test('frontend : les endpoints distants et locaux partagent le contrat refresh', () => {
  const edge = readRel('../../supabase/functions/pharma-api/index.ts');
  const refreshEdgeStart = edge.indexOf('path === "auth/refresh"');
  const refreshEdgeBlock = edge.slice(refreshEdgeStart, refreshEdgeStart + 6000);
  assert.match(refreshEdgeBlock, /user,\s*\},\s*\}\);/);
});
