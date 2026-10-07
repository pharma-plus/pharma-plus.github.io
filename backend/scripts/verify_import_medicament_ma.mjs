#!/usr/bin/env node
// ============================================================
// VÉRIFICATIONS POST-IMPORT medicament.ma (LECTURE SEULE)
// · SQL : compteurs, ppc, provenance, runs, journal, exclues(27),
//   non-régression métier (empreintes vs baseline).
// · API Edge : login runtime (SUPER_ADMIN_* de .env, jamais affiché),
//   GET /reference/products (+recherche nom), détail, catalog,
//   recherche POS, barcode. Si login impossible → NON EXÉCUTÉ.
// ============================================================
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';

const B = JSON.parse(readFileSync('C:/Users/Merouan/AppData/Local/Temp/opencode/baseline_avant.json', 'utf8'));
const SRC = 'C:/medicament_ma_extraction/';
const PG = 'file:///C:/Users/Merouan/Documents/Default Project/pharma-maroc-gold/backend/node_modules/pg/lib/index.js';
const BASE = 'https://lwepnnecnrqdzadesyqo.supabase.co/functions/v1/pharma-api/api/v1';

const results = [];
const check = (n, ok, d) => { results.push({ n, ok: ok === null ? null : !!ok, d }); console.log(`${ok === null ? 'NON EXÉCUTÉ' : ok ? 'PASS' : 'FAIL'} | ${n} | ${d}`); };

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
  hash[6] = (hash[6] & 0x0f) | 0x50; hash[8] = (hash[8] & 0x3f) | 0x80;
  const h = hash.toString('hex', 0, 16);
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20, 32)}`;
}
const NS = uuid5('6ba7b810-9dad-11d1-80b4-00c04fd430c8', 'medicament.ma');

/* ---------- SQL ---------- */
const mod = await import(PG);
const { Client } = mod.default ?? mod;
const env = readFileSync('C:/Users/Merouan/Documents/Default Project/pharma-maroc-gold/backend/.env', 'utf8');
const kv = (k) => env.split('\n').map((l) => l.trim()).find((l) => l.startsWith(k + '='))?.slice(k.length + 1).trim().replace(/^"|"$/g, '');
const c = new Client({ connectionString: kv('DATABASE_URL').replace(/[?&]sslmode=[^&]*/g, ''), ssl: { rejectUnauthorized: false } });
await c.connect();
const one = async (s, p) => (await c.query(s, p)).rows[0];

/* T1 — reference_products total */
const refTotal = (await one(`SELECT count(*)::int AS n FROM reference_products`)).n;
check('reference_products total', refTotal === 5054, `${refTotal} (45 + 5009 attendu = 5054)`);

/* T2 — 5009 produits importés = exactement le plan (set equality) */
const src = parseCSV(readFileSync(SRC + 'medicaments_clean.csv', 'utf8'));
const refsOfficial = (await c.query(`SELECT name, laboratory FROM reference_products WHERE source <> 'medicament.ma'`)).rows;
const refByKey = new Map();
for (const r of refsOfficial) { const k = mkey(r.name); if (!refByKey.has(k)) refByKey.set(k, []); refByKey.get(k).push(r); }
const srcLabs = parseCSV(readFileSync(SRC + 'laboratoires.csv', 'utf8'));
const labSet = new Set(srcLabs.map((l) => l.nom_original));
const OBJ = /(carton|flacon|bo[iî]te|dose|comprim|sachet|uniquement|solution|intravitr|\d)/i;
function cleanLab(raw) {
  if (!raw) return null;
  const i = raw.lastIndexOf(' - ');
  if (i > 0) { const p = raw.slice(0, i).trim(), s = raw.slice(i + 3).trim(); if (OBJ.test(p) && s !== raw && labSet.has(s)) return s; }
  return raw;
}
const planIds = new Set(), excludedIds = new Set();
let expPpv = 0, expPh = 0, expPpc = 0;
const num = (v) => { if (!v) return false; return Number.isFinite(Number(v.replace(/\s/g, '').replace(',', '.'))); };
for (const r of src) {
  const lab = cleanLab(r.laboratoire_nom);
  const nk = mkey(r.nom_commercial);
  const exact = refByKey.get(nk) ?? [];
  let cat;
  if (exact.length > 1) cat = 'D';
  else if (exact.length === 1) { const a = norm(lab), b = norm(exact[0].laboratory); cat = (a && b && a !== b) ? 'F' : 'B'; }
  else if (r.doublon_classe !== 'UNIQUE') cat = 'E';
  else { const cands = refsOfficial.filter((rf) => { const rk = mkey(rf.name); return nk.length >= 8 && rk.length >= 8 && (rk.includes(nk) || nk.includes(rk)); }); cat = cands.length === 1 ? 'C' : cands.length > 1 ? 'D' : 'A'; }
  const id = uuid5(NS, r.medicament_id);
  if (cat === 'A' || cat === 'E') {
    planIds.add(id);
    if (num(r.prix_public_dhs)) expPpv++;
    if (num(r.prix_ph_dhs)) expPh++;
    if (num(r.prix_ppc_dhs)) expPpc++;
  } else excludedIds.add(id);
}
const dbIds = new Set((await c.query(`SELECT id::text AS id FROM reference_products WHERE source='medicament.ma'`)).rows.map((r) => r.id));
let missing = 0, extra = 0;
for (const id of planIds) if (!dbIds.has(id)) missing++;
for (const id of dbIds) if (!planIds.has(id)) extra++;
check('5009 produits importés (égalité de ensemble exacte)', planIds.size === 5009 && dbIds.size === 5009 && missing === 0 && extra === 0,
  `plan=${planIds.size} db=${dbIds.size} manquants=${missing} étrangers=${extra}`);
let exclPresent = 0;
for (const id of excludedIds) if (dbIds.has(id)) exclPresent++;
check('27 exclus absents de la base', exclPresent === 0, `${exclPresent} exclue(s) trouvée(s) — attendu 0`);

/* T3 — ppc */
const ppc = await one(`SELECT count(ppc) AS avec, count(*) FILTER (WHERE source='medicament.ma') AS imported, count(*) FILTER (WHERE source<>'medicament.ma' AND ppc IS NOT NULL) AS vieux_ppc FROM reference_products`);
check('ppc renseigné sur les importés', Number(ppc.avec) === expPpc, `${ppc.avec}/${expPpc} (attendu = PPC des lignes importées)`);
check('ppc NULL sur les 45 références existantes', Number(ppc.vieux_ppc) === 0, `${ppc.vieux_ppc} vieux avec ppc`);

/* T4 — provenance */
const prov = await one(`SELECT count(*)::int AS n FROM reference_product_provenance`);
check('provenance complète', prov.n === 5009, `${prov.n} lignes`);
const provSample = await one(`SELECT p.medicament_id, p.source, p.doublon_classe, p.labo_source_original, p.hash_source IS NOT NULL AS h, p.source_url IS NOT NULL AS u FROM reference_product_provenance p JOIN reference_products r ON r.id=p.reference_id ORDER BY p.medicament_id LIMIT 1`);
check('provenance contenu (medicament_id, source, hash, url)', provSample.source === 'medicament.ma' && provSample.h && provSample.u, JSON.stringify(provSample));
const cleaned = await one(`SELECT count(*)::int AS n FROM reference_product_provenance WHERE labo_source_original IN ('Carton de 12 - LAPROPHAN','uniquement intravitréenne - BAYER S.A','Flacon de 120 doses - SYNTHEMEDIC')`);
check('3 nettoyages labo avec original conservé', cleaned.n === 3, `${cleaned.n}/3`);

/* T5 — reference_sync_runs */
const runs = (await c.query(`SELECT source, status, new_count, notes FROM reference_sync_runs ORDER BY started_at`)).rows;
const okRuns = runs.some((r) => r.status === 'completed' && r.new_count === 5009) && runs.some((r) => r.status === 'completed' && r.new_count === 0) && runs.some((r) => r.status === 'failed');
check('reference_sync_runs (1 échec journalisé + 1 import 5009 + 1 idempotence 0)', okRuns, JSON.stringify(runs.map((r) => `${r.source}:${r.status}:${r.new_count}`)));

/* T6 — reference_product_updates */
const upd = await one(`SELECT count(*)::int AS total, count(*) FILTER (WHERE u.change_type='new' AND r.source='medicament.ma') AS news FROM reference_product_updates u LEFT JOIN reference_products r ON r.id=u.product_id`);
check('reference_product_updates', upd.total === 5054 && Number(upd.news) === 5009, `total=${upd.total} (45+5009), new importés=${upd.news}`);
const updOld = await one(`SELECT count(*)::int AS n FROM reference_product_updates u JOIN reference_products r ON r.id=u.product_id WHERE r.source <> 'medicament.ma' AND u.sync_run_id IN (SELECT id FROM reference_sync_runs WHERE source='medicament.ma')`);
check('aucun journal sur les 45 références existantes', updOld.n === 0, `${updOld.n}`);

/* T7 — données non inventées */
const noInv = await one(`SELECT count(*) FILTER (WHERE dci IS NOT NULL) AS dci, count(*) FILTER (WHERE barcode_ean13 IS NOT NULL) AS bc, count(*) FILTER (WHERE tva_rate IS NOT NULL) AS tva, count(*) FILTER (WHERE category_code IS NOT NULL) AS cat, count(*) FILTER (WHERE commercial_status IS NULL) AS statut_null, count(*) FILTER (WHERE laboratory IS NULL) AS lab_null FROM reference_products WHERE source='medicament.ma'`);
check('aucune donnée inventée (DCI/EAN/TVA/catégorie = NULL)', Number(noInv.dci) === 0 && Number(noInv.bc) === 0 && Number(noInv.tva) === 0 && Number(noInv.cat) === 0,
  `dci=${noInv.dci} barcode=${noInv.bc} tva=${noInv.tva} cat=${noInv.cat} | statut_null=${noInv.statut_null} lab_null=${noInv.lab_null}`);
const pr = await one(`SELECT count(ppv) AS ppv, count(ph) AS ph, count(ppc) AS ppc FROM reference_products WHERE source='medicament.ma'`);
check('prix importés PPV/PH/PPC (vs source attendue)', Number(pr.ppv) === expPpv && Number(pr.ph) === expPh && Number(pr.ppc) === expPpc,
  `ppv=${pr.ppv}/${expPpv} ph=${pr.ph}/${expPh} ppc=${pr.ppc}/${expPpc}`);
const pfhtNull = await one(`SELECT count(pfht) AS n FROM reference_products WHERE source='medicament.ma' AND pfht IS NOT NULL`);
check('pfht jamais utilisé pour PPC', Number(pfhtNull.n) === 0, `${pfhtNull.n} pfht non-null`);

/* T8-T18 — NON-RÉGRESSION (compteurs + empreintes vs baseline) */
for (const t of ['medications', 'stock_balances', 'stock_movements', 'lots', 'sales', 'sale_items', 'purchase_orders', 'customers', 'suppliers', 'laboratories', 'categories']) {
  const n = (await one(`SELECT count(*)::int AS n FROM ${t}`)).n;
  check(`non-régression ${t}`, n === B.counts[t], `avant=${B.counts[t]} après=${n}`);
}
const stock = await one(`SELECT COALESCE(sum(quantity),0)::text AS qty, count(*)::int AS lignes, count(DISTINCT medication_id)::int AS meds FROM stock_balances`);
check('stock total identique', stock.qty === B.stock.qty && stock.lignes === B.stock.lignes, `avant=${B.stock.qty} après=${stock.qty}`);
const fpCols = {
  medications: `SELECT md5(string_agg(id::text || '|' || name || '|' || price_sale || '|' || price_purchase || '|' || COALESCE(barcode_ean13,'') || '|' || laboratory_id, ',' ORDER BY id::text)) AS m FROM medications`,
  stock_balances: `SELECT md5(string_agg(id::text || '|' || medication_id || '|' || quantity || '|' || COALESCE(lot_id::text,''), ',' ORDER BY id::text)) AS m FROM stock_balances`,
  lots: `SELECT md5(string_agg(id::text || '|' || medication_id || '|' || lot_number || '|' || COALESCE(cost_price::text,'') || '|' || COALESCE(expiry_date::text,''), ',' ORDER BY id::text)) AS m FROM lots`,
  sales: `SELECT md5(string_agg(id::text || '|' || number || '|' || total::text, ',' ORDER BY id::text)) AS m FROM sales`,
  sale_items: `SELECT md5(string_agg(id::text || '|' || medication_id || '|' || quantity || '|' || unit_price, ',' ORDER BY id::text)) AS m FROM sale_items`,
  suppliers: `SELECT md5(string_agg(id::text || '|' || name, ',' ORDER BY id::text)) AS m FROM suppliers`,
  customers: `SELECT md5(string_agg(id::text || '|' || name, ',' ORDER BY id::text)) AS m FROM customers`,
};
for (const [t, sql] of Object.entries(fpCols)) {
  const m = (await one(sql)).m;
  check(`empreinte ${t} identique`, m === B.fingerprints[t], `md5 ${m.slice(0, 8)}… vs ${B.fingerprints[t].slice(0, 8)}…`);
}
const barcodes = await one(`SELECT count(barcode_ean13) AS n FROM medications`);
check('EAN produits existants intacts', Number(barcodes.n) === 7, `${barcodes.n}/7`);

/* ---------- API EDGE ---------- */
console.log('\n--- API EDGE ---');
let token = null;
try {
  const email = kv('SUPER_ADMIN_EMAIL'), password = kv('SUPER_ADMIN_PASSWORD');
  const r = await fetch(BASE + '/auth/login', {
    method: 'POST', headers: { 'accept': 'application/json', 'content-type': 'application/json' },
    body: JSON.stringify({ email, password, device: { name: 'Flutter', type: 'mobile', userAgent: 'pmg-app' } }),
  });
  const j = await r.json().catch(() => ({}));
  token = j?.data?.accessToken || j?.data?.access_token || j?.access_token || null;
  check('login Edge (SUPER_ADMIN)', !!token, `HTTP ${r.status}`);
} catch (e) { check('login Edge (SUPER_ADMIN)', false, String(e.message).slice(0, 80)); }

const api = async (p) => {
  try {
    const r = await fetch(BASE + p, { headers: { 'accept': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) } });
    const j = await r.json().catch(() => ({}));
    return { s: r.status, j };
  } catch (e) { return { s: 0, j: { err: e.message } }; }
};

if (token) {
  const t1 = await api('/reference/products?limit=5');
  check('GET /reference/products', t1.s === 200 && Array.isArray(t1.j.data) && t1.j.meta?.total === 5054, `HTTP ${t1.s}, total=${t1.j.meta?.total}`);
  const t2 = await api('/reference/products?q=' + encodeURIComponent('Doliprane') + '&limit=10');
  check('recherche par nom (q)', t2.s === 200 && (t2.j.data?.length ?? 0) > 0, `HTTP ${t2.s}, ${t2.j.data?.length} résultats Doliprane`);
  const t3 = await api('/reference/products?q=' + encodeURIComponent('PARACETAMOL') + '&limit=10');
  check('recherche par DCI/nom importé (q=Doliprane1000)', t3.s === 200, `HTTP ${t3.s}, ${t3.j.data?.length} résultats`);
  const someId = dbIds.values().next().value;
  const t4 = await api(`/reference/products/${someId}`);
  check('GET /reference/products/:id', t4.s === 200 && t4.j.data?.source === 'medicament.ma', `HTTP ${t4.s}`);
  const t5 = await api('/catalog/medications?q=' + encodeURIComponent('Doliprane') + '&limit=10');
  const arr5 = Array.isArray(t5.j) ? t5.j : (t5.j?.data ?? []);
  check('GET /catalog/medications (recherche POS)', t5.s === 200 && arr5.length > 0, `HTTP ${t5.s}, ${arr5.length} résultat(s)`);
  // Scanner réel de l'app = route q= (barcode_ean13.ilike, index.ts:421)
  const t6 = await api('/catalog/medications?q=3400936055412&limit=5');
  const arr6 = Array.isArray(t6.j) ? t6.j : (t6.j?.data ?? []);
  check('scanner EAN via q= (chemin réel de l app)', t6.s === 200 && arr6.length > 0, `HTTP ${t6.s}, ${arr6.length} résultat(s) Doliprane`);
  // Route dédiée /barcode/:code — BUG PRÉ-EXISTANT index.ts:2689 (extraction du chemin
  // renvoie le chemin complet, 0 ligne) — index.ts inchangé depuis 0883962, non lié à l'import.
  const t6b = await api('/catalog/medications/barcode/3400936079228');
  const arr6b = Array.isArray(t6b.j) ? t6b.j : (t6b.j?.data ?? []);
  check('route dédiée /barcode/:code (BUG PRÉ-EXISTANT)', arr6b.length > 0,
    `HTTP ${t6b.s}, ${arr6b.length} résultat(s) — échec dû à index.ts:2689, fichier identique au backup 0883962`);
  const t7 = await api('/reference/categories');
  check('GET /reference/categories (non cassé)', t7.s === 200, `HTTP ${t7.s}, ${t7.j.data?.length} catégories`);
  // recherche labo/prix : filtres non exposés par Edge (design existant) → niveau données
} else {
  for (const n of ['GET /reference/products', 'recherche par nom', 'détail produit', 'GET /catalog/medications', 'recherche POS', 'scanner/barcode', 'reference/categories'])
    check(n, null, 'login Edge indisponible (aucun identifiant exécutable dans ce contexte)');
}
/* Recherche labo/prix — vérifiée au niveau données (Edge n'expose pas ces filtres) */
const labQ = await one(`SELECT count(*)::int AS n FROM reference_products WHERE source='medicament.ma' AND laboratory ILIKE '%SOTHEMA%'`);
check('recherche par laboratoire (données)', labQ.n > 0, `${labQ.n} lignes SOTHEMA`);
const priceQ = await one(`SELECT count(*)::int AS n FROM reference_products WHERE ppc >= 10 AND ppc <= 100 AND source='medicament.ma'`);
check('recherche par prix PPC (données)', priceQ.n > 0, `${priceQ.n} lignes PPC 10-100 MAD`);

const pass = results.filter((r) => r.ok === true).length, fail = results.filter((r) => r.ok === false).length, skip = results.filter((r) => r.ok === null).length;
console.log(`\nRESULTATS: ${pass} PASS / ${fail} FAIL / ${skip} NON EXÉCUTÉ`);
await c.end();
