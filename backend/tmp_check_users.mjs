// Lecture seule : inspecte pharmacies + roles.
import pg from 'pg';
import 'dotenv/config';

const rawUrl = process.env.DATABASE_URL ?? '';
const useSsl = /(sslmode=require|supabase|amazonaws|\.rds\.)/i.test(rawUrl);
let connectionString = rawUrl;
if (useSsl) {
  const u = new URL(rawUrl);
  u.searchParams.delete('sslmode');
  connectionString = u.toString();
}
const client = new pg.Client({
  connectionString,
  ssl: useSsl ? { rejectUnauthorized: false } : undefined,
});
await client.connect();

const tables = await client.query(
  `SELECT table_name FROM information_schema.tables WHERE table_schema='public' ORDER BY table_name`,
);
console.log('=== TABLES ===');
console.log(tables.rows.map((r) => r.table_name).join(', '));

const ph = await client.query('SELECT id, name FROM pharmacies ORDER BY name');
console.log('=== PHARMACIES ===', ph.rowCount);
for (const r of ph.rows) console.log(JSON.stringify(r));

const ro = await client.query('SELECT id, pharmacy_id, code, name FROM roles ORDER BY pharmacy_id, code');
console.log('=== ROLES ===', ro.rowCount);
for (const r of ro.rows) console.log(JSON.stringify(r));

await client.end();

