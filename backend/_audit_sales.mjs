import { Client } from "pg";
import "dotenv/config";

const url = (process.env.DATABASE_URL ?? "").replace(/[?&]sslmode=[^&]*/g, "");
const c = new Client({ connectionString: url, ssl: { rejectUnauthorized: false } });
await c.connect();
try {
  const cols = await c.query(
    `select column_name from information_schema.columns
     where table_schema='public' and table_name='sales' order by ordinal_position`);
  console.log("sales cols:", cols.rows.map(r => r.column_name).join(", "));

  const s = await c.query(`
    select s.id, s.number, s.sale_date::date as d, s.total, s.status,
      pg_typeof(s.payments)::text as payments_type,
      (select count(*) from payments p where p.sale_id=s.id) as nb_pay
    from sales s
    where not exists (select 1 from payments p where p.sale_id=s.id)
    order by s.sale_date`);
  console.log("Ventes sans paiement (table payments) :");
  console.table(s.rows);

  const pay = await c.query(`
    select s.number, s.payment_method, left(s.payments::text, 160) as payments_json
    from sales s
    where not exists (select 1 from payments p where p.sale_id=s.id)`);
  console.log("Colonne jsonb sales.payments pour ces 4 :");
  console.table(pay.rows);

  const t = await c.query(`
    select si.tax_rate, count(*) as n
    from sale_items si
    group by si.tax_rate order by n desc`);
  console.log("tax_rate sur sale_items :");
  console.table(t.rows);
} finally {
  await c.end();
}
