import { Client } from "pg";
import "dotenv/config";
const url = (process.env.DATABASE_URL ?? "").replace(/[?&]sslmode=[^&]*/g, "");
const db = new Client({ connectionString: url, ssl: { rejectUnauthorized: false } });
await db.connect();
try {
  const c = await db.query("select column_name, data_type from information_schema.columns where table_name='stock_balances' order by ordinal_position");
  console.log("STOCK_BALANCES: " + c.rows.map(r => r.column_name + ":" + r.data_type.slice(0,10)).join(", "));
  const v = await db.query(`select count(*)::int n, coalesce(sum(quantity),0)::int qte,
    coalesce(sum(quantity * coalesce(cost_price, unit_price, 0)),0)::numeric(14,2) val1
    from stock_balances`).catch(async () => {
    const c2 = (await db.query("select column_name from information_schema.columns where table_name='stock_balances'")).rows.map(r=>r.column_name);
    return { rows: [{ n: "?", qte: "?", val1: "?", cols: c2.join(",") }] };
  });
  console.log("balances=" + v.rows[0].n + " qte=" + v.rows[0].qte + (v.rows[0].cols ? " COLS=" + v.rows[0].cols : " val=" + v.rows[0].val1));
} finally { await db.end(); }