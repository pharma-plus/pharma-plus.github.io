import { Client } from 'pg';
import dotenv from 'dotenv';
dotenv.config();

const raw = process.env.DATABASE_URL.replace(/[?&]sslmode=[^&]*/g, '');
const c = new Client({ connectionString: raw, ssl: { rejectUnauthorized: false } });
await c.connect();
const pid = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

// sale_items medication_id : combien matchent medications ?
const { rows: stats } = await c.query(`
  SELECT
    COUNT(*) AS total_items,
    COUNT(*) FILTER (WHERE m.id IS NOT NULL) AS matched,
    COUNT(*) FILTER (WHERE m.id IS NULL) AS unmatched
  FROM sale_items si
  LEFT JOIN medications m ON m.id = si.medication_id
  WHERE si.pharmacy_id = $1
`, [pid]);
console.log("sale_items match:", JSON.stringify(stats[0]));

// Exemples unmatched
const { rows: un } = await c.query(`
  SELECT DISTINCT si.medication_id FROM sale_items si
  LEFT JOIN medications m ON m.id = si.medication_id
  WHERE si.pharmacy_id = $1 AND m.id IS NULL LIMIT 3
`, [pid]);
console.log("unmatched IDs:", un.map(r => r.medication_id));

// Sales avec user_id
const { rows: su } = await c.query(`
  SELECT user_id, COUNT(*) FROM sales WHERE pharmacy_id = $1 AND status='completed' GROUP BY user_id
`, [pid]);
console.log("sales by user_id:", JSON.stringify(su));

// Employees avec user_id
const { rows: eu } = await c.query(`
  SELECT id, first_name, last_name, user_id FROM employees WHERE pharmacy_id = $1
`, [pid]);
console.log("employees:", JSON.stringify(eu));

await c.end();
