import { Client } from "pg";
import "dotenv/config";
const url = (process.env.DATABASE_URL ?? "").replace(/[?&]sslmode=[^&]*/g, "");
const db = new Client({ connectionString: url, ssl: { rejectUnauthorized: false } });
await db.connect();
try {
  const a = await db.query(`select medication_id, sum(abs(quantity))::numeric as comp from stock_movements
    where reference_type='test_cleanup' group by 1`);
  console.log("COMPENSATIONS par produit :");
  for (const r of a.rows) console.log(`  med=${r.medication_id} +${r.comp}`);
  const s = await db.query(`select count(*)::int as n, sum(total) as t from sales`);
  console.log(`VENTES restantes = ${s.rows[0].n} (total ${s.rows[0].t})`);
  const mv = await db.query(`select count(*)::int as n from stock_movements where reference_type='sale'
    and (reference_id is null or not exists (select 1 from sales s where s.id = stock_movements.reference_id))`);
  console.log("mouvements 'sale' VRAIMENT orphelins =", mv.rows[0].n);
  const st = await db.query(`select count(*)::int as n from sales where notes ilike '%test%'`);
  console.log("ventes test restantes =", st.rows[0].n);
} finally { await db.end(); }
