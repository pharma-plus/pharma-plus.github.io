#!/usr/bin/env node
// ============================================================
// IMPORT medicament.ma → reference_products (PHARMA+)
// ============================================================
// · Cible UNIQUEMENT le référentiel : reference_products,
//   reference_sync_runs, reference_product_updates,
//   reference_product_provenance. Jamais medications/stock/ventes.
// · Idempotent : id = uuid5(NS, medicament_id) → 2e import = 0 création.
// · Transaction unique : toute erreur → ROLLBACK total.
// · Aucune suppression, aucun UPDATE de produit existant.
// · Les 27 lignes exclues au dry-run (26 conflits labo +
//   1 correspondance probable) ne sont JAMAIS importées.
// · Aucune donnée inventée : champs absents = NULL.
//
// Usage : node backend/scripts/import_medicament_ma.mjs [--dry]
//   --dry = plan uniquement, AUCUNE écriture.
// ============================================================
import { readFileSync } from 'node:fs';
import { createHash, randomUUID } from 'node:crypto';

const DRY = process.argv.includes('--dry');
const SRC = 'C:/medicament_ma_extraction/';
const PG = 'file:///C:/Users/Merouan/Documents/Default Project/pharma-maroc-gold/backend/node_modules/pg/lib/index.js';
const BATCH = 200;

