import 'dotenv/config';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import pg from 'pg';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const SCHEMA_DIR = path.resolve(__dirname, '../../database/schema');

const { Client } = pg;

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

const files = (await fs.readdir(SCHEMA_DIR))
  .filter((f) => f.endsWith('.sql'))
  .sort();

for (const file of files) {
  const content = await fs.readFile(path.join(SCHEMA_DIR, file), 'utf8');
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

await client.end();
console.log(`\nMigration terminée : ${files.length} fichiers appliqués.`);
