import { Client } from 'pg';
import dotenv from 'dotenv';
dotenv.config();

const raw = process.env.DATABASE_URL.replace(/[?&]sslmode=[^&]*/g, '');
const c = new Client({ connectionString: raw, ssl: { rejectUnauthorized: false } });
await c.connect();
const pid = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

const { rows: cols } = await c.query(`
  SELECT column_name FROM information_schema.columns
  WHERE table_schema='public' AND table_name='medications' ORDER BY ordinal_position
`);
console.log("medications columns:", cols.map(r => r.column_name).join(", "));

const { rows: withStock } = await c.query(`
  SELECT m.id, m.name, m.status, m.price_sale, m.reorder_level, sb.quantity,
         (SELECT l.cost_price FROM lots l WHERE l.medication_id = m.id LIMIT 1) AS cost
  FROM stock_balances sb
  JOIN medications m ON m.id = sb.medication_id
  WHERE sb.pharmacy_id = $1 AND sb.quantity > 0
  ORDER BY sb.quantity DESC LIMIT 5
`, [pid]);
console.log("\nmeds with stock:");
for (const r of withStock) {
  console.log(` ${r.name} | status=${r.status} | price=${r.price_sale} | cost=${r.cost} | reorder=${r.reorder_level} | qty=${r.quantity}`);
}

const { rows: any } = await c.query(`
  SELECT COUNT(DISTINCT medication_id) FROM stock_balances WHERE pharmacy_id = $1 AND quantity > 0
`, [pid]);
console.log("\nany status+stock:", any[0].count);

const { rows: avail } = await c.query(`
  SELECT COUNT(DISTINCT m.id) FROM medications m
  JOIN stock_balances sb ON sb.medication_id = m.id
  WHERE m.pharmacy_id = $1 AND m.status = 'available' AND sb.quantity > 0
`, [pid]);
console.log("available+stock:", avail[0].count);

await c.end();