/* ---------- utilitaires ---------- */
function parseCSV(txt) {
  const lines = txt.split('\n').filter((l) => l.trim());
  const header = lines[0].split(',').map((h) => h.trim());
  const rows = [];
  for (const line of lines.slice(1)) {
    const out = []; let cur = '', q = false;
    for (let i = 0; i < line.length; i++) {
      const ch = line[i];
      if (q) { if (ch === '"') { if (line[i + 1] === '"') { cur += '"'; i++; } else q = false; } else cur += ch; }
      else if (ch === '"') q = true;
      else if (ch === ',') { out.push(cur); cur = ''; } else cur += ch;
    }
    out.push(cur);
    const row = {}; header.forEach((h, i) => row[h] = (out[i] ?? '').trim());
    rows.push(row);
  }
  return rows;
}
const norm = (s) => (s ?? '').normalize('NFD').replace(/\p{M}/gu, '').replace(/\s+/g, ' ').trim().toUpperCase();
const mkey = (s) => norm(s).replace(/[^A-Z0-9]/g, '');
function uuid5(namespace, name) {
  const ns = Buffer.from(namespace.replace(/-/g, ''), 'hex');
  const hash = createHash('sha1').update(Buffer.concat([ns, Buffer.from(name, 'utf8')])).digest();
  hash[6] = (hash[6] & 0x0f) | 0x50;
  hash[8] = (hash[8] & 0x3f) | 0x80;
  const h = hash.toString('hex', 0, 16);
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20, 32)}`;
}
const NS = uuid5('6ba7b810-9dad-11d1-80b4-00c04fd430c8', 'medicament.ma'); // 184da714-105b-5658-b124-70d0f4f8e932
const parsePrice = (v) => { if (!v) return null; const n = Number(v.replace(/\s/g, '').replace(',', '.')); return Number.isFinite(n) ? n : null; };

/* ---------- nettoyage labo (3 cas objectifs validés en dry-run) ---------- */
const OBJ_PREFIX = /(carton|flacon|bo[iî]te|dose|comprim|sachet|uniquement|solution|intravitr|\d)/i;
const srcLabs = parseCSV(readFileSync(SRC + 'laboratoires.csv', 'utf8'));
const srcLabOriginals = new Set(srcLabs.map((l) => l.nom_original));
function cleanLab(raw) {
  if (!raw) return { lab: null, original: null };
  const idx = raw.lastIndexOf(' - ');
  if (idx > 0) {
    const prefix = raw.slice(0, idx).trim(), suffix = raw.slice(idx + 3).trim();
    if (OBJ_PREFIX.test(prefix) && suffix !== raw && srcLabOriginals.has(suffix))
      return { lab: suffix, original: raw };
  }
  return { lab: raw, original: null };
}

/* ---------- chargement source ---------- */
const src = parseCSV(readFileSync(SRC + 'medicaments_clean.csv', 'utf8'));
if (src.length !== 5036) { console.error(`ARRET : ${src.length} lignes source (attendu 5036)`); process.exit(2); }

/* ---------- connexion + pré-vérifications ---------- */
const env = readFileSync('C:/Users/Merouan/Documents/Default Project/pharma-maroc-gold/backend/.env', 'utf8');
const kv = (k) => env.split('\n').map((l) => l.trim()).find((l) => l.startsWith(k + '='))?.slice(k.length + 1).trim().replace(/^"|"$/g, '');
const mod = await import(PG);
const { Client } = mod.default ?? mod;
const c = new Client({ connectionString: kv('DATABASE_URL').replace(/[?&]sslmode=[^&]*/g, ''), ssl: { rejectUnauthorized: false } });
await c.connect();

const guard = async (sql, label) => {
  const r = await c.query(sql);
  if (!r.rows.length) { console.error(`ARRET : ${label}`); await c.end(); process.exit(3); }
};
await guard(`SELECT 1 FROM information_schema.columns WHERE table_name='reference_products' AND column_name='ppc'`, 'migration 931 (ppc) non appliquée');
await guard(`SELECT 1 FROM information_schema.tables WHERE table_name='reference_product_provenance'`, 'migration 932 (provenance) non appliquée');

// Matching UNIQUEMENT contre les références des autres sources :
// les lignes déjà importées (source='medicament.ma') ne doivent pas
// participer au classement → classification stable = idempotence.
const refs = (await c.query(`SELECT id, name, laboratory FROM reference_products WHERE source <> 'medicament.ma'`)).rows;
const refByNorm = new Map();
for (const r of refs) { const k = mkey(r.name); if (!refByNorm.has(k)) refByNorm.set(k, []); refByNorm.get(k).push(r); }

/* ---------- classification identique au dry-run ---------- */
const cls = { A: 0, B: 0, C: 0, D: 0, E: 0, F: 0 };
const excluded = [];
const plan = [];
for (const r of src) {
  if (!r.medicament_id || !r.nom_commercial) { console.error('ARRET : ligne source invalide', r.medicament_id); await c.end(); process.exit(4); }
  const { lab, original } = cleanLab(r.laboratoire_nom);
  const nk = mkey(r.nom_commercial);
  const exact = refByNorm.get(nk) ?? [];
  let category;
  if (exact.length > 1) category = 'D';
  else if (exact.length === 1) {
    const ref = exact[0];
    const a = norm(lab), b = norm(ref.laboratory);
    category = (a && b && a !== b) ? 'F' : 'B';
  } else if (r.doublon_classe !== 'UNIQUE') category = 'E';
  else {
    const cands = refs.filter((rf) => { const rk = mkey(rf.name); return nk.length >= 8 && rk.length >= 8 && (rk.includes(nk) || nk.includes(rk)); });
    category = cands.length === 1 ? 'C' : cands.length > 1 ? 'D' : 'A';
  }
  cls[category]++;
  const insert = category === 'A' || category === 'E';
  if (!insert) { excluded.push({ name: r.nom_commercial, category, lab_source: r.laboratoire_nom || null }); continue; }
  plan.push({
    id: uuid5(NS, r.medicament_id),
    row: {
      id: uuid5(NS, r.medicament_id),
      category_code: null, name: r.nom_commercial, dci: null, substance_active: null,
      dosage: r.dosage || null, form: r.forme || null, presentation: r.presentation || null,
      laboratory: lab, therapeutic_class: null, commercial_status: r.statut || null,
      amm_number: null, code_produit: r.source_id || null, barcode_ean13: null, qr_code: null,
      ppv: parsePrice(r.prix_public_dhs), ph: parsePrice(r.prix_ph_dhs), pfht: null,
      ppc: parsePrice(r.prix_ppc_dhs), tva_rate: null, rcp_url: null, notice_url: null,
      source: 'medicament.ma', source_updated_at: null,
    },
    prov: {
      source: 'medicament.ma', medicament_id: r.medicament_id, source_id: r.source_id || null,
      source_url: r.source_url || null, source_file: r.source_file || null, hash_source: r.hash_source || null,
      date_source: r.date_source ? new Date(r.date_source) : null,
      date_import: r.date_import ? new Date(r.date_import) : null,
      lettre_source: r.lettre_source || null, doublon_classe: r.doublon_classe,
      source_occurrences: Number(r.source_occurrences) || null,
      nom_original: r.nom_original || null, labo_source_original: (original ?? r.laboratoire_nom) || null,
      prix_original: r.prix_original || null, secondary_original: r.secondary_original || null,
      statut_source: r.statut || null,
    },
  });
}

/* ---------- gardeurs de cohérence avec le dry-run ---------- */
const insertCount = plan.length;
const excludedCount = excluded.length;
if (cls.A + cls.B + cls.C + cls.D + cls.E + cls.F !== 5036) { console.error('ARRET : classification incohérente', cls); await c.end(); process.exit(5); }
if (insertCount !== 5009 || excludedCount !== 27) {
  console.error(`ARRET : plan ${insertCount} créations / ${excludedCount} exclusions (dry-run attendu : 5009 / 27)`, cls);
  await c.end(); process.exit(6);
}

console.log(JSON.stringify({ phase: DRY ? 'DRY (aucune écriture)' : 'IMPORT', classification: cls, a_creer: insertCount, a_ignorer: excludedCount }));

if (DRY) {
  console.log('Exclus:', JSON.stringify(excluded.slice(0, 30)));
  await c.end();
  process.exit(0);
}

/* ---------- idempotence : exclusion des ids déjà présents ---------- */
const allIds = plan.map((p) => p.id);
const existing = new Set();
for (let i = 0; i < allIds.length; i += 1000) {
  const chunk = allIds.slice(i, i + 1000);
  const r = await c.query(`SELECT id FROM reference_products WHERE id = ANY($1::uuid[])`, [chunk]);
  r.rows.forEach((x) => existing.add(x.id));
}
const todo = plan.filter((p) => !existing.has(p.id));
const skippedExisting = plan.length - todo.length;
console.log(JSON.stringify({ deja_existants: skippedExisting, a_inserer_maintenant: todo.length }));

/* ---------- TRANSACTION ---------- */
const runId = randomUUID();
const t0 = Date.now();
try {
  await c.query('BEGIN');
  await c.query(
    `INSERT INTO reference_sync_runs (id, source, status) VALUES ($1, 'medicament.ma', 'running')`,
    [runId],
  );
  const pCols = ['id', 'category_code', 'name', 'dci', 'substance_active', 'dosage', 'form', 'presentation', 'laboratory', 'therapeutic_class', 'commercial_status', 'amm_number', 'code_produit', 'barcode_ean13', 'qr_code', 'ppv', 'ph', 'pfht', 'ppc', 'tva_rate', 'rcp_url', 'notice_url', 'source', 'source_updated_at'];
  const pType = { id: 'uuid', category_code: 'text', name: 'text', dci: 'text', substance_active: 'text', dosage: 'text', form: 'text', presentation: 'text', laboratory: 'text', therapeutic_class: 'text', commercial_status: 'text', amm_number: 'text', code_produit: 'text', barcode_ean13: 'text', qr_code: 'text', ppv: 'numeric', ph: 'numeric', pfht: 'numeric', ppc: 'numeric', tva_rate: 'numeric', rcp_url: 'text', notice_url: 'text', source: 'text', source_updated_at: 'timestamptz' };
  for (let i = 0; i < todo.length; i += BATCH) {
    const batch = todo.slice(i, i + BATCH);
    const vals = [], params = [];
    let n = 0;
    for (const p of batch) {
      vals.push(`(${pCols.map((_, j) => `$${n * pCols.length + j + 1}::${pType[pCols[j]]}`).join(',')})`);
      params.push(...pCols.map((k) => p.row[k]));
      n++;
    }
    await c.query(`INSERT INTO reference_products (${pCols.join(',')}) VALUES ${vals.join(',')}`, params);
  }
  let updRows = 0;
  for (let i = 0; i < todo.length; i += BATCH) {
    const batch = todo.slice(i, i + BATCH);
    const vals = [], params = [];
    let n = 0;
    for (const p of batch) {
      vals.push(`($${n * 3 + 1}::uuid,$${n * 3 + 2}::uuid,NULL::text,$${n * 3 + 3}::text,'new','{}'::jsonb)`);
      params.push(runId, p.id, p.row.name);
      n++;
    }
    await c.query(`INSERT INTO reference_product_updates (sync_run_id, product_id, barcode, name, change_type, fields) VALUES ${vals.join(',')}`, params);
    updRows += batch.length;
  }
  let provRows = 0;
  const vCols = ['reference_id', 'source', 'medicament_id', 'source_id', 'source_url', 'source_file', 'hash_source', 'date_source', 'date_import', 'lettre_source', 'doublon_classe', 'source_occurrences', 'nom_original', 'labo_source_original', 'prix_original', 'secondary_original', 'statut_source'];
  const vType = { reference_id: 'uuid', source: 'text', medicament_id: 'text', source_id: 'text', source_url: 'text', source_file: 'text', hash_source: 'text', date_source: 'timestamptz', date_import: 'timestamptz', lettre_source: 'text', doublon_classe: 'text', source_occurrences: 'integer', nom_original: 'text', labo_source_original: 'text', prix_original: 'text', secondary_original: 'text', statut_source: 'text' };
  for (let i = 0; i < todo.length; i += BATCH) {
    const batch = todo.slice(i, i + BATCH);
    const vals = [], params = [];
    let n = 0;
    for (const p of batch) {
      vals.push(`(${vCols.map((_, j) => `$${n * vCols.length + j + 1}::${vType[vCols[j]]}`).join(',')})`);
      params.push(...vCols.map((k) => k === 'reference_id' ? p.id : p.prov[k]));
      n++;
    }
    await c.query(`INSERT INTO reference_product_provenance (${vCols.join(',')}) VALUES ${vals.join(',')}`, params);
    provRows += batch.length;
  }
  const notes = JSON.stringify({ plan: insertCount, crees: todo.length, ignores_exclus: excludedCount, deja_existants: skippedExisting, doublons_source_importes: cls.E });
  await c.query(
    `UPDATE reference_sync_runs SET status='completed', finished_at=now(), new_count=$1, modified_count=0, price_changed_count=0, status_changed_count=0, removed_count=0, notes=$2 WHERE id=$3`,
    [todo.length, notes, runId],
  );
  await c.query('COMMIT');
  console.log(JSON.stringify({
    resultat: 'IMPORT OK', run_id: runId, reference_products_crees: todo.length,
    reference_product_updates: updRows, provenance: provRows, secondes: Math.round((Date.now() - t0) / 100),
    exclus: excludedCount, exclus_detail: excluded.map((e) => `${e.category}:${e.name}`),
  }, null, 1));
} catch (err) {
  await c.query('ROLLBACK').catch(() => {});
  const msg = String(err?.message ?? err).slice(0, 450);
  console.error('ROLLBACK EFFECTUE — aucune écriture partielle. Erreur:', msg);
  try {
    await c.query(
      `INSERT INTO reference_sync_runs (id, source, status, finished_at, new_count, modified_count, price_changed_count, status_changed_count, removed_count, notes) VALUES ($1,'medicament.ma','failed',now(),0,0,0,0,0,$2)`,
      [randomUUID(), `ECHEC IMPORT (rollback total): ${msg}`],
    );
    console.error('Echec journalisé dans reference_sync_runs.');
  } catch (e2) {
    console.error('Journalisation echec impossible:', String(e2?.message ?? e2));
  }
  await c.end();
  process.exit(1);
}
await c.end();
console.log('IMPORT_TERMINE');
