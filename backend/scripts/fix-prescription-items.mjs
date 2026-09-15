// Ajoute prescription_items.created_at si absente (utilisee par le tri du
// service prescriptions : ORDER BY pi.created_at DESC).
import 'dotenv/config';
import pg from 'pg';

const url = (process.env.DATABASE_URL || '').replace(/[?&]sslmode=[^&]*/g, '');
const p = new pg.Pool({ connectionString: url, ssl: { rejectUnauthorized: false } });
await p.query(
  `ALTER TABLE prescription_items
     ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now()`,
);
console.log('prescription_items.created_at : OK');
await p.end();
