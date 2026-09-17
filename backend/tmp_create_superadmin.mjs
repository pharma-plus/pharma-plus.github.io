// Crée ou répare le super admin global (identifiants du .env), idempotent.
import pg from 'pg';
import argon2 from 'argon2';
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

const email = process.env.SUPER_ADMIN_EMAIL ?? 'admin@pharmamarocgold.com';
const password = process.env.SUPER_ADMIN_PASSWORD ?? 'ChangeMe_123!';
const roleId = '00000000-0000-0000-0000-000000000001'; // super_admin (global)
const userId = '00000000-0000-0000-0000-0000000000aa';

const passwordHash = await argon2.hash(password, { type: argon2.argon2id });

const res = await client.query(
  `INSERT INTO users (id, pharmacy_id, branch_id, role_id, first_name, last_name,
                      email, username, phone, password_hash, is_super_admin,
                      must_change_password, two_factor_enabled)
   VALUES ($1,NULL,NULL,$2,'Super','Admin',$3,'superadmin',NULL,$4,true,false,false)
   ON CONFLICT (email) DO UPDATE
     SET password_hash = EXCLUDED.password_hash,
         is_super_admin = true,
         role_id = EXCLUDED.role_id,
         must_change_password = false,
         two_factor_enabled = false
   RETURNING id, email, username`,
  [userId, roleId, email, passwordHash],
);
console.log('SUPER ADMIN OK:', JSON.stringify(res.rows[0]));
await client.end();
