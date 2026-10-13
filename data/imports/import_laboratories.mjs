// Import LABORATOIRES — idempotent, dry-run par défaut, rapport obligatoire.
// Usage : node import_laboratories.mjs [chemin_csv]  → dry-run
//         node import_laboratories.mjs [chemin_csv] --apply  → écriture
// Source par défaut : C:\medicament_ma_extraction\laboratoires.csv (medicament.ma)
import { createRequire } from "node:module";
const require = createRequire("C:/Users/Merouan/Documents/Default Project/pharma-maroc-gold/backend/package.json");
const dotenv = require("dotenv");
dotenv.config({ path: "C:/Users/Merouan/Documents/Default Project/pharma-maroc-gold/backend/.env" });
const pg = (await import("file:///C:/Users/Merouan/Documents/Default Project/pharma-maroc-gold/backend/node_modules/pg/lib/index.js")).default;
import fs from "node:fs";
import path from "node:path";

const APPLY = process.argv.includes("--apply");
const CSV = process.argv.slice(2).find((a) => !a.startsWith("--")) ?? "C:\\medicament_ma_extraction\\laboratoires.csv";
const PID = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa";
const norm = (s) => String(s ?? "").normalize("NFD").replace(/[̀-ͯ]/g, "").toUpperCase().replace(/[^A-Z0-9]+/g, " ").trim();

function parseCsv(text) {
  const lines = text.split(/\r?\n/).filter((l) => l.trim());
  const header = lines[0].split(",").map((h) => h.trim().replace(/^"|"$/g, ""));
  return lines.slice(1).map((line) => {
    const cells = [];
    let cur = "", inQ = false;
    for (const ch of line) {
      if (ch === '"') inQ = !inQ;
      else if (ch === "," && !inQ) { cells.push(cur.trim()); cur = ""; }
      else cur += ch;
    }
    cells.push(cur.trim());
    const row = {};
    header.forEach((h, i) => row[h] = (cells[i] ?? "").replace(/^"|"$/g, ""));
    return row;
  });
}

const raw = process.env.DATABASE_URL;
const c = new pg.Client({ connectionString: raw.replace(/[?&]sslmode=[^&]*/g, ""), ssl: { rejectUnauthorized: false } });
await c.connect();

const rows = parseCsv(fs.readFileSync(CSV, "utf8"));
const { rows: existing } = await c.query(`SELECT id, name FROM laboratories WHERE pharmacy_id = $1`, [PID]);
const byNorm = new Map(existing.map((l) => [norm(l.name), l]));

const toCreate = [], already = [], variants = [];
for (const r of rows) {
  const name = (r.nom_original ?? r.name ?? "").trim();
  if (!name) continue;
  const k = norm(name);
  if (byNorm.has(k)) { already.push({ name, existing: byNorm.get(k).name }); continue; }
  // variante proche (même préfixe 6+ chars) → signalée, jamais fusionnée
  const close = existing.find((e) => {
    const ek = norm(e.name);
    return ek !== k && (ek.startsWith(k.slice(0, 8)) || k.startsWith(ek.slice(0, 8))) && k.length >= 8;
  });
  if (close) variants.push({ source: name, proche: close.name });
  toCreate.push({ name, source_id: r.laboratory_id ?? null, produits: Number(r.nombre_de_produits ?? 0) });
}

const ts = new Date().toISOString().replace(/[:T]/g, "").slice(0, 14);
const report = {
  import: "laboratories", source: CSV, mode: APPLY ? "APPLY" : "DRY-RUN",
  at: new Date().toISOString(),
  lignes_source: rows.length, existants: existing.length,
  a_creer: toCreate.length, deja_presents: already.length,
  variantes_signalees: variants, crees: [], erreurs: [],
};
console.log(`MODE: ${report.mode} | source: ${rows.length} labs | existants: ${existing.length} | à créer: ${toCreate.length} | déjà présents: ${already.length}`);
if (variants.length) console.log("VARIANTES (non fusionnées):", JSON.stringify(variants.slice(0, 10)));

if (APPLY && toCreate.length) {
  const backupPath = `reports/imports/laboratories_backup_${ts}.json`;
  fs.mkdirSync("reports/imports", { recursive: true });
  fs.writeFileSync(backupPath, JSON.stringify({ at: new Date().toISOString(), rows: existing }, null, 1));
  console.log("BACKUP:", backupPath);
  await c.query("BEGIN");
  try {
    for (const t of toCreate) {
      const ins = await c.query(
        `INSERT INTO laboratories (id, pharmacy_id, name) VALUES (gen_random_uuid(), $1, $2) RETURNING id`,
        [PID, t.name]);
      report.crees.push({ id: ins.rows[0].id, name: t.name, source_id: t.source_id, produits: t.produits });
    }
    await c.query("COMMIT");
  } catch (e) { await c.query("ROLLBACK"); report.erreurs.push(e.message); throw e; }
  console.log("CRÉÉS:", report.crees.length);
}

const repPath = `reports/imports/import_laboratories_${ts}.json`;
fs.writeFileSync(repPath, JSON.stringify(report, null, 1));
console.log("RAPPORT:", repPath);
await c.end();
