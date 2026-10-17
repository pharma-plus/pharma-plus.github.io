// Permissions backups live + création client Edge (service role ?).
import { Client } from "pg";
import "dotenv/config";

const url = (process.env.DATABASE_URL ?? "").replace(/[?&]sslmode=[^&]*/g, "");
const db = new Client({ connectionString: url, ssl: { rejectUnauthorized: false } });
await db.connect();
try {
  const perms = await db.query(
    `select p.id, p.code from permissions p where p.code like 'backup%' order by p.code`,
  );
  console.log("PERMISSIONS backups :", JSON.stringify(perms.rows));

  const rp = await db.query(
    `select r.name, p.code from role_permissions rp
     join roles r on r.id = rp.role_id
     join permissions p on p.id = rp.permission_id
     where p.code like 'backup%'`,
  );
  console.log("ROLE_PERMISSIONS :", JSON.stringify(rp.rows));

  const cols = await db.query(
    `select column_name from information_schema.columns where table_name='permissions' order by ordinal_position`,
  );
  console.log("COLONNES permissions :", cols.rows.map((r) => r.column_name).join(","));
} finally {
  await db.end();
}
