// Import FOURNISSEURS — idempotent, dry-run par défaut, rapport obligatoire.
// Usage : node import_suppliers.mjs chemin.csv [--apply]
// Colonnes : name (obligatoire), contact_name, email, phone, address, city,
//            tax_id, ice, website, whatsapp, type (laboratoire|grossiste|autre),
//            status (active|inactive), payment_terms, notes
// Règles : jamais de coordonnée inventée (champs absents = laissés intacts),
//          matching par nom normalisé, mises à jour uniquement des champs fournis.
import { createRequire } from "node:module";
const require = createRequire("C:/Users/Merouan/Documents/Default Project/pharma-maroc-gold/backend/package.json");
const dotenv = require("dotenv");
dotenv.config({ path: "C:/Users/Merouan/Documents/Default Project/pharma-maroc-gold/backend/.env" });
const pg = (await import("file:///C:/Users/Merouan/Documents/Default Project/pharma-maroc-gold/backend/node_modules/pg/lib/index.js")).default;
import fs from "node:fs";

const APPLY = process.argv.includes("--apply");
const CSV = process.argv.slice(2).find((a) => !a.startsWith("--"));
if (!CSV) { console.error("Usage: node import_suppliers.mjs chemin.csv [--apply]"); process.exit(1); }
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
const { rows: existing } = await c.query(`SELECT * FROM suppliers WHERE pharmacy_id = $1`, [PID]);
const byNorm = new Map(existing.map((s) => [norm(s.name), s]));

const creates = [], updates = [], already = [], rejects = [];
for (const r of rows) {
  const name = (r.name ?? "").trim();
  if (!name) { rejects.push({ ligne: r, motif: "nom manquant" }); continue; }
  const k = norm(name);
  const patch = {};
  for (const f of ["contact_name", "email", "phone", "address", "city", "tax_id", "ice", "website", "whatsapp", "type", "payment_terms", "notes"]) {
    if (r[f] !== undefined && String(r[f]).trim() !== "") patch[f] = String(r[f]).trim();
  }
  if (r.status && ["active", "inactive"].includes(r.status)) patch.status = r.status;
  const hit = byNorm.get(k);
  if (!hit) { creates.push({ name, patch }); continue; }
  const changed = Object.entries(patch).filter(([f, v]) => String(hit[f] ?? "") !== v);
  if (changed.length) updates.push({ id: hit.id, name: hit.name, changed: Object.fromEntries(changed) });
  else already.push(hit.name);
}

const ts = new Date().toISOString().replace(/[:T]/g, "").slice(0, 14);
const report = {
  import: "suppliers", source: CSV, mode: APPLY ? "APPLY" : "DRY-RUN",
  at: new Date().toISOString(), lignes_source: rows.length, existants: existing.length,
  a_creer: creates.length, a_mettre_a_jour: updates.length, inchanges: already.length,
  rejets: rejects.length, motifs_rejet: rejects, crees: [], mis_a_jour: [], erreurs: [],
};
console.log(`MODE: ${report.mode} | source: ${rows.length} | créer: ${creates.length} | maj: ${updates.length} | inchangés: ${already.length} | rejets: ${rejects.length}`);

if (APPLY) {
  const backupPath = `reports/imports/suppliers_backup_${ts}.json`;
  fs.mkdirSync("reports/imports", { recursive: true });
  fs.writeFileSync(backupPath, JSON.stringify({ at: new Date().toISOString(), rows: existing }, null, 1));
  console.log("BACKUP:", backupPath);
  await c.query("BEGIN");
  try {
    for (const cr of creates) {
      const ins = await c.query(
        `INSERT INTO suppliers (id, pharmacy_id, name, status, contact_name, email, phone, address, city, tax_id, ice, website, whatsapp, type, payment_terms, notes)
         VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15) RETURNING id`,
        [PID, cr.name, cr.patch.status ?? "active", cr.patch.contact_name ?? null, cr.patch.email ?? null,
         cr.patch.phone ?? null, cr.patch.address ?? null, cr.patch.city ?? null, cr.patch.tax_id ?? null,
         cr.patch.ice ?? null, cr.patch.website ?? null, cr.patch.whatsapp ?? null, cr.patch.type ?? "autre",
         cr.patch.payment_terms ?? null, cr.patch.notes ?? null]);
      report.crees.push({ id: ins.rows[0].id, name: cr.name });
    }
    for (const up of updates) {
      const sets = Object.keys(up.changed).map((f, i) => `${f} = $${i + 3}`).join(", ");
      await c.query(`UPDATE suppliers SET ${sets} WHERE id = $2 AND pharmacy_id = $1`, [PID, up.id, ...Object.values(up.changed)]);
      report.mis_a_jour.push(up);
    }
    await c.query("COMMIT");
  } catch (e) { await c.query("ROLLBACK"); report.erreurs.push(e.message); throw e; }
  console.log("CRÉÉS:", report.crees.length, "| MAJ:", report.mis_a_jour.length);
}

const repPath = `reports/imports/import_suppliers_${ts}.json`;
fs.writeFileSync(repPath, JSON.stringify(report, null, 1));
console.log("RAPPORT:", repPath);
await c.end();
