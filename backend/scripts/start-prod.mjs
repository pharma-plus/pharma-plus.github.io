import { Client } from 'pg';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const backendDir = path.resolve(__dirname, '..');

async function needsMigration() {
  const client = new Client({ connectionString: process.env.DATABASE_URL });
  try {
    await client.connect();
  } catch {
    return true;
  }
  const res = await client.query(
    "SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='users'"
  );
  await client.end();
  return res.rowCount === 0;
}

if (await needsMigration()) {
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
