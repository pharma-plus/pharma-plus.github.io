import 'dotenv/config';
import pg from 'pg';

const raw = process.env.DATABASE_URL || '';
const db = new pg.Client({
  connectionString: raw.replace(/[?&]sslmode=[^&]*/g, ''),
  ssl: { rejectUnauthorized: false },
});
await db.connect();

const pharmacies = await db.query(`
  SELECT id, name FROM pharmacies ORDER BY created_at LIMIT 5
`);
console.log('=== PHARMACIES ===');
for (const p of pharmacies.rows) console.log(`${p.id} — ${p.name}`);

const branches = await db.query(`
  SELECT id, pharmacy_id, name FROM branches ORDER BY created_at LIMIT 5
`);
console.log('\n=== BRANCHES ===');
for (const b of branches.rows) console.log(`${b.id} — ${b.name} (pharmacy ${b.pharmacy_id})`);

const statuses = await db.query(`
  SELECT status, COUNT(*) FROM medications GROUP BY status
`);
console.log('\n=== STATUTS medications ===');
for (const s of statuses.rows) console.log(`${s.count}: ${s.status}`);

const forms = await db.query(`
  SELECT form, COUNT(*) FROM medications WHERE form IS NOT NULL GROUP BY form ORDER BY COUNT(*) DESC LIMIT 10
`);
console.log('\n=== FORMES medications ===');
for (const f of forms.rows) console.log(`${f.count}: ${f.form}`);

// Check how POS filters medications (status + pharmacy)
const sampleMeds = await db.query(`
  SELECT m.id, m.name, m.status, m.pharmacy_id, m.price_sale, m.tva_rate,
         COALESCE(sb.quantity, 0) as stock
  FROM medications m
  LEFT JOIN stock_balances sb ON sb.medication_id = m.id
  WHERE m.status = 'available'
  LIMIT 5
`);
console.log('\n=== EXEMPLES médicaments disponibles ===');
for (const m of sampleMeds.rows) {
  console.log(`${m.name} | status=${m.status} | pharmacy=${m.pharmacy_id} | prix=${m.price_sale} | stock=${m.stock}`);
}

// What branch_id does stock_balances use?
const sbSample = await db.query(`
  SELECT DISTINCT branch_id, COUNT(*) as cnt
  FROM stock_balances GROUP BY branch_id LIMIT 5
`);
console.log('\n=== BRANCHES dans stock_balances ===');
for (const s of sbSample.rows) console.log(`${s.branch_id}: ${s.cnt} lignes`);

await db.end();
