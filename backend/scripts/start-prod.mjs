import 'dotenv/config'; // En local : DATABASE_URL vient du .env (no-op sur l'h├®bergeur)
import { Client } from 'pg';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const backendDir = path.resolve(__dirname, '..');

/**
 * Connexion cloud (Supabase pooler, RDSÔÇª) : `sslmode=require` dans l'URL
 * ├®crase l'option ssl explicite (pg r├®cent le traite comme verify-full, or la
 * cha├«ne CA du pooler n'est pas fournie) => on retire sslmode et on passe
 * rejectUnauthorized:false. Sans cela, la connexion ├®choue et l'application
 * croyait ├á tort la base vide (=> migration sur une base pleine => crash).
 */
function makeClient() {
  const rawUrl = process.env.DATABASE_URL ?? '';
  const useSsl = /(sslmode=require|supabase|amazonaws|\.rds\.)/i.test(rawUrl);
  let connectionString = rawUrl;
  if (useSsl) {
    try {
      const u = new URL(rawUrl);
      u.searchParams.delete('sslmode');
      connectionString = u.toString();
    } catch {
      /* URL non standard : on la garde telle quelle */
    }
  }
  return new Client({
    connectionString,
    ssl: useSsl ? { rejectUnauthorized: false } : undefined,
  });
}

/** Base neuve (aucune table `users`) ? En cas d'erreur de connexion on
 *  r├®pond `false` : on ne migre JAMAIS ├á l'aveugle (une base pleine ferait
 *  ├®chouer migrate.js et planterait le conteneur en boucle). */
async function isEmptyDatabase() {
  const client = makeClient();
  try {
    await client.connect();
  } catch (err) {
    console.error('[start-prod] Connexion DB impossible :', err.message);
    return false;
  }
  try {
    const res = await client.query(
      "SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='users'",
    );
    return res.rowCount === 0;
  } finally {
    await client.end();
  }
}

if (await isEmptyDatabase()) {
  console.log('[start-prod] Base vide -> migration + seed');
  const r1 = spawnSync('node', ['scripts/migrate.js'], { cwd: backendDir, stdio: 'inherit' });
  if (r1.status !== 0) {
    console.error('[start-prod] migrate a echoue');
    process.exit(1);
  }
  const r2 = spawnSync('node', ['scripts/seed.js'], { cwd: backendDir, stdio: 'inherit' });
  if (r2.status !== 0) {
    console.error('[start-prod] seed a echoue');
    process.exit(1);
  }
  console.log('[start-prod] Migration + seed termines');
}

await import('../src/server.js');
