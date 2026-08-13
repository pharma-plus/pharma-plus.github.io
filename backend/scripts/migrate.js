import 'dotenv/config';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import pg from 'pg';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const SCHEMA_DIR = path.resolve(__dirname, '../../database/schema');

const { Client } = pg;
const client = new Client({ connectionString: process.env.DATABASE_URL });
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
