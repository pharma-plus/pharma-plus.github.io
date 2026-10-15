// Colonnes users utilisees par auth/switch-user
import { Client } from "pg";
import "dotenv/config";

const url = (process.env.DATABASE_URL ?? "").replace(/[?&]sslmode=[^&]*/g, "");
const c = new Client({ connectionString: url, ssl: { rejectUnauthorized: false } });
await c.connect();
try {
  const r = await c.query(
    `select column_name from information_schema.columns
     where table_name='users'
       and column_name in ('username','pin_hash','locked_until','two_factor_enabled','failed_login_attempts','locked_out_until')
     order by column_name`,
  );
  console.table(r.rows);
} finally {
  await c.end();
}
