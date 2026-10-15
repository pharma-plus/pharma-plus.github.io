// Diagnostic colonnes/constraints employees (status, user_id)
import { Client } from "pg";
import "dotenv/config";

const url = (process.env.DATABASE_URL ?? "").replace(/[?&]sslmode=[^&]*/g, "");
const c = new Client({ connectionString: url, ssl: { rejectUnauthorized: false } });
await c.connect();
try {
  const cols = await c.query(
    "select column_name,data_type,column_default,is_nullable from information_schema.columns where table_name='employees' order by ordinal_position",
  );
  console.table(cols.rows);
  const ck = await c.query(
    "select conname, pg_get_constraintdef(oid) as def from pg_constraint where conrelid = 'employees'::regclass",
  );
  console.table(ck.rows);
  const vals = await c.query(
    "select status, count(*) from employees group by status",
  );
  console.table(vals.rows);
} finally {
  await c.end();
}
