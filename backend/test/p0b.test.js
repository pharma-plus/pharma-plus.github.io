import { test, mock, before } from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

/* ---- Mock du pool SQL (aucune base réelle requise) ---- */

function handle(text) {
  if (/count\(\*\)::int AS total/i.test(text)) return { rowCount: 1, rows: [{ total: 0 }] };
  if (/count\(\*\)::int AS n/i.test(text)) return { rowCount: 1, rows: [{ n: 0 }] };
  if (/fn_next_number/i.test(text)) return { rowCount: 1, rows: [{ number: 'CAISSE-2026-000001' }] };
  return { rowCount: 0, rows: [] };
}

const fakeClient = () => ({ query: async (text) => handle(text), release: () => {} });
const poolMock = {
  query: (text) => handle(text),
  connect: async () => fakeClient(),
  on: () => {},
  end: async () => {},
};

mock.module(new URL('../src/db/pool.js', import.meta.url).href, {
  exports: {
    pool: poolMock,
    query: (text) => handle(text),
    withTenant: async (_id, fn) => fn(fakeClient()),
    withTransaction: async (_id, fn) => fn(fakeClient()),
  },
});

let app;
let cashSessionService;
let paymentsService;
let userSessionService;
let maintenanceService;

before(async () => {
  const { createApp } = await import('../src/app.js');
  app = createApp();
  ({ cashSessionService } = await import('../src/modules/cash-sessions/service.js'));
  ({ paymentsService } = await import('../src/modules/payments/service.js'));
  ({ userSessionService } = await import('../src/modules/user-sessions/service.js'));
  ({ maintenanceService } = await import('../src/modules/maintenance/service.js'));
});

/* ---- 1. Les 4 routers sont réellement branchés dans app.js ---- */

const MOUNTED = [
  '/api/v1/cash-sessions/open',
  '/api/v1/payments',
  '/api/v1/user-sessions',
  '/api/v1/maintenance/health-check',
];

for (const path of MOUNTED) {
  test(`route montée : ${path} rejette sans jeton (401 ≠ 404)`, async () => {
    const res = await request(app).get(path);
    assert.equal(res.status, 401, `attendu 401, reçu ${res.status} (${JSON.stringify(res.body)})`);
    assert.equal(res.body.error.code, 'UNAUTHORIZED');
  });
}

test('contrôle : une route non montée renvoie bien 404', async () => {
  const res = await request(app).get('/api/v1/cash-sessions-inexistant');
  assert.equal(res.status, 404);
  assert.equal(res.body.error.code, 'NOT_FOUND');
});

/* ---- 2. Contrats des services (exports attendus par les routers) ---- */

test('cashSessionService : pas de caisse ouverte → null (fermeture attendue par le POS)', async () => {
  const summary = await cashSessionService.getOpenSession('11111111-1111-1111-1111-111111111111');
  assert.equal(summary, null);
});

test('cashSessionService.getGlobalStats : totaux initialisés par statut', async () => {
  const stats = await cashSessionService.getGlobalStats('11111111-1111-1111-1111-111111111111');
  assert.equal(stats.open.status, 'OUVERTE');
  assert.equal(stats.open.sessions, 0);
  assert.equal(stats.closed.status, 'FERMEE');
  assert.ok(Array.isArray(stats.rows));
});

test('paymentsService.listPayments : pagination normalisée', async () => {
  const result = await paymentsService.listPayments('11111111-1111-1111-1111-111111111111', { page: 2, limit: 50 });
  assert.deepEqual(result.items, []);
  assert.equal(result.meta.total, 0);
  assert.equal(result.meta.page, 2);
  assert.equal(result.meta.limit, 50);
  assert.equal(result.meta.offset, 50);
});

test('userSessionService.getActiveSessions : liste vide sans session active', async () => {
  const rows = await userSessionService.getActiveSessions('11111111-1111-1111-1111-111111111111');
  assert.deepEqual(rows, []);
});

test('maintenanceService.healthCheck : santé instance sans données sensibles', async () => {
  const health = await maintenanceService.healthCheck('11111111-1111-1111-1111-111111111111');
  assert.equal(health.status, 'ok');
  assert.deepEqual(health.counts, {
    medications: 0, sales: 0, stockBalances: 0, users: 0, activeSessions: 0,
  });
  assert.equal(health.lastSale, null);
});

test('maintenanceService.resetDatabase : refuse sans confirmation « REINITIALISER »', async () => {
  const actor = { id: 'u1', isSuperAdmin: true, permissions: new Set() };
  await assert.rejects(
    () => maintenanceService.resetDatabase('11111111-1111-1111-1111-111111111111',
      { level: 'stock_zero', confirmation: 'non' }, actor),
    (err) => err.code === 'VALIDATION_ERROR',
  );
});

