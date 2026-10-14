import 'dotenv/config';
import pg from 'pg';

const raw = process.env.DATABASE_URL || '';
const db = new pg.Client({
  connectionString: raw.replace(/[?&]sslmode=[^&]*/g, ''),
  ssl: { rejectUnauthorized: false },
});
await db.connect();

// Purger les produits TEST_PHARMA_PLUS créés par l'exécution partielle
const deleted = await db.query(`
  DELETE FROM stock_balances
  WHERE medication_id IN (SELECT id FROM medications WHERE name LIKE 'TEST_PHARMA_PLUS%')
`);
console.log(`stock_balances supprimés: ${deleted.rowCount}`);

const deletedMeds = await db.query(`
  DELETE FROM medications WHERE name LIKE 'TEST_PHARMA_PLUS%'
`);
console.log(`medications supprimés: ${deletedMeds.rowCount}`);

await db.end();
