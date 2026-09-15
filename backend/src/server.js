import { createApp } from './app.js';
import { config } from './config/index.js';
import { pool } from './db/pool.js';

const app = createApp();

const server = app.listen(config.port, async () => {
  console.log(`[pmg] API PHARMA MAROC GOLD démarrée sur http://localhost:${config.port}`);
  try {
    await pool.query('SELECT 1');
    console.log('[pmg] Connexion PostgreSQL : OK');
  } catch (err) {
    console.error('[pmg] Connexion PostgreSQL : ÉCHEC —', err.message);
  }
});

async function shutdown(signal) {
  console.log(`[pmg] ${signal} reçu, arrêt propre...`);
  server.close(async () => {
    await pool.end();
    process.exit(0);
  });
  setTimeout(() => process.exit(1), 10_000).unref();
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));
