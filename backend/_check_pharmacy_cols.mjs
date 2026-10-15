// Colonnes de la table pharmacies
import { Client } from "pg";
import "dotenv/config";

const url = (process.env.DATABASE_URL ?? "").replace(/[?&]sslmode=[^&]*/g, "");
const c = new Client({ connectionString: url, ssl: { rejectUnauthorized: false } });
await c.connect();
try {
  const r = await c.query(
    `select column_name, data_type, is_nullable, column_default
     from information_schema.columns where table_name='pharmacies'
     order by ordinal_position`,
  );
  console.table(r.rows);
} finally {
  await c.end();
}
