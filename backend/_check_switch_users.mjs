// Etat users/employees (PIN, roles, liaison) pour tests switch-user
import { Client } from "pg";
import "dotenv/config";

const url = (process.env.DATABASE_URL ?? "").replace(/[?&]sslmode=[^&]*/g, "");
const c = new Client({ connectionString: url, ssl: { rejectUnauthorized: false } });
await c.connect();
try {
  const u = await c.query(
    `select u.id, u.email, u.first_name, u.last_name, u.status,
            (u.pin_hash is not null) as has_pin,
            r.name as role, u.pharmacy_id,
            e.id as emp_id, e.first_name as emp_first, e.status as emp_status
     from users u
     left join roles r on r.id = u.role_id
     left join employees e on e.user_id = u.id
     order by u.created_at`,
  );
  console.table(u.rows);
  const f = await c.query(
    "select id, first_name, last_name, status, user_id from employees order by first_name",
  );
  console.table(f.rows);
} finally {
  await c.end();
}
