import { Client } from "pg";
import "dotenv/config";
const url = (process.env.DATABASE_URL ?? "").replace(/[?&]sslmode=[^&]*/g, "");
const db = new Client({ connectionString: url, ssl: { rejectUnauthorized: false } });
await db.connect();
try {
  const cols = await db.query("select column_name from information_schema.columns where table_name='permissions' order by ordinal_position");
  console.log("COLS permissions:", cols.rows.map(r => r.column_name).join(","));
  const p = await db.query("select * from permissions where code like 'backup%' or code like '%backup%' order by code");
  console.log("PERMS backups:", JSON.stringify(p.rows));
  const rps = await db.query("select role_id, permission_code from role_permissions where permission_code like 'backup%'");
  console.log("GRANTS:", JSON.stringify(rps.rows));
  const total = await db.query("select count(*)::int as n from permissions");
  console.log("total permissions:", total.rows[0].n);
} finally { await db.end(); }
