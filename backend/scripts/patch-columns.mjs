// Patch idempotent : compare le schema SQL (database/schema/*.sql) avec les
// colonnes reelles de la base et ajoute les colonnes manquantes.
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

// --- Parse CREATE TABLE ... ( ... ); du schema
const schema = {}; // table -> { col: definition }
for (const f of fs.readdirSync(SCHEMA_DIR).filter((f) => f.endsWith('.sql')).sort()) {
  const txt = fs.readFileSync(path.join(SCHEMA_DIR, f), 'utf8');
  const re = /CREATE TABLE (?:IF NOT EXISTS )?([a-zA-Z_][\w]*)\s*\(([\s\S]*?)\n\)/g;
  let m;
  while ((m = re.exec(txt))) {
    const table = m[1].toLowerCase();
    const body = m[2];
    schema[table] = schema[table] || {};
    for (const rawLine of body.split('\n')) {
      const line = rawLine.trim().replace(/--.*$/, '').trim().replace(/,$/, '');
      if (!line) continue;
      if (/^(PRIMARY KEY|UNIQUE|FOREIGN KEY|CONSTRAINT|CHECK|EXCLUDE)/i.test(line)) continue;
      const cm = line.match(/^([a-zA-Z_][\w]*)\s+(.+)$/);
      if (!cm) continue;
      const col = cm[1].toLowerCase();
      if (['key', 'constraint'].includes(col.toLowerCase()) && /PRIMARY|FOREIGN|UNIQUE/i.test(line)) continue;
      schema[table][col] = cm[2].trim();
    }
  }
}

// --- Colonnes reelles
const { rows } = await client.query(
  `SELECT table_name, column_name FROM information_schema.columns WHERE table_schema = 'public'`,
);
const actual = {};
for (const r of rows) {
  actual[r.table_name] = actual[r.table_name] || new Set();
  actual[r.table_name].add(r.column_name);
}

// --- Ajout des colonnes manquantes
let added = 0, failed = 0;
for (const [table, cols] of Object.entries(schema)) {
  if (!actual[table]) continue; // table inexistante : ne pas la creer ici
  for (const [col, def] of Object.entries(cols)) {
    if (actual[table].has(col)) continue;
    let typeDef = def.replace(/--.*$/gm, '').replace(/\s+REFERENCES\s+.*$/is, '').trim();
    try {
      await client.query(`ALTER TABLE "${table}" ADD COLUMN IF NOT EXISTS "${col}" ${typeDef}`);
      console.log(`+ ${table}.${col}`);
      added++;
    } catch (err) {
      console.error(`! ${table}.${col} : ${err.message.split('\n')[0]}`);
      failed++;
    }
  }
}
// --- ALTER TABLE ... ADD COLUMN IF NOT EXISTS explicites du schema
for (const f of fs.readdirSync(SCHEMA_DIR).filter((f) => f.endsWith('.sql')).sort()) {
  const txt = fs.readFileSync(path.join(SCHEMA_DIR, f), 'utf8');
  const re = /ALTER TABLE\s+(?:ONLY\s+)?"?([a-zA-Z_][\w]*)"?\s+ADD COLUMN\s+IF NOT EXISTS\s+([^;]+);/gi;
  let m;
  while ((m = re.exec(txt))) {
    const table = m[1].toLowerCase();
    if (!actual[table]) continue;
    const col = m[2].trim().split(/[\s(]/)[0].replace(/"/g, '').toLowerCase();
    if (actual[table].has(col)) continue;
    try {
      await client.query(`ALTER TABLE "${table}" ADD COLUMN IF NOT EXISTS ${m[2].trim()}`);
      console.log(`+ (alter) ${table}.${col}`);
      added++;
    } catch (err) {
      console.error(`! (alter) ${table}.${col} : ${err.message.split('\n')[0]}`);
      failed++;
    }
  }
}
console.log(`\nColonnes ajoutees: ${added} | echecs: ${failed}`);
await client.end();
