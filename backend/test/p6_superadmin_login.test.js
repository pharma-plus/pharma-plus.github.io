import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { decideLoginProfile } from '../../supabase/functions/pharma-api/login_policy.ts';

/**
 * P0 superadmin (prompt sécurité §3.2 / §3.4 / §5) :
 *
 *  (a) finishLogin n'attribue PLUS aucun privilège de secours — un compte
 *      Supabase Auth sans profil applicatif valide reçoit un refus contrôlé ;
 *  (b) la décision vit dans login_policy.ts (module pur, testé ici en
 *      comportement — scénarios 1 à 7 demandés) ;
 *  (c) __diag exige le superadmin vérifié côté serveur (plus settings:edit) ;
 *  (d) aucune route users n'écrit is_super_admin depuis un corps de requête ;
 *  (e) le portail superadmin front reste conditionné au flag serveur.
 *
 * Aucun test ici ne modifie un compte réel : les scénarios de comportement
 * tournent sur des profils factices, les vérifications de source lisent le
 * dépôt, et la preuve live (admin@pharma.ma) est faite par sondes séparées.
 */

const readRel = (p) => readFileSync(fileURLToPath(new URL(p, import.meta.url)), 'utf8');
const edge = readRel('../../supabase/functions/pharma-api/index.ts');
const appDart = readRel('../../frontend/lib/app.dart');

const finishStart = edge.indexOf('async function finishLogin(');
const finishEnd = edge.indexOf('function mapTable(', finishStart);
const finishBlock = edge.slice(finishStart, finishEnd);
const diagStart = edge.indexOf('path === "__diag" || path === "/__diag"');
const diagBlock = edge.slice(diagStart, diagStart + 600);

/* ---------------- Comportement (login_policy.ts) ---------------- */

const profile = (over = {}) => ({
  id: '11111111-1111-4111-8111-111111111111',
  email: 'user@pharma.ma',
  pharmacy_id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  branch_id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  role_id: '00000000-0000-0000-0000-000000000003',
  status: 'active',
  is_super_admin: false,
  ...over,
});

test('1. compte Auth + profil applicatif valide → session acceptée, privilèges = base', () => {
  const d = decideLoginProfile({
    profileById: null,
    profileByEmail: profile(),
    sessionEmail: 'user@pharma.ma',
  });
  assert.equal(d.ok, true);
  assert.equal(d.profile.is_super_admin, false, 'aucun privilège ajouté');
  assert.equal(d.profile.role_id, '00000000-0000-0000-0000-000000000003', 'rôle conservé');
});

test('2. compte Auth SANS profil applicatif → refus contrôlé PROFILE_MISSING', () => {
  const d = decideLoginProfile({
    profileById: null,
    profileByEmail: null,
    sessionEmail: 'orphan@pharma.ma',
  });
  assert.equal(d.ok, false);
  assert.equal(d.code, 'PROFILE_MISSING');
  assert.ok(d.message.includes('Profil applicatif introuvable'), 'message maîtrisé');
  // La décision contient AUCUN objet de profil reconstruit :
  assert.ok(!('profile' in d) || d.profile === undefined, 'pas de profil synthétique');
});

test('3. profil sans rôle attribué → refus PROFILE_INCOMPLETE (pas de rôle par défaut)', () => {
  const d = decideLoginProfile({
    profileById: null,
    profileByEmail: profile({ role_id: null }),
    sessionEmail: 'user@pharma.ma',
  });
  assert.equal(d.ok, false);
  assert.equal(d.code, 'PROFILE_INCOMPLETE');
});

test('4. profil désactivé → refus PROFILE_DISABLED', () => {
  const d = decideLoginProfile({
    profileById: null,
    profileByEmail: profile({ status: 'inactive' }),
    sessionEmail: 'user@pharma.ma',
  });
  assert.equal(d.ok, false);
  assert.equal(d.code, 'PROFILE_DISABLED');
});

test('5. identité Auth/profil incohérentes → refus IDENTITY_MISMATCH', () => {
  // (a) deux lignes différentes revendiquent la même session
  const a = decideLoginProfile({
    profileById: profile({ id: '11111111-1111-4111-8111-111111111111' }),
    profileByEmail: profile({ id: '22222222-2222-4222-8222-222222222222' }),
    sessionEmail: 'user@pharma.ma',
  });
  assert.equal(a.ok, false);
  assert.equal(a.code, 'IDENTITY_MISMATCH');
  // (b) email du profil ≠ email de la session
  const b = decideLoginProfile({
    profileById: null,
    profileByEmail: profile({ email: 'autre@pharma.ma' }),
    sessionEmail: 'user@pharma.ma',
  });
  assert.equal(b.ok, false);
  assert.equal(b.code, 'IDENTITY_MISMATCH');
});

