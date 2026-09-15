// Compare les tables definies dans database/schema/*.sql avec celles
// reellement presentes en base, et les tables referencees (FK) absentes.
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

// Tables declarees dans le schema
const schemaTables = new Set();
for (const f of fs.readdirSync(SCHEMA_DIR).filter((f) => f.endsWith('.sql')).sort()) {
  const txt = fs.readFileSync(path.join(SCHEMA_DIR, f), 'utf8');
  const re = /CREATE TABLE (?:IF NOT EXISTS )?([a-zA-Z_][\w]*)/g;
  let m;
  while ((m = re.exec(txt))) schemaTables.add(m[1].toLowerCase());
}

// Tables reelles
const { rows } = await client.query(
  `SELECT table_name FROM information_schema.tables
    WHERE table_schema = 'public' AND table_type = 'BASE TABLE'`,
);
const dbTables = new Set(rows.map((r) => r.table_name));

const missing = [...schemaTables].filter((t) => !dbTables.has(t)).sort();
console.log(`Tables schema: ${schemaTables.size} | tables DB: ${dbTables.size}`);
console.log(`Tables MANQUANTES en base (${missing.length}):`);
for (const t of missing) console.log(`  - ${t}`);
await client.end();
