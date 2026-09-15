// Active/renew la licence de la pharmacie demo (idempotent).
import 'dotenv/config';
import pg from 'pg';

const url = (process.env.DATABASE_URL || '').replace(/[?&]sslmode=[^&]*/g, '');
const p = new pg.Pool({ connectionString: url, ssl: { rejectUnauthorized: false } });
const PH = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
const MODULES = [
  'catalog', 'stock', 'sales', 'purchases', 'accounting', 'employees',
  'attendance', 'reports', 'ai', 'website', 'support', 'cameras',
  'prescriptions', 'customers', 'suppliers', 'sync', 'notifications', 'backups',
];

const upd = await p.query(
  `UPDATE licenses
      SET status = 'active',
          activation_date = now() - interval '30 days',
          expiry_date = now() + interval '2 years',
          updated_at = now()
    WHERE pharmacy_id = $1
  RETURNING id`,
  [PH],
);

if (upd.rowCount === 0) {
  await p.query(
    `INSERT INTO licenses
       (id, pharmacy_id, type, status, billing_cycle, activation_date, expiry_date,
        max_users, max_branches, modules)
     VALUES ('aaaaaaa0-0000-0000-0000-000000000001', $1, 'enterprise', 'active',
             'annual', now() - interval '30 days', now() + interval '2 years',
             50, 10, $2::jsonb)
     ON CONFLICT (id) DO NOTHING`,
    [PH, JSON.stringify(MODULES)],
  );
  console.log('Licence ENTERPRISE creee (active, 2 ans, 18 modules).');
} else {
  console.log(`Licence(s) reactives: ${upd.rowCount}.`);
}

const check = await p.query('SELECT type, status, expiry_date FROM licenses WHERE pharmacy_id = $1', [PH]);
console.log(JSON.stringify(check.rows, null, 1));
await p.end();
