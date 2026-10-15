import { Client } from 'pg';
import dotenv from 'dotenv';
dotenv.config();

const raw = process.env.DATABASE_URL.replace(/[?&]sslmode=[^&]*/g, '');
const c = new Client({ connectionString: raw, ssl: { rejectUnauthorized: false } });
await c.connect();

// 1. Colonnes employees
const cols = await c.query(
  `SELECT column_name, data_type FROM information_schema.columns
   WHERE table_name='employees' ORDER BY ordinal_position`
);
console.log('=== COLONNES employees ===');
console.log(cols.rows.map(r => `  ${r.column_name}: ${r.data_type}`).join('\n'));
const names = cols.rows.map(r => r.column_name);
for (const need of ['cnss', 'address', 'hire_date']) {
  console.log(`${need}: ${names.includes(need) ? 'EXISTE' : 'ABSENTE'}`);
}

// 2. Route PUT users/:id/pin dans Edge
// (vérifié côté code, pas ici)

// 3. RLS sur audit_logs, roles, role_permissions
const rls = await c.query(
  `SELECT relname, relrowsecurity FROM pg_class
   WHERE relname IN ('audit_logs','roles','role_permissions','permissions')`
);
console.log('\n=== RLS ===');
for (const r of rls.rows) {
  console.log(`  ${r.relname}: ${r.relrowsecurity ? 'RLS ACTIVE' : 'SANS RLS'}`);
}

await c.end();
