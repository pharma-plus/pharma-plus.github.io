// Empreinte test : emp.link + iso.admin + pharmacie test (public.users + auth)
import { Client } from "pg";
import "dotenv/config";

const url = (process.env.DATABASE_URL ?? "").replace(/[?&]sslmode=[^&]*/g, "");
const c = new Client({ connectionString: url, ssl: { rejectUnauthorized: false } });
await c.connect();
try {
  const pu = await c.query(
    `select id, email, pharmacy_id, status from users
     where email like 'emp.link%' or email like 'iso.admin%' or email like 'x.employees%'
     order by email`,
  );
  console.log("public.users:");
  console.table(pu.rows);
  const au = await c.query(
    `select id, email from auth.users
     where email like 'emp.link%' or email like 'iso.admin%' or email like 'x.employees%'
     order by email`,
  );
  console.log("auth.users:");
  console.table(au.rows);
  const ph = await c.query(
    "select id, name, slug from pharmacies where slug like 'pharma-test-iso%'",
  );
  console.log("pharmacies test:");
  console.table(ph.rows);
} finally {
  await c.end();
}
