import { Client } from "pg";
import "dotenv/config";

const url = (process.env.DATABASE_URL ?? "").replace(/[?&]sslmode=[^&]*/g, "");
const c = new Client({ connectionString: url, ssl: { rejectUnauthorized: false } });
await c.connect();
try {
  const s = await c.query(`
    select number, status, subtotal, discount_total, tax_total, total, payment_method,
      paid_amount, change_amount, payment_ref
    from sales where number = 'POS-2026-000098'`);
  console.log("Vente 98 :"); console.table(s.rows);

  const pay = await c.query(`
    select p.method, p.amount, p.status
    from payments p join sales s on s.id = p.sale_id
    where s.number = 'POS-2026-000098'`);
  console.log("Payments :"); console.table(pay.rows);

  const li = await c.query(`
    select si.medication_id, si.quantity, si.unit_price, si.tax_rate, si.line_total, si.lot_id
    from sale_items si join sales s on s.id = si.sale_id
    where s.number = 'POS-2026-000098'`);
  console.log("sale_items :"); console.table(li.rows);

  const st = await c.query(`
    select quantity, updated_at from stock_balances
    where medication_id = (select id from medications where name = 'TEST_PHARMA_PLUS_StockNormal_A' limit 1)`);
  console.log("Stock actuel produit :"); console.table(st.rows);
} finally {
  await c.end();
}