test('6. compte ordinaire → aucun privilège global, portail superadmin verrouillé', () => {
  const d = decideLoginProfile({
    profileById: null,
    profileByEmail: profile(),
    sessionEmail: 'user@pharma.ma',
  });
  assert.equal(d.ok, true);
  assert.notEqual(d.profile.is_super_admin, true, 'ordinaire ≠ superadmin');

  // Front : le portail ne s'ouvre que sur le flag fourni par le serveur.
  assert.match(appDart, /auth\.user\?\.isSuperAdmin == true/,
    'SuperAdminPortal conditionné à isSuperAdmin serveur');

  // Serveur : hasPermission ne bypass que sur la colonne base + rôle présent.
  const hpStart = edge.indexOf('async function hasPermission(');
  const hpBlock = edge.slice(hpStart, hpStart + 1500);
  assert.match(hpBlock, /if \(u\.is_super_admin\) return \{ allowed: true, userId \};/,
    'bypass superadmin = colonne base uniquement');
  assert.match(hpBlock, /if \(!u\.role_id\) return \{ allowed: false, userId \};/,
    'compte sans rôle = refus');

  // Les routes users lisent le drapeau d'un profil, jamais du corps requête.
  assert.ok(
    edge.includes('const { email, password, first_name, last_name, role_id, employee_id } ='),
    'POST /users : whitelist de champs (pas de is_super_admin dans le body)',
  );
  assert.ok(
    edge.includes('employee_id, branch_id } ='),
    'PUT /users/:id : whitelist de champs (branch_id ajoute en 2.5.7, pas de is_super_admin dans le body)',
  );
  assert.ok(!/patch\.is_super_admin/.test(edge), 'aucun patch is_super_admin');
});

test('7. privilèges du superadmin viennent de la base, jamais reconstruits', () => {
  const d = decideLoginProfile({
    profileById: null,
    profileByEmail: profile({ is_super_admin: true }),
    sessionEmail: 'user@pharma.ma',
  });
  assert.equal(d.ok, true);
  assert.equal(d.profile.is_super_admin, true, 'flag base préservé tel quel');
  // enrichProfile expose la colonne telle quelle (défaut false si absente).
  assert.match(edge, /is_super_admin: profile\.is_super_admin \?\? false/);
  // La route /auth/me renvoie le profil enrichi (preuve live : sondes).
  assert.ok(edge.includes('enrichProfile(sb, profile)'), 'auth/me via enrichProfile');
});

/* ---------------- Source : finishLogin sans fallback ---------------- */

test('finishLogin : plus aucun fallback is_super_admin de secours', () => {
  assert.ok(finishStart > 0 && finishEnd > finishStart, 'bloc finishLogin trouvé');
  assert.ok(!finishBlock.includes('is_super_admin: true'),
    'aucune attribution is_super_admin: true dans finishLogin');
  assert.ok(!finishBlock.includes('branch_id: "bbbbbbbb'),
    'plus de profil synthétique avec branch arbitraire');
  assert.ok(!finishBlock.includes('role_id: "00000000-0000-0000-0000-000000000002"'),
    'plus de rôle de secours attribué');
  // Fichier entier : la seule valeur restante est un défaut à FALSE (refresh).
  assert.ok(!edge.includes('is_super_admin: true'),
    'aucune occurrence is_super_admin: true dans tout le fichier Edge');
});

