import { Client } from 'pg';
import dotenv from 'dotenv';
dotenv.config();

const raw = process.env.DATABASE_URL.replace(/[?&]sslmode=[^&]*/g, '');
const c = new Client({ connectionString: raw, ssl: { rejectUnauthorized: false } });
await c.connect();

const cols = async (table) => {
  const { rows } = await c.query(
    `SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='public' AND table_name=$1 ORDER BY ordinal_position`,
    [table]
  );
  console.log(`\n== ${table} ==`);
  for (const r of rows) console.log(` ${r.column_name}: ${r.data_type}`);
};

await cols("sale_items");
await cols("stock_balances");
await cols("lots");

const { rows: si } = await c.query("SELECT medication_id, quantity, unit_price FROM sale_items LIMIT 3");
console.log("\nsample sale_items:", JSON.stringify(si));
const { rows: sb } = await c.query("SELECT medication_id, quantity FROM stock_balances WHERE quantity > 0 LIMIT 5");
console.log("sample stock_balances (qty>0):", JSON.stringify(sb));
const { rows: m } = await c.query("SELECT id, name FROM medications LIMIT 3");
console.log("sample medications:", JSON.stringify(m));

await c.end();
