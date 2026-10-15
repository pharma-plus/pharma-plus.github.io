// Pharmacies existantes + users par pharmacie (test isolation 17.F)
import { Client } from "pg";
import "dotenv/config";

const url = (process.env.DATABASE_URL ?? "").replace(/[?&]sslmode=[^&]*/g, "");
const c = new Client({ connectionString: url, ssl: { rejectUnauthorized: false } });
await c.connect();
try {
  const p = await c.query("select id, name, status from pharmacies order by created_at");
  console.table(p.rows);
  const u = await c.query(
    "select pharmacy_id, count(*) as n from users group by pharmacy_id",
  );
  console.table(u.rows);
  const s = await c.query(
    "select id, pharmacy_id, user_id, status, opened_at from cash_sessions order by opened_at desc limit 5",
  );
  console.table(s.rows);
} finally {
  await c.end();
}
