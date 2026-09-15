// Liste les colonnes d'une table (usage: node scripts/columns.mjs <table>)
import 'dotenv/config';
import pg from 'pg';

const url = (process.env.DATABASE_URL || '').replace(/[?&]sslmode=[^&]*/g, '');
const p = new pg.Pool({ connectionString: url, ssl: { rejectUnauthorized: false } });
const table = process.argv[2] || 'customers';
const r = await p.query(
  `SELECT column_name, is_nullable, data_type FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = $1 ORDER BY ordinal_position`,
  [table],
);
console.log(r.rows.map((c) => `${c.column_name}${c.is_nullable === 'NO' ? '*' : ''}:${c.data_type}`).join('\n'));
await p.end();
