import "dotenv/config";
import pg from "pg";
const raw = process.env.DATABASE_URL;
const c = new pg.Client({ connectionString: raw.replace(/[?&]sslmode=[^&]*/g, ""), ssl: { rejectUnauthorized: false } });
await c.connect();
const { rows } = await c.query(`
  SELECT s.number, s.status, s.total, s.created_at, s.notes,
         (SELECT COALESCE(SUM(amount),0) FROM payments WHERE sale_id=s.id) AS paid
  FROM sales s
  WHERE s.pharmacy_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
  ORDER BY s.created_at DESC LIMIT 8`);
for (const r of rows) {
  console.log(`${r.created_at.toISOString().slice(11,16)} | ${r.number} | ${r.status} | total=${r.total} paid=${r.paid} | ${r.notes ?? ""}`);
}
const { rows: [{ n }] } = await c.query(`SELECT COUNT(*)::int AS n FROM sales WHERE created_at > now() - interval '3 hours'`);
console.log(`\nVentes dernières 3h: ${n}`);
await c.end();
