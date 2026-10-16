import 'dotenv/config';
import pg from 'pg';
import { requireOpsConfirm } from './scripts/test_env.mjs';

const raw = process.env.DATABASE_URL || '';
const db = new pg.Client({
  connectionString: raw.replace(/[?&]sslmode=[^&]*/g, ''),
  ssl: { rejectUnauthorized: false },
});
requireOpsConfirm(process.env.DATABASE_URL, { script: "_update_test_stock.mjs" });
await db.connect();

// Mettre Ã  jour TOUS les produits TEST Ã  50 unitÃ©s
const updated = await db.query(`
  UPDATE stock_balances 
  SET quantity = 50, updated_at = now()
  WHERE medication_id IN (
    SELECT id FROM medications WHERE name LIKE 'TEST_PHARMA_PLUS%'
  )
  RETURNING medication_id, quantity
`);
console.log(`Produits TEST avec stock mis Ã  jour: ${updated.rowCount}`);

// VÃ©rifier
const verify = await db.query(`
  SELECT m.name, COALESCE(sb.quantity, 0) as stock
  FROM medications m
  LEFT JOIN stock_balances sb ON sb.medication_id = m.id
  WHERE m.name LIKE 'TEST_PHARMA_PLUS%'
  ORDER BY m.name
`);
console.log(`\n=== VÃ‰RIFICATION: ${verify.rows.length} produits ===`);
for (const v of verify.rows) {
  console.log(`${v.name}: ${v.stock} unitÃ©s`);
}

await db.end();
