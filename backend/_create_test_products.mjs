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

// Vérifier qu'aucun produit TEST n'existe déjà
const existing = await db.query(
  `SELECT COUNT(*) as cnt FROM medications WHERE name LIKE 'TEST_PHARMA_PLUS%'`
);
if (parseInt(existing.rows[0].cnt) > 0) {
  console.log(`STOP: ${existing.rows[0].cnt} produits TEST_PHARMA_PLUS existent déjà.`);
  console.log('Supprimez-les d\'abord ou changez le marqueur.');
  await db.end();
  process.exit(1);
}

// 20 produits de test avec scénarios variés
const products = [
  // 5 produits SANS stock (pas de ligne stock_balances) → stock inconnu
  { name: 'TEST_PHARMA_PLUS_AucunStock_A', price: 25.00, tva: 20, form: 'Comprimé', dosage: '500 mg', scenario: 'no_stock_row' },
  { name: 'TEST_PHARMA_PLUS_AucunStock_B', price: 32.50, tva: 20, form: 'Gélule', dosage: '250 mg', scenario: 'no_stock_row' },
  { name: 'TEST_PHARMA_PLUS_AucunStock_C', price: 18.00, tva: 10, form: 'Sirop', dosage: '100 ml', scenario: 'no_stock_row' },
  { name: 'TEST_PHARMA_PLUS_AucunStock_D', price: 45.00, tva: 20, form: 'Comprimé', dosage: '1 g', scenario: 'no_stock_row' },
  { name: 'TEST_PHARMA_PLUS_AucunStock_E', price: 12.00, tva: 10, form: 'Pommade', dosage: '30 g', scenario: 'no_stock_row' },

  // 5 produits avec stock = 0 explicite
  { name: 'TEST_PHARMA_PLUS_StockZero_A', price: 55.00, tva: 20, form: 'Comprimé', dosage: '20 mg', scenario: 'zero' },
  { name: 'TEST_PHARMA_PLUS_StockZero_B', price: 78.00, tva: 20, form: 'Gélule', dosage: '40 mg', scenario: 'zero' },
  { name: 'TEST_PHARMA_PLUS_StockZero_C', price: 22.00, tva: 10, form: 'Solution', dosage: '200 ml', scenario: 'zero' },
  { name: 'TEST_PHARMA_PLUS_StockZero_D', price: 95.00, tva: 20, form: 'Comprimé', dosage: '50 mg', scenario: 'zero' },
  { name: 'TEST_PHARMA_PLUS_StockZero_E', price: 38.00, tva: 10, form: 'Crème', dosage: '40 g', scenario: 'zero' },

  // 5 produits avec stock faible (1-3 unités)
  { name: 'TEST_PHARMA_PLUS_StockFaible_A', price: 65.00, tva: 20, form: 'Comprimé', dosage: '10 mg', scenario: 1 },
  { name: 'TEST_PHARMA_PLUS_StockFaible_B', price: 42.00, tva: 20, form: 'Gélule', dosage: '15 mg', scenario: 2 },
  { name: 'TEST_PHARMA_PLUS_StockFaible_C', price: 28.00, tva: 10, form: 'Sirop', dosage: '150 ml', scenario: 3 },
  { name: 'TEST_PHARMA_PLUS_StockFaible_D', price: 88.00, tva: 20, form: 'Comprimé', dosage: '100 mg', scenario: 1 },
  { name: 'TEST_PHARMA_PLUS_StockFaible_E', price: 51.00, tva: 20, form: 'Spray', dosage: '30 ml', scenario: 2 },

  // 5 produits avec stock normal (10-50 unités)
  { name: 'TEST_PHARMA_PLUS_StockNormal_A', price: 35.00, tva: 20, form: 'Comprimé', dosage: '500 mg', scenario: 10 },
  { name: 'TEST_PHARMA_PLUS_StockNormal_B', price: 48.00, tva: 20, form: 'Gélule', dosage: '20 mg', scenario: 25 },
  { name: 'TEST_PHARMA_PLUS_StockNormal_C', price: 15.00, tva: 10, form: 'Sirop', dosage: '100 ml', scenario: 50 },
  { name: 'TEST_PHARMA_PLUS_StockNormal_D', price: 72.00, tva: 20, form: 'Comprimé', dosage: '25 mg', scenario: 15 },
  { name: 'TEST_PHARMA_PLUS_StockNormal_E', price: 30.00, tva: 10, form: 'Pommade', dosage: '50 g', scenario: 20 },
];

const created = [];
for (const p of products) {
  const id = randomUUID();
  const margin = p.price * 0.3;
  const pricePurchase = p.price - margin;

  await db.query(
    `INSERT INTO medications (
      id, pharmacy_id, name, dosage, form, price_purchase, price_sale,
      tva_rate, margin, prescription_required, reorder_level, min_stock,
      status, is_public, revision, laboratory_name
    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16)`,
    [
      id, PHARMACY_ID, p.name, p.dosage, p.form,
      pricePurchase.toFixed(2), p.price.toFixed(2),
      p.tva, margin.toFixed(2),
      false, 5, 2,
      'available', true, 1, 'TEST_LAB'
    ]
  );

  // Créer le stock si le scénario le prévoit (pas pour no_stock_row)
  if (p.scenario !== 'no_stock_row') {
    const qty = p.scenario === 'zero' ? 0 : p.scenario;
    const stockId = randomUUID();
    await db.query(
      `INSERT INTO stock_balances (
        id, pharmacy_id, branch_id, medication_id, lot_id,
        quantity, reserved_quantity, location, updated_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, now())`,
      [
        stockId, PHARMACY_ID, BRANCH_ID, id, null,
        qty, 0, 'Rayon Test'
      ]
    );
  }

  created.push({ id, name: p.name, scenario: p.scenario });
  console.log(`✓ ${p.name} — ${p.scenario === 'no_stock_row' ? 'pas de ligne stock' : `stock=${p.scenario === 'zero' ? 0 : p.scenario}`}`);
}

// Vérification finale
const verify = await db.query(`
  SELECT m.name, m.price_sale, m.tva_rate,
         CASE WHEN sb.id IS NULL THEN 'NO_ROW'
              ELSE sb.quantity::text
         END as stock
  FROM medications m
  LEFT JOIN stock_balances sb ON sb.medication_id = m.id
  WHERE m.name LIKE 'TEST_PHARMA_PLUS%'
  ORDER BY m.name
`);

console.log(`\n=== VÉRIFICATION: ${verify.rows.length} produits TEST créés ===`);
for (const v of verify.rows) {
  console.log(`${v.name} | prix=${v.price_sale} | TVA=${v.tva_rate}% | stock=${v.stock}`);
}

const total = await db.query(`
  SELECT COUNT(*) as cnt FROM medications WHERE name LIKE 'TEST_PHARMA_PLUS%'
`);
console.log(`\nTOTAL: ${total.rows[0].cnt}/20 produits TEST_PHARMA_PLUS`);

await db.end();
