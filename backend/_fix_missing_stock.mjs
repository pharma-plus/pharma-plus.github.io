import 'dotenv/config';
import pg from 'pg';
import { randomUUID } from 'crypto';

const raw = process.env.DATABASE_URL || '';
const db = new pg.Client({
  connectionString: raw.replace(/[?&]sslmode=[^&]*/g, ''),
  ssl: { rejectUnauthorized: false },
});
await db.connect();

const PHARMACY_ID = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
const BRANCH_ID = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

// Créer les lignes stock manquantes pour les 5 produits AucunStock
const noStockMeds = await db.query(`
  SELECT m.id, m.name FROM medications m
  WHERE m.name LIKE 'TEST_PHARMA_PLUS_AucunStock%'
  AND NOT EXISTS (SELECT 1 FROM stock_balances sb WHERE sb.medication_id = m.id)
`);
console.log(`Produits sans ligne stock: ${noStockMeds.rows.length}`);

for (const m of noStockMeds.rows) {
  const stockId = randomUUID();
  await db.query(
    `INSERT INTO stock_balances (
      id, pharmacy_id, branch_id, medication_id, lot_id,
      quantity, reserved_quantity, location, updated_at
    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, now())`,
    [stockId, PHARMACY_ID, BRANCH_ID, m.id, null, 50, 0, 'Rayon Test']
  );
  console.log(`✓ ${m.name}: 50 unités`);
}

// Vérification finale : TOUS les produits TEST à 50
const verify = await db.query(`
  SELECT m.name, COALESCE(sb.quantity, 0) as stock
  FROM medications m
  LEFT JOIN stock_balances sb ON sb.medication_id = m.id
  WHERE m.name LIKE 'TEST_PHARMA_PLUS%'
  ORDER BY m.name
`);
console.log(`\n=== VÉRIFICATION: ${verify.rows.length} produits ===`);
for (const v of verify.rows) {
  console.log(`${v.name}: ${v.stock} unités`);
}

await db.end();
