// PMG-MOROCCO-SUPPLIERS
/**
 * IMPORT CONTR├öL├ë ÔÇö Fournisseurs / laboratoires pharmaceutiques du Maroc.
 *
 * Ins├¿re (idempotent : jamais de doublon, n'├®crase RIEN) une base initiale
 * de laboratoires et distributeurs pr├®sents au Maroc dans CHAQUE pharmacie
 * existante (ou une seule avec --pharmacy=<uuid>).
 *
 * Sources publiques : sites officiels des soci├®t├®s (sothema.ma,
 * cooperpharma.ma, laprophan.ma, maphar.ma, cophat.maÔÇª) et r├®pertoires
 * professionnels. T├®l├®phones / emails / ICE : non renseign├®s ici ÔÇö
 * ├á compl├®ter par la pharmacie (ne pas inventer de donn├®es de contact).
 *
 * Usage :
 *   node scripts/import-morocco-suppliers.js
 *   node scripts/import-morocco-suppliers.js --pharmacy=<uuid>
 */
import 'dotenv/config';
import pg from 'pg';
import { randomUUID } from 'node:crypto';

const rawUrl = process.env.DATABASE_URL ?? '';
const useSsl = /(sslmode=require|supabase|amazonaws|\.rds\.)/i.test(rawUrl);
let connectionString = rawUrl;
if (useSsl) {
  const u = new URL(rawUrl);
  u.searchParams.delete('sslmode');
  connectionString = u.toString();
}
const client = new pg.Client({
  connectionString,
  ssl: useSsl ? { rejectUnauthorized: false } : undefined,
});
await client.connect();

// Colonnes type/ice (migration 920) ÔÇö cr├®├®es ici si absentes pour que
// le script fonctionne sur toute base existante.
await client.query(`ALTER TABLE suppliers ADD COLUMN IF NOT EXISTS type TEXT`);
await client.query(`ALTER TABLE suppliers ADD COLUMN IF NOT EXISTS ice TEXT`);

/**
 * Base initiale ÔÇö informations v├®rifiables publiquement.
 * type : laboratoire | grossiste | distributeur | fournisseur
 */
const MOROCCO_SUPPLIERS = [
  // ---- Laboratoires pharmaceutiques marocains ----
  { name: 'Sothema', type: 'laboratoire', city: 'Casablanca', website: 'https://www.sothema.ma' },
  { name: 'Cooper Pharma', type: 'laboratoire', city: 'Casablanca', website: 'https://www.cooperpharma.ma' },
  { name: 'Laprophan', type: 'laboratoire', city: 'Casablanca', website: 'https://www.laprophan.ma' },
  { name: 'Maphar', type: 'laboratoire', city: 'Casablanca', website: 'https://www.maphar.ma' },
  { name: 'Bottu', type: 'laboratoire', city: 'Casablanca' },
  { name: 'Galenica', type: 'laboratoire', city: 'Casablanca' },
  { name: 'Promopharm', type: 'laboratoire', city: 'Casablanca' },
  // ---- R├®partition / grossiste ----
  { name: 'Cophat', type: 'grossiste', city: 'Casablanca', website: 'https://www.cophat.ma' },
  // ---- Filiales marocaines de laboratoires internationaux ----
  { name: 'Sanofi Maroc', type: 'laboratoire', city: 'Casablanca' },
  { name: 'Novartis Maroc', type: 'laboratoire', city: 'Casablanca' },
  { name: 'Pfizer Maroc', type: 'laboratoire', city: 'Casablanca' },
  { name: 'GSK Maroc', type: 'laboratoire', city: 'Casablanca' },
  { name: 'AstraZeneca Maroc', type: 'laboratoire', city: 'Casablanca' },
  { name: 'Servier Maroc', type: 'laboratoire', city: 'Casablanca' },
  { name: 'Janssen Maroc', type: 'laboratoire', city: 'Casablanca' },
  { name: 'Bayer Maroc', type: 'laboratoire', city: 'Casablanca' },
  { name: 'Boehringer Ingelheim Maroc', type: 'laboratoire', city: 'Casablanca' },
  { name: 'Roche Maroc', type: 'laboratoire', city: 'Casablanca' },
  { name: 'Merck Maroc', type: 'laboratoire', city: 'Casablanca' },
  { name: 'Viatris Maroc', type: 'laboratoire', city: 'Casablanca' },
  { name: 'Biogaran', type: 'laboratoire', city: 'Casablanca' },
  { name: 'Zentiva Maroc', type: 'laboratoire', city: 'Casablanca' },
  { name: 'Hikma Maroc', type: 'laboratoire', city: 'Casablanca' },
];

const pharmacyArg = process.argv.find((a) => a.startsWith('--pharmacy='));
const pharmacyFilter = pharmacyArg ? pharmacyArg.split('=')[1] : null;

const { rows: pharmacies } = pharmacyFilter
  ? await client.query('SELECT id, name FROM pharmacies WHERE id = $1', [pharmacyFilter])
  : await client.query('SELECT id, name FROM pharmacies WHERE status = $1', ['active']);

if (pharmacies.length === 0) {
  process.stdout.write('Aucune pharmacie cible trouv├®e ÔÇö rien ├á importer.\n');
  await client.end();
  process.exit(0);
}

let inserted = 0;
let skipped = 0;
for (const ph of pharmacies) {
  for (const s of MOROCCO_SUPPLIERS) {
    const exists = await client.query(
      `SELECT 1 FROM suppliers WHERE pharmacy_id = $1 AND lower(name) = lower($2) LIMIT 1`,
      [ph.id, s.name],
    );
    if (exists.rowCount > 0) {
      skipped++;
      continue; // NE PAS ├®craser les fournisseurs d├®j├á pr├®sents.
    }
    await client.query(
      `INSERT INTO suppliers (id, pharmacy_id, name, type, city, website, status, notes)
       VALUES ($1,$2,$3,$4,$5,$6,'active',$7)`,
      [
        randomUUID(),
        ph.id,
        s.name,
        s.type,
        s.city ?? null,
        s.website ?? null,
        'Base initiale Maroc ÔÇö contacts et ICE ├á compl├®ter (sources publiques).',
      ],
    );
    inserted++;
  }
  process.stdout.write(`ÔûÂ ${ph.name} : +${MOROCCO_SUPPLIERS.length} fournisseurs contr├┤l├®s\n`);
}

process.stdout.write(`\nTermin├® : ${inserted} ins├®r├®(s), ${skipped} d├®j├á pr├®sent(s) (ignor├®s).\n`);
await client.end();
