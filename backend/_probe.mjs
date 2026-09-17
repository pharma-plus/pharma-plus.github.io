// Diagnostic temporaire : compte le contenu réel des tables PHARMA+ (lecture seule).
import pg from 'pg';
import 'dotenv/config';
const { Pool } = pg;
const pool = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });
const q = (s, p) => pool.query(s, p);
const pharm = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
for (const t of ['users','medications','suppliers','sales','sale_items','stock_balances','lots','reference_products','reference_categories','reference_sync_runs','licenses','branches','pharmacies','roles','role_permissions']) {
  const r = await q(`SELECT count(*)::int AS n FROM ${t}`);
  console.log('COUNT', t, '=', r.rows[0].n);
}
const lic = await q("SELECT id, status, activation_date, expiry_date, features FROM licenses WHERE pharmacy_id=$1", [pharm]);
console.log('LICENSES:', JSON.stringify(lic.rows));
const sa = await q("SELECT id, email, is_super_admin, role_id, status, must_change_password, two_factor_enabled, branch_id FROM users WHERE email='superadmin@pharmamarocgold.com'");
console.log('SUPERADMIN:', JSON.stringify(sa.rows));
const u = await q("SELECT id, email, is_super_admin, role_id, status, first_name, last_name, branch_id FROM users WHERE is_super_admin=false LIMIT 5");
console.log('USERS_NON_SA:', JSON.stringify(u.rows));
const perms = await q("SELECT DISTINCT rp.permission_code FROM role_permissions rp JOIN users u ON u.role_id=rp.role_id WHERE u.email='superadmin@pharmamarocgold.com'");
console.log('SA_PERMS:', JSON.stringify(perms.rows));
await pool.end();
