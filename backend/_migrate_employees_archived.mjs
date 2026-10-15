// Migration additive : employees.status accepte 'archived' (archivage logique)
import { Client } from "pg";
import "dotenv/config";

const url = (process.env.DATABASE_URL ?? "").replace(/[?&]sslmode=[^&]*/g, "");
const c = new Client({ connectionString: url, ssl: { rejectUnauthorized: false } });
await c.connect();
try {
  await c.query("BEGIN");
  await c.query("ALTER TABLE employees DROP CONSTRAINT IF EXISTS employees_status_check");
  await c.query(
    "ALTER TABLE employees ADD CONSTRAINT employees_status_check CHECK (status = ANY (ARRAY['active'::text,'inactive'::text,'on_leave'::text,'terminated'::text,'archived'::text]))",
  );
  await c.query("COMMIT");
  const ck = await c.query(
    "select conname, pg_get_constraintdef(oid) as def from pg_constraint where conrelid = 'employees'::regclass and conname = 'employees_status_check'",
  );
  console.table(ck.rows);
  console.log("OK employees_status_check mis a jour");
} catch (e) {
  await c.query("ROLLBACK");
  console.error("ECHEC:", e.message);
  process.exitCode = 1;
} finally {
  await c.end();
}
