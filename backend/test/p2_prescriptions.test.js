import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const edge = readFileSync(
  new URL("../../supabase/functions/pharma-api/index.ts", import.meta.url),
  "utf8",
);

test("prescriptions : POST cree la prescription ET ses lignes (items rejete par le proxy)", () => {
  const at = edge.indexOf('path === "prescriptions" && req.method === "POST"');
  assert.ok(at >= 0, "route POST /prescriptions absente");
  const b = edge.slice(at, at + 4500);
  // Insertion explicite des lignes (le proxy generique ecrase 'items' inconnu).
  assert.match(b, /sb\s*\n?\s*\.from\("prescription_items"\)\s*\n?\s*\.insert\(/);
  // Nom patient + au moins une ligne valides.
  assert.match(b, /nom du patient requis/);
  assert.match(b, /au moins une ligne requise/);
  // Rollback de l'entete si une ligne echoue.
  assert.match(b, /await sb\.from\("prescriptions"\)\.delete\(\)\.eq\("id", presc\.id\)/);
  // Reponse embarque les lignes (la fiche UI lit p['items']).
  assert.match(b, /items: lines/);
});

test("prescriptions : GET /:id embarque les items et est filtre pharmacy_id", () => {
  const at = edge.indexOf("const prescItemMatch = path.match(/^prescriptions\\/");
  assert.ok(at >= 0, "route GET /prescriptions/:id absente");
  const b = edge.slice(at, at + 1200);
  assert.match(b, /eq\("pharmacy_id", pid\)/);
  assert.match(b, /items: lines/);
  assert.match(b, /\.from\("prescription_items"\)/);
});

test("prescriptions : /status route existe, statuts valides selon le CHECK, filtre tenant", () => {
  const at = edge.indexOf("const prescStatusMatch = path.match(/^prescriptions\\/");
  assert.ok(at >= 0, "route /status absente (frontend l'appelle)");
  const b = edge.slice(at, at + 1200);
  assert.match(b, /"received", "processing", "filled", "rejected", "archived"/);
  assert.match(b, /eq\("pharmacy_id", pid\)/);
  // 'dispensed' (valeur hors CHECK) ne doit plus apparaitre nulle part.
  assert.ok(!/"dispensed"/.test(edge), "statut hors CHECK 'dispensed' residuel");
});

test("prescriptions : dispense ecrit 'filled' + filled_at, marque les lignes, filtre tenant", () => {
  const at = edge.indexOf('if (/^prescriptions\\/[^/]+\\/dispense$/');
  assert.ok(at >= 0, "route dispense absente");
  const b = edge.slice(at, at + 2400);
  assert.match(b, /status: "filled"/);
  assert.match(b, /filled_at:/);
  assert.match(b, /eq\("pharmacy_id", pid\)/);
  assert.match(b, /is_dispensed: true/);
});
