import { Client } from "pg";
import "dotenv/config";
const url = (process.env.DATABASE_URL ?? "").replace(/[?&]sslmode=[^&]*/g, "");
const db = new Client({ connectionString: url, ssl: { rejectUnauthorized: false } });
await db.connect();
try {
  const o = await db.query(`select count(*)::int as n from stock_movements sm
    where sm.reference_type='sale' and (sm.reference_id is null
      or not exists (select 1 from sales s where s.id = sm.reference_id))`);
  console.log("mouvements reference_id orphelin =", o.rows[0].n);
  const d = await db.query(`select count(*)::int as n from mv_daily_sales`);
  console.log("mv_daily_sales rows =", d.rows[0].n);
  const t = await db.query(`select coalesce(sum(total),0) as t, count(*)::int as n from sales`);
  console.log("sales =", t.rows[0].n, "sum(total) =", t.rows[0].t);
} finally { await db.end(); }
