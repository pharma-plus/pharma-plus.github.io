import { Client } from "pg";
import "dotenv/config";
const url = (process.env.DATABASE_URL ?? "").replace(/[?&]sslmode=[^&]*/g, "");
const db = new Client({ connectionString: url, ssl: { rejectUnauthorized: false } });
await db.connect();
try {
  const c = await db.query(`select column_name from information_schema.columns where table_name='users' and column_name='pin_hash'`);
  console.log("pin_hash column exists:", c.rowCount > 0);
  const a = await db.query(`select action, entity_type, details::text d, created_at from audit_log
    where details::text like '%edc15f97%' or entity_id = 'edc15f97-b8ce-4482-b530-b33fa7746a2d'
    order by created_at desc limit 8`);
  for (const r of a.rows) console.log(r.created_at, r.action, r.entity_type, r.d?.slice(0, 160));
  if (!a.rowCount) console.log("aucun audit_log sur admin");
} finally { await db.end(); }
