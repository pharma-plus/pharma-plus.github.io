import { Client } from 'pg';
import dotenv from 'dotenv';
dotenv.config();

const raw = process.env.DATABASE_URL.replace(/[?&]sslmode=[^&]*/g, '');
const c = new Client({ connectionString: raw, ssl: { rejectUnauthorized: false } });
await c.connect();

// Ajout colonnes manquantes
await c.query(`ALTER TABLE public.employees ADD COLUMN IF NOT EXISTS cnss text`);
await c.query(`ALTER TABLE public.employees ADD COLUMN IF NOT EXISTS address text`);
console.log('Colonnes cnss/address ajoutées (ou déjà présentes)');

// Vérification
const cols = await c.query(
  `SELECT column_name FROM information_schema.columns WHERE table_name='employees'`
);
const names = cols.rows.map(r => r.column_name);
console.log('cnss:', names.includes('cnss') ? 'OK' : 'MANQUANT');
console.log('address:', names.includes('address') ? 'OK' : 'MANQUANT');
console.log('hire_date:', names.includes('hire_date') ? 'OK' : 'MANQUANT');

// Policies RLS
const pol = await c.query(
  `SELECT tablename, policyname, cmd, roles FROM pg_policies
   WHERE schemaname='public' AND tablename IN
   ('audit_logs','roles','role_permissions','permissions')
   ORDER BY tablename, policyname`
);
console.log('\n=== POLICIES RLS ===');
if (pol.rows.length === 0) {
  console.log('  AUCUNE POLICY — tables inaccessibles même avec RLS!');
} else {
  for (const p of pol.rows) {
    console.log(`  ${p.tablename}: ${p.policyname} (${p.cmd}) roles=${p.roles.join(',')}`);
  }
}

await c.end();
