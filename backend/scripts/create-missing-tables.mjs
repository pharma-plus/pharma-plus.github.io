// Cree les tables du schema manquantes en base (ordre des fichiers schema).
import 'dotenv/config';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import pg from 'pg';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const SCHEMA_DIR = path.resolve(__dirname, '../../database/schema');

const url = (process.env.DATABASE_URL || '').replace(/[?&]sslmode=[^&]*/g, '');
const client = new pg.Client({ connectionString: url, ssl: { rejectUnauthorized: false } });
await client.connect();

// Tables declarees dans le schema + blocs SQL de creation (par fichier, ordre d'apparition)
const blocks = []; // { table, sql, file }
for (const f of fs.readdirSync(SCHEMA_DIR).filter((x) => x.endsWith('.sql')).sort()) {
  const txt = fs.readFileSync(path.join(SCHEMA_DIR, f), 'utf8');
  const re = /CREATE TABLE (?:IF NOT EXISTS )?([a-zA-Z_][\w]*)\s*\(([\s\S]*?)\n\)/g;
  let m;
  while ((m = re.exec(txt))) {
    blocks.push({
      table: m[1].toLowerCase(),
      sql: `${m[0]};`,
      file: f,
    });
  }
}

// Tables reelles
const { rows } = await client.query(
  `SELECT table_name FROM information_schema.tables
    WHERE table_schema = 'public' AND table_type = 'BASE TABLE'`,
);
const dbTables = new Set(rows.map((r) => r.table_name));

let created = 0, failed = 0;
for (const b of blocks) {
  if (dbTables.has(b.table)) continue;
  try {
    await client.query(b.sql);
    console.log(`+ ${b.table} (${b.file})`);
    dbTables.add(b.table);
    created++;
  } catch (err) {
    console.error(`! ${b.table} (${b.file}) : ${err.message.split('\n')[0]}`);
    failed++;
  }
}
console.log(`\nTables creees: ${created} | echecs: ${failed}`);
await client.end();
