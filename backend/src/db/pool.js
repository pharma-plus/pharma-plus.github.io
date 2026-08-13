import pg from 'pg';
import { config } from '../config/index.js';

const { Pool } = pg;

// Connexions cloud (Supabase, AWS RDS, etc.) : on active SSL quand l'URL
// l'exige. En local (postgres://... sans sslmode) ssl reste undefined.
const ssl =
  config.databaseUrl &&
  /(sslmode=require|supabase|amazonaws|\.rds\.)/i.test(config.databaseUrl)
    ? { rejectUnauthorized: false }
    : undefined;

export const pool = new Pool({
  connectionString: config.databaseUrl,
  ssl,
  max: 20,
  idleTimeoutMillis: 30_000,
  connectionTimeoutMillis: 5_000,
  application_name: 'pharma-maroc-gold-api',
});

pool.on('error', (err) => {
  console.error('[pg] idle client error', err);
});

/**
 * Exécute une requête dans le contexte du tenant courant.
 * `pharmacyId` configure la variable `app.pharmacy_id` utilisée par les
 * politiques RLS (isolation stricte entre pharmacies).
 */
export async function withTenant(pharmacyId, fn) {
  if (!pharmacyId) return fn();
  const client = await pool.connect();
  try {
    await client.query("SELECT set_config('app.pharmacy_id', $1, true)", [pharmacyId]);
    return await fn(client);
  } finally {
    client.release();
  }
}

/**
 * Exécute une transaction avec isolation tenant.
 */
export async function withTransaction(pharmacyId, fn) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    if (pharmacyId) {
      await client.query("SELECT set_config('app.pharmacy_id', $1, true)", [pharmacyId]);
    }
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

export const query = (text, params) => pool.query(text, params);
