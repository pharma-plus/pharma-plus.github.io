import 'dotenv/config';
import pg from 'pg';
import { requireOpsConfirm } from './scripts/test_env.mjs';

const raw = process.env.DATABASE_URL || '';
const db = new pg.Client({
  connectionString: raw.replace(/[?&]sslmode=[^&]*/g, ''),
  ssl: { rejectUnauthorized: false },
});
requireOpsConfirm(process.env.DATABASE_URL, { script: "_purge_test_products.mjs" });
await db.connect();

// Purger les produits TEST_PHARMA_PLUS crÃ©Ã©s par l'exÃ©cution partielle
const deleted = await db.query(`
  DELETE FROM stock_balances
  WHERE medication_id IN (SELECT id FROM medications WHERE name LIKE 'TEST_PHARMA_PLUS%')
`);
console.log(`stock_balances supprimÃ©s: ${deleted.rowCount}`);

const deletedMeds = await db.query(`
  DELETE FROM medications WHERE name LIKE 'TEST_PHARMA_PLUS%'
`);
console.log(`medications supprimÃ©s: ${deletedMeds.rowCount}`);

await db.end();