test('finishLogin : décide via login_policy.ts et refuse en 403 avant session', () => {
  assert.match(finishBlock, /decideLoginProfile\(\{/,
    'délègue la décision à login_policy.ts');
  assert.match(finishBlock, /if \(!decision\.ok\)/, 'refus explicite');
  assert.match(finishBlock, /return json\(\s*\{ error: \{ code: decision\.code/, 'réponse d\'erreur maîtrisée');
  assert.match(finishBlock, /\},\s*403,\s*\);/, 'HTTP 403');
  assert.ok(
    finishBlock.indexOf('if (!decision.ok)') < finishBlock.indexOf('"user_sessions"'),
    'le refus précède toute insertion de session',
  );
  // Recherche id + email (comptes legacy) puis politique commune.
  assert.match(finishBlock, /\.eq\("id", sub\)/, 'profil par id Auth');
  assert.match(finishBlock, /\.ilike\("email", normalized\)/, 'profil par email (legacy)');
});

test('finishLogin : journalisation du refus sans donnée personnelle', () => {
  assert.match(finishBlock, /\[login\] refus profil \$\{decision\.code\}/,
    'log = code de refus seul');
  assert.ok(!/console\.(error|log)\([^)]*normalized/.test(finishBlock),
    'aucun email journalisé dans le bloc de refus');
});

/* ---------------- Source : garde __diag (§5) ---------------- */

test('__diag : superadmin vérifié côté serveur, plus settings:edit', () => {
  assert.ok(diagStart > 0, 'route __diag trouvée');
  assert.match(diagBlock, /requireSuperAdmin\(sb, req\)/, 'gate requireSuperAdmin');
  assert.ok(!/hasPermission\(\s*sb,\s*req,\s*"settings:edit"/.test(diagBlock),
    'settings:edit ne suffit plus pour __diag');
  const helperStart = edge.indexOf('async function requireSuperAdmin(');
  assert.ok(helperStart > 0, 'helper requireSuperAdmin présent');
  const helperBlock = edge.slice(helperStart, helperStart + 700);
  assert.match(helperBlock, /currentUserId\(req\)/, 'identité = JWT vérifié');
  assert.match(helperBlock, /is_super_admin === true/, 'flag base strict');
  assert.match(helperBlock, /u\.status !== "active"/, 'compte actif exigé');
});

/* ---------------- §2/§9 : rotation du mot de passe ---------------- */

test('version déploiement = 2.5.7', () => {
  assert.ok(edge.includes('EDGE_VERSION = "2.5.7"'),
    'bump 2.5.7 (route /branches : vraie table + PUT /users accepte branch_id → vente test débloquée)');
});

test('change-password : mot de passe actuel vérifié, sessions révoquées, audité', () => {
  const cpStart = edge.indexOf('path === "auth/change-password"');
  assert.ok(cpStart > 0, 'route auth/change-password trouvée');
  const cpBlock = edge.slice(cpStart, cpStart + 4500);
  // Le jeton seul ne suffit plus : il faut prouver le secret actuel.
  assert.match(cpBlock, /currentPassword/, 'currentPassword lu du corps');
  assert.match(cpBlock, /if \(!cur\)/, 'refus 400 sans currentPassword');
  assert.match(cpBlock, /signInWithPassword\(\{/, 'vérification réelle via Supabase Auth');
  assert.match(cpBlock, /INVALID_PASSWORD/, 'code de refus explicite');
  assert.match(cpBlock, /\},\s*401,\s*\);/, '401 si mdp actuel faux');
  assert.ok(cpBlock.indexOf('signInWithPassword') < cpBlock.indexOf('updateUserById'),
    'la vérification précède toute mise à jour');
  // Rotation : révocation applicative + sessions de rafraîchissement + audit.
  assert.match(cpBlock, /\.from\("user_sessions"\)\s*\.update\(\{\s*revoked_at:/,
    'sessions applicatives révoquées');
  assert.ok(cpBlock.indexOf('currentUserId(req)') > 0,
    'résolution de l\u0027id profil (user_sessions/audit_logs sont sur public.users.id)');
  assert.match(cpBlock, /\.eq\("user_id",\s*profileId \?\? userId\)/,
    'révocation par id profil (jamais le sub Auth)');
  assert.match(cpBlock, /performedBy:\s*profileId \?\? userId/,
    'audit rattaché à l\u0027id profil (FK public.users)');
  assert.match(cpBlock, /\/auth\/v1\/admin\/users\/\$\{userId\}\/sessions/,
    'sessions GoTrue supprimées (API admin)');
  assert.match(cpBlock, /method: "DELETE"/, 'méthode DELETE sur les sessions');
  assert.match(cpBlock, /user_password_changed/, 'audit de rotation');
  // Route NON publique : jamais sans session active.
  const pubStart = edge.indexOf('const PUBLIC_PATHS');
  const pubBlock = edge.slice(pubStart, pubStart + 160);
  assert.ok(!pubBlock.includes('change-password'),
    'change-password hors PUBLIC_PATHS (session active requise)');
  // Le front envoie déjà currentPassword (settings_page.dart) : pas de rupture.
  const front = readRel('../../frontend/lib/features/settings/settings_page.dart');
  assert.match(front, /'currentPassword': _cur\.text/,
    'front envoie bien currentPassword');
});
