import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

/**
 * P7 — Contrat de schéma des endpoints Super Admin CRM (partie D).
 *
 * La table réelle (source de vérité) ne contient PAS les colonnes que
 * la fonction Edge écrivait ou lisait :
 *   - pharmacies : pas de license_type / license_expiry (→ table licenses) ;
 *   - invoices : pas de "amount" (subtotal / tax_total / total),
 *     branch_id NOT NULL ;
 *   - roles : pas de description ;
 *   - role_permissions : (role_id, permission_code), pas module/action.
 *
 * Objectif : le GET /superadmin/pharmacies doit OBTENIR des données (la
 * pharmacie de test doit apparaître dans la liste CRM) et chaque action
 * (créer / permissions) doit viser des colonnes réelles.
 *
 * Test statique de contrat — aucun appel réseau, aucune donnée réelle.
 */

const edge = readFileSync(
  fileURLToPath(new URL('../../supabase/functions/pharma-api/index.ts', import.meta.url)),
  'utf8',
);

// Ancres sur les HANDLERS (path === "…"), pas sur le tableau superadminPaths.
const blockAfter = (anchor, nextAnchor) => {
  const start = edge.indexOf(anchor);
  assert.ok(start > 0, `bloc introuvable : ${anchor}`);
  const end = nextAnchor ? edge.indexOf(nextAnchor, start) : edge.length;
  assert.ok(end > start, `fin introuvable après ${anchor}`);
  return edge.slice(start, end);
};

const pharmacies = blockAfter('path === "superadmin/pharmacies"', 'path === "superadmin/prospects"');
const invoices = blockAfter('path === "superadmin/invoices"', 'path === "superadmin/tickets"');
const tickets = blockAfter('path === "superadmin/tickets"', 'path === "superadmin/roles"');
const roles = blockAfter('path === "superadmin/roles"', 'ROOT');

const getPart = (block) => block.slice(0, block.indexOf('req.method === "POST"'));
const postPart = (block) => block.slice(block.indexOf('req.method === "POST"'));

test('pharmacies GET : aucun select de colonne inexistante + enrichissement licences réel', () => {
  const g = getPart(pharmacies);
  // Le SELECT réel (chaîne passée à .select()) ne cite plus license_type
  const sel = g.match(/\.select\(\s*[\s\S]*?"\)\)?\)?/)?.[0] ?? '';
  assert.equal(/license_type/.test(sel), false, 'license_type ne doit plus être sélectionné sur pharmacies');
  assert.equal(/license_expiry/.test(sel), false);
  assert.match(g, /\.from\("licenses"\)/);
  assert.match(g, /license_type:\s*licMap\.get\(p\.id\)\?\.type/);
});

test('pharmacies POST : insert sans colonne inexistante (license_type)', () => {
  const p = postPart(pharmacies);
  const insertPayload = p.match(/insert\(\{[\s\S]*?\}\)\.select/)?.[0] ?? '';
  assert.ok(insertPayload.length > 10, 'payload insert introuvable');
  assert.equal(/license_type/.test(insertPayload), false);
  assert.match(p, /status:\s*"active"/);
});

test('invoices GET : mapping compat pharmacy_name + amount (= total)', () => {
  const g = getPart(invoices);
  assert.match(g, /pharmacy_name:\s*r\.pharmacies\?\.name/);
  assert.match(g, /amount:\s*r\.total/);
});

test('invoices POST : insert colonnes réelles (total, branch_id, pas de clé "amount:")', () => {
  const p = postPart(invoices);
  assert.match(p, /branch_id:\s*branchId/);
  assert.match(p, /total:\s*amount/);
  assert.doesNotMatch(p.replace(/total:\s*amount/g, ''), /amount\s*:/);
});

test('tickets GET : mapping compat pharmacy_name', () => {
  const g = getPart(tickets);
  assert.match(g, /pharmacy_name:\s*r\.pharmacies\?\.name/);
});

test('roles GET : permissions mappées depuis role_permissions(permission_code) réel', () => {
  assert.match(roles, /role_permissions\(permission_code\)/);
  assert.match(roles, /permMap/);
});

test('roles POST/PUT : aucune écriture d\'une colonne description inexistante', () => {
  const insertPart = roles.slice(roles.indexOf('.from("roles").insert'));
  assert.ok(!/\bdescription\s*[,}]|\bdescription\s*:/.test(insertPart),
    'l\'insert roles ne doit pas contenir de description');
  assert.ok(!/updateData\.description/.test(roles),
    'l\'update roles ne doit pas contenir de description');
});

test('roles permissions PUT : insert en colonnes réelles (permission_code "module:action", pas module/action)', () => {
  assert.match(roles, /permission_code:\s*`\$\{module\}:\$\{action\}`/);
  // L'ancien payload objet { role_id, module, action } n'a plus de clé
  // "module" (la déstructure flatMap ([module, actions]) est légitime).
  assert.ok(!/^\s+module,\s*$/m.test(roles), 'l\'insert ne doit plus contenir la clé "module"');
  assert.ok(!/^\s+action,\s*$/m.test(roles), 'l\'insert ne doit plus contenir la clé "action"');
});

/* Contrats frontend cohérents avec le schéma réel */

const crm = readFileSync(
  fileURLToPath(new URL('../../frontend/lib/features/super_admin/super_admin_crm_page.dart', import.meta.url)),
  'utf8',
);
const rolePage = readFileSync(
  fileURLToPath(new URL('../../frontend/lib/features/super_admin/role_management_page.dart', import.meta.url)),
  'utf8',
);

test('frontend : formulaire pharmacie sans champ license_type non persistable', () => {
  const phStart = crm.indexOf('class _PharmacyForm');
  const phEnd = crm.indexOf('class _ProspectForm');
  assert.ok(!/license_type|_licenseType/.test(crm.slice(phStart, phEnd)));
});

test('frontend : formulaire rôle sans champ description non persistable', () => {
  const rfStart = rolePage.indexOf('class _RoleFormState');
  const rfEnd = rolePage.indexOf('class PermissionMatrixDialog');
  assert.ok(!/_description/.test(rolePage.slice(rfStart, rfEnd)));
});

test('frontend : un seul bouton Créer à l\'écran (pas de doublon FAB/EmptyState)', () => {
  const esStart = crm.indexOf('class _EmptyState');
  const esEnd = crm.indexOf('// Forms');
  const es = crm.slice(esStart, esEnd);
  assert.ok(!/onPressed:\s*onAdd/.test(es), 'pas de bouton Créer dans l\'état vide (doublon du FAB)');
});

test('frontend : onglet Rôles = module complet (RoleManagementBody), pas de dialogue vide', () => {
  assert.match(crm, /_activeTab == 'roles'/);
  assert.match(crm, /RoleManagementBody\(\)/);
  const dlg = crm.indexOf('void _showCreateDialog');
  assert.match(crm.slice(dlg, dlg + 400), /_fetchListForTab/,
    'création refusée pour les onglets sans formulaire (jamais de dialogue vide)');
});

test('frontend : vue Analytics toujours affichée (stats réelles), jamais l\'état vide erroné', () => {
  const bodyStart = crm.indexOf('Expanded(', crm.indexOf('Widget build(BuildContext context)'));
  const branch = crm.slice(bodyStart, bodyStart + 2600);
  assert.match(branch, /_activeTab == 'analytics'/);
  assert.match(branch, /_buildAnalytics\(locale\)/);
});
