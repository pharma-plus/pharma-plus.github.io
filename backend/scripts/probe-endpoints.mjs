// Sonde tous les endpoints GET utilises par le frontend avec une session
// PHARMACIE (meme mecanique que login : session + JWT signe). Usage local.
import 'dotenv/config';
import crypto from 'node:crypto';
import pg from 'pg';
import jwt from 'jsonwebtoken';

const BASE = 'http://127.0.0.1:4000/api/v1';
const EMAIL = 'admin@pharma.ma';
const sha256 = (s) => crypto.createHash('sha256').update(s).digest('hex');

const url = (process.env.DATABASE_URL || '').replace(/[?&]sslmode=[^&]*/g, '');
const pool = new pg.Pool({ connectionString: url, ssl: { rejectUnauthorized: false } });

const { rows } = await pool.query('SELECT * FROM users WHERE email = $1', [EMAIL]);
if (rows.length === 0) throw new Error(`Utilisateur ${EMAIL} introuvable`);
const user = rows[0];

// --- Session de sonde (expire dans 1 h)
const sessionId = crypto.randomUUID();
const tokenId = crypto.randomBytes(32).toString('hex');
const refresh = crypto.randomBytes(48).toString('hex');
await pool.query(
  `INSERT INTO user_sessions
     (id, user_id, pharmacy_id, access_token_hash, refresh_token_hash,
      device_name, device_type, user_agent, expires_at)
   VALUES ($1,$2,$3,$4,$5,'probe','web','probe.mjs', now() + interval '1 hour')`,
  [sessionId, user.id, user.pharmacy_id, sha256(tokenId), sha256(refresh)],
);
const token = jwt.sign(
  { sub: user.id, sid: sessionId, tkh: tokenId, pharmacyId: user.pharmacy_id, isSuperAdmin: user.is_super_admin },
  process.env.JWT_SECRET,
  { issuer: 'pharma-maroc-gold', expiresIn: '1h' },
);

const get = async (path) => {
  const res = await fetch(`${BASE}${path}`, { headers: { Authorization: `Bearer ${token}` } });
  let body = '';
  try { body = (await res.text()).slice(0, 180); } catch { /* noop */ }
  return { path, status: res.status, body };
};

const staticPaths = [
  '/auth/me',
  '/branches',
  '/roles?limit=50',
  '/users?limit=5',
  '/catalog/medications?limit=5',
  '/catalog/medications?limit=5&is_parapharmacie=true',
  '/catalog/categories',
  '/stock/alerts',
  
  '/suppliers?limit=5',
  '/customers?limit=5',
  '/employees?limit=5',
  '/employees/summary',
  '/attendance',
  '/attendance/leaves',
  '/attendance/summary',
  '/purchases/orders?limit=5',
  '/purchases/receptions?limit=5',
  '/sales?limit=5',
  '/prescriptions?limit=5',
  '/dashboard/overview',
  '/reports/financial?from=2026-08-15&to=2026-09-14',
  '/reports/stock',
  '/accounting/expenses',
  '/accounting/journal',
  
  '/notifications',
  '/audit?limit=10',
  '/pharmacies/me',
  '/pharmacies?limit=5',
  '/pharmacies/global-stats',
  '/website/settings',
  
  '/ai/insights',
  '/ai/reorder-plan',
  '/ai/sales-analysis',
  '/reference/sync/status',
  '/support?limit=5',
  
  
];

const results = [];
for (const p of staticPaths) {
  try { results.push(await get(p)); } catch (e) { results.push({ path: p, status: 'ERR', body: e.message }); }
}

// --- Details avec un id reel
const firstId = async (table) => {
  const r = await pool.query(`SELECT id FROM ${table} WHERE pharmacy_id = $1 LIMIT 1`, [user.pharmacy_id]);
  return r.rows[0]?.id ?? null;
};
const detailProbes = [
  ['/suppliers/%ID', 'suppliers'],
  ['/customers/%ID', 'customers'],
  ['/employees/%ID', 'employees'],
  ['/purchases/orders/%ID', 'purchase_orders'],
  ['/prescriptions/%ID', 'prescriptions'],
];
for (const [tpl, table] of detailProbes) {
  try {
    const id = await firstId(table);
    results.push(id ? await get(tpl.replace('%ID', id)) : { path: tpl, status: 'SKIP', body: `aucune ligne dans ${table}` });
  } catch (e) { results.push({ path: tpl, status: 'ERR', body: e.message }); }
}

// --- Nettoyage session + resume
await pool.query('DELETE FROM user_sessions WHERE id = $1', [sessionId]);
await pool.end();

const bad = results.filter((r) => ![200, 201, 204].includes(r.status) && r.status !== 'SKIP');
console.log(`\n=== ${results.length} endpoints sondes | OK: ${results.length - bad.length} | KO: ${bad.length} ===`);
for (const r of results.filter((r) => [200, 201, 204].includes(r.status) || r.status === 'SKIP')) {
  console.log(`  [${r.status}] ${r.path}`);
}
console.log('');
for (const r of bad) {
  console.log(`  [${r.status}] ${r.path}\n         ${String(r.body).replace(/\s+/g, ' ').slice(0, 170)}`);
}

