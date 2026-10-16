import 'dotenv/config';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import argon2 from 'argon2';
import pg from 'pg';
import { requireOpsConfirm } from './test_env.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const SEED_DIR = path.resolve(__dirname, '../../database/seeds');
const DEMO_PHARMACY = '11111111-1111-1111-1111-111111111111';
const DEMO_BRANCH = '22222222-2222-2222-2222-222222222222';
const DEMO_USER_ID = '99999999-9999-9999-9999-999999999999';

const { Client } = pg;

// Garde obligatoire (prompt sécurité §4) : sur une cible Supabase (prod OU
// test), confirmation explicite du projet requis avant toute écriture. Cible
// non-Supabase (Postgres Render/local dédié) : aucune création superadmin et
// compte démo conditionné — pas de privilège à rétablir.
const dbUrlRaw = process.env.DATABASE_URL ?? '';
if (/supabase\.(?:co|com)/i.test(dbUrlRaw)) {
  requireOpsConfirm(dbUrlRaw, { script: 'scripts/seed.js' });
} else {
  console.log('▶ seed : cible non-Supabase — confirmation projet non applicable (aucune création superadmin)');
}

// Cloud (Supabase, RDS…) : SSL requis. `sslmode=require` dans l'URL écraserait
// l'option ssl explicite (pg récent le traite comme verify-full, or la chaîne
// CA du pooler n'est pas fournie) => on le retire et on passe l'option à la main.
const rawUrl = process.env.DATABASE_URL ?? '';
const useSsl = /(sslmode=require|supabase|amazonaws|\.rds\.)/i.test(rawUrl);
let connectionString = rawUrl;
if (useSsl) {
  const u = new URL(rawUrl);
  u.searchParams.delete('sslmode');
  connectionString = u.toString();
}
const client = new Client({
  connectionString,
  ssl: useSsl ? { rejectUnauthorized: false } : undefined,
});
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

// 2. Super administrateur : PLUS DE CRÉATION PAR LE SEED (prompt sécurité §4).
//    Aucun identifiant par défaut : le compte superadmin est géré par la
//    procédure contrôlée scripts/superadmin_reconcile.mjs (env + confirmation
//    explicite, aucun secret codé en dur).
console.log('▶ superadmin : création seed retirée (procédure contrôlée uniquement)');

// 3. Compte de démonstration — mot de passe EXPLICITE via SEED_DEMO_PASSWORD
//    (aucun mot de passe par défaut : si l'variable est absente, le compte
//    n'est pas créé).
const demoPassword = process.env.SEED_DEMO_PASSWORD || '';
if (!demoPassword) {
  console.log('▶ compte démo : SEED_DEMO_PASSWORD absente — création ignorée (pas de secret par défaut)');
} else if (demoPassword.length < 8) {
  console.error('\nÉCHEC : SEED_DEMO_PASSWORD trop courte (8 caractères minimum)');
  process.exit(1);
} else {
  const email = 'admin@demo.ma';
  const existing = await client.query('SELECT id FROM users WHERE lower(email) = lower($1)', [email]);
  if (existing.rowCount === 0) {
    const passwordHash = await argon2.hash(demoPassword, { type: argon2.argon2id });
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
                          email, username, phone, password_hash, must_change_password, two_factor_enabled)
       VALUES ($1,$2,$3,$4,'Amine','El Alami',$5,'admin','+212 6 60 00 00 00',$6,false,false)
       ON CONFLICT (email) DO NOTHING`,
      [DEMO_USER_ID, DEMO_PHARMACY, DEMO_BRANCH, roleRows[0].id, email, passwordHash],
    );
    console.log('▶ utilisateur admin@demo.ma créé (mot de passe fourni par SEED_DEMO_PASSWORD) ... OK');
  } else {
    console.log('▶ utilisateur admin@demo.ma déjà présent (ignoré)');
  }
}

await client.end();
console.log('Seed terminé.');
