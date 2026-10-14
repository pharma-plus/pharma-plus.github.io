import 'dotenv/config';
import pg from 'pg';

const raw = process.env.DATABASE_URL || '';
const db = new pg.Client({
  connectionString: raw.replace(/[?&]sslmode=[^&]*/g, ''),
  ssl: { rejectUnauthorized: false },
});
await db.connect();

// Structure des tables pertinentes
const tables = await db.query(`
  SELECT table_name, column_name, data_type
  FROM information_schema.columns
  WHERE table_name IN ('medications', 'lots', 'stock_balances', 'stock_movements', 'reference_products')
  ORDER BY table_name, ordinal_position
`);

console.log('=== STRUCTURE DES TABLES ===');
for (const t of tables.rows) {
  console.log(`${t.table_name}.${t.column_name}: ${t.data_type}`);
}

// Compter les produits existants
const meds = await db.query(`SELECT COUNT(*) as total FROM medications`);
console.log(`\n=== PRODUITS EXISTANTS ===`);
console.log(`Total medications: ${meds.rows[0].total}`);

// Vérifier les produits TEST existants
const testMeds = await db.query(`
  SELECT id, name, price_sale, tva_rate, status, pharmacy_id
  FROM medications
  WHERE name ILIKE '%TEST%' OR name ILIKE '%PHARMA_TEST%'
  ORDER BY name
  LIMIT 25
`);
console.log(`\n=== PRODUITS TEST EXISTANTS ===`);
console.log(`Nombre: ${testMeds.rows.length}`);
for (const m of testMeds.rows) {
  console.log(`- ${m.name} (${m.price_sale} MAD, TVA ${m.tva_rate}%, status: ${m.status})`);
}

// Vérifier le stock pour les produits TEST
if (testMeds.rows.length > 0) {
  const testIds = testMeds.rows.map(m => m.id);
  const stock = await db.query(`
    SELECT m.name, COALESCE(sb.quantity, 0) as stock
    FROM medications m
    LEFT JOIN stock_balances sb ON sb.medication_id = m.id
    WHERE m.id = ANY($1)
    ORDER BY m.name
  `, [testIds]);
  
  console.log(`\n=== STOCK DES PRODUITS TEST ===`);
  for (const s of stock.rows) {
    console.log(`- ${s.name}: ${s.stock} unités`);
  }
}

// Vérifier la structure des colonnes critiques
const medColumns = await db.query(`
  SELECT column_name, data_type, is_nullable, column_default
  FROM information_schema.columns
  WHERE table_name = 'medications'
  ORDER BY ordinal_position
`);

console.log(`\n=== COLONNES medications ===`);
for (const c of medColumns.rows) {
  console.log(`${c.column_name}: ${c.data_type} ${c.is_nullable === 'NO' ? 'NOT NULL' : ''} ${c.column_default || ''}`);
}

await db.end();
