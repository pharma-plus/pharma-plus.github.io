import pg from 'pg';
import { config } from '../config/index.js';

const { Pool } = pg;

// Connexions cloud (Supabase, AWS RDS…) : SSL activé. `sslmode=require` dans
// l'URL écraserait l'option ssl explicite (pg récent le traite comme
// verify-full, or la chaîne CA du pooler n'est pas fournie) => on le retire
// et on passe rejectUnauthorized:false explicitement. En local (postgres://…
// sans sslmode) ssl reste undefined.
const rawUrl = config.databaseUrl ?? '';
const useSsl = /(sslmode=require|supabase|amazonaws|\.rds\.)/i.test(rawUrl);
let databaseUrl = rawUrl;
if (useSsl) {
  const u = new URL(rawUrl);
  u.searchParams.delete('sslmode');
  databaseUrl = u.toString();
}
const ssl = useSsl ? { rejectUnauthorized: false } : undefined;

export const pool = new Pool({
  connectionString: databaseUrl,
  ssl,
  max: 20,
  idleTimeoutMillis: 30_000,
  connectionTimeoutMillis: 5_000,
  maxLifetimeSeconds: 1_800,
  application_name: 'pharma-maroc-gold-api',
});

pool.on('error', (err) => {
  console.error('[pg] idle client error', err.code, err.message);
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

/** Codes d'erreur PostgreSQL relatifs à une connexion perdue/morte. */
const CONNECTION_ERROR_CODES = new Set([
  'ECONNREFUSED', 'ETIMEDOUT', 'ECONNRESET', 'ENOTFOUND',
  '57P01', // admin_shutdown
  '57P02', // crash_shutdown
  '57P03', // cannot_connect_now
  '08001', // unable_to_connect
  '08006', // connection_failure
  '08007', // connection_failure_during_transaction
]);

/** Nombre maximum de tentatives en cas d'erreur de connexion temporaire. */
const MAX_CONNECT_RETRY = 2;

/**
 * Détermine si une requête SQL est une écriture (INSERT/UPDATE/DELETE).
 * Les écritures ne sont pas retryées automatiquement pour éviter tout
 * doublon en cas d'interruption réseau après exécution côté serveur.
 * L'idempotence des écritures critiques est gérée au niveau applicatif
 * (clés Idempotency-Key et clientSaleId dans SyncEngine).
 */
export function isWriteQuery(text) {
  const trimmed = text.trim();
  // Une requête INSERT/UPDATE/DELETE/... peut être précédée d'une clause
  // WITH (CTE). Détecter aussi ces cas pour éviter tout retry d'écriture
  // susceptible d'avoir déjà été exécutée côté serveur.
  const writePrefixes = /^(WITH\s+.*\b(INSERT|UPDATE|DELETE|TRUNCATE|DROP|ALTER|CREATE)\b|INSERT|UPDATE|DELETE|TRUNCATE|DROP|ALTER|CREATE)\b/i;
  return writePrefixes.test(trimmed);
}

/**
 * Exécute une requête SQL avec retry limité en cas d'erreur de connexion
 * temporaire. Les erreurs SQL (contrainte, syntaxe, permission) ne sont
 * pas retryées. Les écritures (INSERT/UPDATE/DELETE) ne sont pas retryées
 * pour éviter les doublons si la requête a déjà été exécutée côté serveur
 * avant la coupure réseau.
 */
async function queryWithRetry(text, params, attempt = 0) {
  try {
    return await pool.query(text, params);
  } catch (err) {
    const isConnectionError =
      CONNECTION_ERROR_CODES.has(err.code) ||
      /terminat|timeout|refused|reset|unable to connect/i.test(err.message);

    const isWrite = isWriteQuery(text);

    if (
      isConnectionError &&
      !isWrite &&
      attempt < MAX_CONNECT_RETRY
    ) {
      // Petite attente avant retry pour laisser le temps au pool de se
      // réapprovisionner.
      await new Promise((r) => setTimeout(r, 300 * (attempt + 1)));
      return queryWithRetry(text, params, attempt + 1);
    }

    // Ajouter un contexte technique exploitable sans divulguer de données.
    err.context = {
      code: err.code,
      message: err.message,
      isConnectionError,
      isWrite,
      attempt: attempt + 1,
    };
    throw err;
  }
}

/**
 * Exécute une requête simple (non transactionnelle) avec retry.
 */
export const query = (text, params) => queryWithRetry(text, params);