test('maintenanceService.resetDatabase : refuse un niveau non supporté (protection totale)', async () => {
  const actor = { id: 'u1', isSuperAdmin: true, permissions: new Set() };
  await assert.rejects(
    () => maintenanceService.resetDatabase('11111111-1111-1111-1111-111111111111',
      { level: 'full', confirmation: 'REINITIALISER' }, actor),
    (err) => err.code === 'VALIDATION_ERROR' && /intervention manuelle/.test(err.details[0].message),
  );
});

/* ---- 3. Contrôles d'accès : uniquement des permissions réelles du catalogue ---- */

function permissionCatalog() {
  const root = fileURLToPath(new URL('../../database/', import.meta.url));
  const codes = new Set();
  for (const rel of ['seeds/001_security.sql', 'schema/015_extensions.sql']) {
    const txt = readFileSync(`${root}${rel}`, 'utf8');
    const arrays = [...txt.matchAll(/ARRAY\[([^\]]+)\]/g)]
      .map((m) => [...m[1].matchAll(/'([^']+)'/g)].map((x) => x[1]));
    assert.ok(arrays.length >= 2, `catalogue illisible dans ${rel}`);
    const [modules, actions] = arrays;
    for (const m of modules) for (const a of actions) codes.add(`${m}:${a}`);
  }
  return codes;
}

test('routers P0-B-6 : aucune permission inexistante dans le catalogue', () => {
  const codes = permissionCatalog();
  const routers = ['cash-sessions', 'payments', 'user-sessions', 'maintenance'];
  for (const name of routers) {
    const file = fileURLToPath(new URL(`../src/modules/${name}/index.js`, import.meta.url));
    const used = [...readFileSync(file, 'utf8').matchAll(/requirePerm\('([^']+)'\)/g)].map((m) => m[1]);
    assert.ok(used.length > 0, `${name} : aucune permission requise`);
    for (const perm of used) {
      assert.ok(codes.has(perm), `${name} : permission inexistante « ${perm} »`);
    }
  }
});

/* ---- 4. P0-B-3 : retours de vente (portage Express <-> SQL) ---- */

const PH = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const SALE = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const BRANCH = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const MED = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';

test('P0-B-3 : route POST /sales/returns montée (401 sans jeton, pas 404)', async () => {
  const res = await request(app).post('/api/v1/sales/returns');
  assert.equal(res.status, 401, `attendu 401, reçu ${res.status}`);
  assert.equal(res.body.error.code, 'UNAUTHORIZED');
});

test('P0-B-3 : returnSale refuse un article en double (DUPLICATE_ITEM)', async () => {
  const { salesService } = await import('../src/modules/sales/service.js');
  await assert.rejects(
    () => salesService.returnSale(PH, {
      saleId: SALE, branchId: BRANCH,
      items: [{ medication_id: MED, quantity: 1 }, { medication_id: MED, quantity: 2 }],
    }, { id: 'user-1' }),
    (err) => err.code === 'DUPLICATE_ITEM' && err.status === 409,
  );
});

test('P0-B-3 : returnSale sur vente inconnue -> 404 (pool mocké sans ligne)', async () => {
  const { salesService } = await import('../src/modules/sales/service.js');
  await assert.rejects(
    () => salesService.returnSale(PH, {
      saleId: SALE, branchId: BRANCH,
      items: [{ medication_id: MED, quantity: 1 }],
    }, { id: 'user-1' }),
    (err) => err.code === 'NOT_FOUND' && err.status === 404,
  );
});

test('P0-B-3 : le portage SQL fn_sale_return couvre la même chaîne que returnSale', () => {
  const root = fileURLToPath(new URL('../../database/', import.meta.url));
  const sql = readFileSync(`${root}schema/014_sale_return.sql`, 'utf8');
  for (const marker of [
    'INSERT INTO sale_returns',
    'INSERT INTO sale_return_items',
    "movement_type, quantity",
    "'sale_return'",
    "status = 'returned'",
    'INSERT INTO invoices',
    "'avoir'",
    'credit_balance',
    'INSERT INTO audit_logs',
    'HINT = \'DUPLICATE_ITEM\'',
    'HINT = \'INVALID_RETURN_QTY\'',
    'HINT = \'ALREADY_RETURNED\'',
  ]) {
    assert.ok(sql.includes(marker), `fn_sale_return : étape manquante ${marker}`);
  }
});

test('P0-B-3 : l\'alignement de base (950_live_compat) couvre ventes et sauvegardes', () => {
  const root = fileURLToPath(new URL('../../database/', import.meta.url));
  const sql = readFileSync(`${root}schema/950_live_compat.sql`, 'utf8');
  assert.match(sql, /ALTER TABLE sales ADD COLUMN IF NOT EXISTS payments/);
  assert.match(sql, /ALTER TABLE backups ADD COLUMN IF NOT EXISTS checksum/);
  for (const marker of ["'pos'", "'returned'", "'manual'", "'verified'", "'inactive'", "'critical'"]) {
    assert.ok(sql.includes(marker), `950_live_compat : valeur du dépôt non alignée ${marker}`);
  }
});
