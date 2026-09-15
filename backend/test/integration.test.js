import { test, mock, before } from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import argon2 from 'argon2';

let passwordHash;

const fakeClient = () => ({
  query: async (text, params) => handle(text, params),
  release: () => {},
});

function handle(text, params) {
  if (/INSERT INTO user_sessions/i.test(text)) return { rowCount: 1, rows: [{ id: params?.[0] }] };
  if (/INSERT INTO audit_logs/i.test(text)) return { rowCount: 1, rows: [] };
  if (/UPDATE user_sessions/i.test(text)) return { rowCount: 1, rows: [] };
  if (/SELECT u\.\*, r\.code/i.test(text)) {
    return {
      rowCount: 1,
      rows: [{
        id: '00000000-0000-0000-0000-00000000000a',
        pharmacy_id: '11111111-1111-1111-1111-111111111111',
        branch_id: null,
        role_id: '00000000-0000-0000-0000-000000000002',
        email: 'admin@demo.ma',
        first_name: 'Admin',
        last_name: 'Demo',
        password_hash: passwordHash,
        status: 'active',
        two_factor_enabled: false,
        is_super_admin: false,
        role_code: 'pharmacy_admin',
        role_name: 'Pharmacien Administrateur',
        pharmacy_name: 'Pharmacie Demo',
        pharmacy_slug: 'pharmacie-demo',
        pharmacy_status: 'active',
      }],
    };
  }
  if (/UPDATE users SET failed_attempts/i.test(text)) return { rowCount: 1, rows: [] };
  if (/UPDATE users SET last_login_at/i.test(text)) return { rowCount: 1, rows: [] };
  if (/UPDATE users SET failed_attempts = 0/i.test(text)) return { rowCount: 1, rows: [] };
  return { rowCount: 0, rows: [] };
}

const poolMock = {
  query: (text, params) => handle(text, params),
  connect: async () => fakeClient(),
  on: () => {},
  end: async () => {},
};

mock.module(new URL('../src/db/pool.js', import.meta.url).href, {
  exports: {
    pool: poolMock,
    query: (text, params) => handle(text, params),
    withTenant: async (pharmacyId, fn) => fn(fakeClient()),
    withTransaction: async (pharmacyId, fn) => fn(fakeClient()),
  },
});

let app;

before(async () => {
  passwordHash = await argon2.hash('password123', { type: argon2.argon2id });
  const { createApp } = await import('../src/app.js');
  app = createApp();
});

test('GET /api/v1/health répond (même sans base réelle)', async () => {
  const res = await request(app).get('/api/v1/health');
  assert.ok([200, 503].includes(res.status));
  assert.equal(res.body.version, '2.0.0');
});

test('404 sur route inconnue', async () => {
  const res = await request(app).get('/api/v1/nonexistent');
  assert.equal(res.status, 404);
  assert.equal(res.body.error.code, 'NOT_FOUND');
});

test('POST /auth/login : succès avec identifiants valides', async () => {
  const res = await request(app)
    .post('/api/v1/auth/login')
    .send({ email: 'admin@demo.ma', password: 'password123', device: { name: 'Test' } });
  assert.equal(res.status, 200);
  assert.equal(res.body.success, true);
  assert.ok(res.body.data.accessToken);
  assert.ok(res.body.data.refreshToken);
  assert.equal(res.body.data.user.email, 'admin@demo.ma');
  assert.equal(res.body.data.user.password_hash, undefined);
});

test('POST /auth/login : refus pour mauvais mot de passe', async () => {
  const res = await request(app)
    .post('/api/v1/auth/login')
    .send({ email: 'admin@demo.ma', password: 'mauvais-mot-de-passe' });
  assert.equal(res.status, 401);
  assert.equal(res.body.success, false);
});

test('POST /auth/login : validation des champs requis', async () => {
  const res = await request(app)
    .post('/api/v1/auth/login')
    .send({ email: 'pas-un-email' });
  assert.equal(res.status, 422);
  assert.equal(res.body.error.code, 'VALIDATION_ERROR');
  assert.ok(Array.isArray(res.body.error.details));
});
