import { Client } from 'pg';
import dotenv from 'dotenv';
dotenv.config();

const raw = process.env.DATABASE_URL.replace(/[?&]sslmode=[^&]*/g, '');
const c = new Client({ connectionString: raw, ssl: { rejectUnauthorized: false } });
await c.connect();
const pid = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

const { rows: uc } = await c.query(`
  SELECT column_name FROM information_schema.columns
  WHERE table_schema='public' AND table_name='users' ORDER BY ordinal_position
`);
console.log("users columns:", uc.map(r => r.column_name).join(", "));

const { rows: users } = await c.query("SELECT id, email, first_name, last_name, role_id FROM users WHERE pharmacy_id = $1 LIMIT 5", [pid]);
console.log("\nusers:", JSON.stringify(users));

// user_ids des ventes
const { rows: saleUsers } = await c.query(`
  SELECT DISTINCT s.user_id, u.email FROM sales s
  LEFT JOIN users u ON u.id = s.user_id
  WHERE s.pharmacy_id = $1 AND s.user_id IS NOT NULL
`, [pid]);
console.log("\nsales user_ids:", JSON.stringify(saleUsers));

await c.end();
