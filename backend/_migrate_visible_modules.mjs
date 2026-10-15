// Migration : colonne visible_modules sur users (NULL = tout visible).
import { Client } from "pg";
import "dotenv/config";

const url = (process.env.DATABASE_URL ?? "").replace(/[?&]sslmode=[^&]*/g, "");
const c = new Client({ connectionString: url, ssl: { rejectUnauthorized: false } });
await c.connect();
try {
  await c.query(
    `ALTER TABLE users ADD COLUMN IF NOT EXISTS visible_modules text[] DEFAULT NULL`
  );
  const r = await c.query(
    `SELECT column_name, data_type, column_default FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'visible_modules'`
  );
  console.log("Colonne visible_modules :", r.rows[0] ?? "ABSENTE");
  // Index GIN pour les requêtes @> (module present)
  await c.query(
    `CREATE INDEX IF NOT EXISTS users_visible_modules_gin ON users USING GIN (visible_modules) WHERE visible_modules IS NOT NULL`
  );
  console.log("Index GIN cree (ou deja present).");
} finally {
  await c.end();
}
