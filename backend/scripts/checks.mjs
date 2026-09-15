// Liste les contraintes CHECK d'une table (usage: node scripts/checks.mjs <table>)
import 'dotenv/config';
import pg from 'pg';

const url = (process.env.DATABASE_URL || '').replace(/[?&]sslmode=[^&]*/g, '');
const p = new pg.Pool({ connectionString: url, ssl: { rejectUnauthorized: false } });
const table = process.argv[2];
const r = await p.query(
  `SELECT conname, pg_get_constraintdef(oid) AS def
     FROM pg_constraint
    WHERE conrelid = $1::regclass AND contype IN ('c','f')`,
  [table],
);
for (const row of r.rows) console.log(`${row.conname}: ${row.def}`);
await p.end();
