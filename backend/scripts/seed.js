import 'dotenv/config';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import argon2 from 'argon2';
import pg from 'pg';
import { config } from '../src/config/index.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const SEED_DIR = path.resolve(__dirname, '../../database/seeds');
const DEMO_PHARMACY = '11111111-1111-1111-1111-111111111111';
const DEMO_BRANCH = '22222222-2222-2222-2222-222222222222';
const DEMO_USER_ID = '99999999-9999-9999-9999-999999999999';
const SUPER_ADMIN_ROLE_ID = '00000000-0000-0000-0000-000000000001';
const SUPER_ADMIN_USER_ID = '00000000-0000-0000-0000-0000000000aa';

const { Client } = pg;
const client = new Client({ connectionString: process.env.DATABASE_URL });
await client.connect();

// 1. Seeds SQL
const files = (await fs.readdir(SEED_DIR)).filter((f) => f.endsWith('.sql')).sort();
for (const file of files) {
  const content = await fs.readFile(path.join(SEED_DIR, file), 'utf8');
  process.stdout.write(`▶ ${file} ... `);
  try {
    await client.query('BEGIN');
    await client.query(content);
    await client.query('COMMIT');
    process.stdout.write('OK\n');
  } catch (err) {
    await client.query('ROLLBACK');
    console.error(`\nÉCHEC sur ${file} :\n${err.message}`);
    process.exit(1);
  }
}

// 2. Super administrateur global (identifiants issus du .env)
const superEmail = config.superAdmin.email;
const superAdmin = await client.query(
  'SELECT id FROM users WHERE lower(email) = lower($1)', [superEmail],
);
if (superAdmin.rowCount === 0) {
  const passwordHash = await argon2.hash(config.superAdmin.password, { type: argon2.argon2id });
  await client.query(
    `INSERT INTO users (id, pharmacy_id, branch_id, role_id, first_name, last_name,
                        email, phone, password_hash, is_super_admin,
                        must_change_password, two_factor_enabled)
     VALUES ($1,NULL,NULL,$2,'Super','Admin',$3,NULL,$4,true,false,false)
     ON CONFLICT (email) DO NOTHING`,
    [SUPER_ADMIN_USER_ID, SUPER_ADMIN_ROLE_ID, superEmail, passwordHash],
  );
  process.stdout.write(`▶ super admin ${superEmail} ... OK\n`);
} else {
  process.stdout.write(`▶ super admin ${superEmail} déjà présent (ignoré)\n`);
}

// 3. Compte de démonstration (mot de passe : Demo123!)
const email = 'admin@demo.ma';
const existing = await client.query('SELECT id FROM users WHERE lower(email) = lower($1)', [email]);
if (existing.rowCount === 0) {
  const passwordHash = await argon2.hash('Demo123!', { type: argon2.argon2id });
  const { rows: roleRows } = await client.query(
    'SELECT id FROM roles WHERE pharmacy_id = $1 AND code = $2',
    [DEMO_PHARMACY, 'pharmacy_admin'],
  );
  if (!roleRows[0]) {
    console.error('\nÉCHEC : rôle pharmacy_admin introuvable pour la pharmacie de démo');
    process.exit(1);
  }
  await client.query(
    `INSERT INTO users (id, pharmacy_id, branch_id, role_id, first_name, last_name,
                        email, phone, password_hash, must_change_password, two_factor_enabled)
     VALUES ($1,$2,$3,$4,'Amine','El Alami',$5,'+212 6 60 00 00 00',$6,false,false)
     ON CONFLICT (email) DO NOTHING`,
    [DEMO_USER_ID, DEMO_PHARMACY, DEMO_BRANCH, roleRows[0].id, email, passwordHash],
  );
  process.stdout.write('▶ utilisateur admin@demo.ma / Demo123! ... OK\n');
} else {
  process.stdout.write('▶ utilisateur admin@demo.ma déjà présent (ignoré)\n');
}

await client.end();
console.log('Seed terminé.');
