// Verification rapide : utilisateurs, pharmacies, donnees metier.
import 'dotenv/config';
import pg from 'pg';

const url = (process.env.DATABASE_URL || '').replace(/[?&]sslmode=[^&]*/g, '');
const p = new pg.Pool({ connectionString: url, ssl: { rejectUnauthorized: false } });
try {
  const u = await p.query('SELECT email, is_super_admin, pharmacy_id, status FROM users ORDER BY created_at LIMIT 10');
  console.log('USERS:', JSON.stringify(u.rows, null, 1));
  const ph = await p.query('SELECT id, name, slug, status FROM pharmacies LIMIT 5');
  console.log('PHARMACIES:', JSON.stringify(ph.rows, null, 1));
  const m = await p.query('SELECT pharmacy_id, count(*)::int AS n FROM medications GROUP BY pharmacy_id');
  console.log('MEDS:', JSON.stringify(m.rows));
  const s = await p.query('SELECT pharmacy_id, count(*)::int AS n FROM suppliers GROUP BY pharmacy_id');
  console.log('SUPPLIERS:', JSON.stringify(s.rows));
  const sa = await p.query('SELECT pharmacy_id, count(*)::int AS n FROM sales GROUP BY pharmacy_id');
  console.log('SALES:', JSON.stringify(sa.rows));
} finally {
  await p.end();
}
