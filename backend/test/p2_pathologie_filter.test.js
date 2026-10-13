// Statique Edge — filtre pathologie reel (carte maladies POS + catalogue).
// Deploye en 2.2.5 : interception du parametre, route des valeurs tracees,
// aucun filtre simule, version bump.
import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const edge = readFileSync(
  new URL("../../supabase/functions/pharma-api/index.ts", import.meta.url),
  "utf8",
);

test("pathologie : le parametre est intercepte (jamais relaie a PostgREST)", () => {
  assert.ok(
    edge.indexOf('k === "pathologie" && table === "medications"') !== -1,
    "interception du parametre pathologie dans proxyToTable",
  );
  assert.ok(
    edge.indexOf("pathologieFilter = v.trim()") !== -1,
    "valeur nettoyee stockee",
  );
});

test("pathologie : filtre converti en ids via medicine_indications (tenant + ilike)", () => {
  const at = edge.indexOf("PATHOLOGIE -> ids Medications");
  assert.ok(at >= 0, "bloc de conversion absent");
  const win = edge.slice(at, at + 1400);
  assert.ok(win.indexOf('from("medicine_indications")') !== -1, "source medicine_indications");
  assert.ok(win.indexOf('eq("pharmacy_id", pid)') !== -1, "isolation tenant");
  assert.ok(win.indexOf("ilike") !== -1, "recherche insensible casse");
  assert.ok(win.indexOf("in.(") !== -1, "filtre id=in.");
});

test("pathologie : aucun resultat -> liste vide explicite (pas de faux positif)", () => {
  const at = edge.indexOf("PATHOLOGIE -> ids Medications");
  const win = edge.slice(at, at + 1500);
  assert.ok(
    win.indexOf("return json({ data: [], meta: { total: 0 } })") !== -1,
    "retour vide coherent quand aucune indication ne matche",
  );
});

test("pathologies : route GET expose les valeurs tracees avec comptage", () => {
  const at = edge.indexOf("PATHOLOGIES DU CATALOGUE");
  assert.ok(at >= 0, "route pathologies absente");
  const win = edge.slice(at, at + 1700);
  assert.ok(win.indexOf('path === "catalog/medications/pathologies"') !== -1, "route exacte");
  assert.ok(win.indexOf('eq("pharmacy_id", pid)') !== -1, "isolation tenant");
  assert.ok(win.indexOf("counts.set(p, (counts.get(p) ?? 0) + 1)") !== -1, "comptage reel");
  assert.ok(win.indexOf("PATHOLOGIES_UNAVAILABLE") !== -1, "erreur explicite");
});

test("pathologies : AUCUNE donnee fabriquee (pas de liste en dur, table source unique)", () => {
  const at = edge.indexOf("PATHOLOGIES DU CATALOGUE");
  const win = edge.slice(at, at + 1700);
  assert.ok(!/pathologie:\s*["'][A-Za-z]/.test(win), "aucune pathologie codee en dur");
  assert.ok(win.indexOf('from("medicine_indications")') !== -1, "source unique");
});

test("version Edge mise a jour pour le filtre pathologie", () => {
  assert.ok(/EDGE_VERSION = "2\.\d+\.\d+"/.test(edge), "constante de version presente");
  assert.ok(edge.indexOf('EDGE_VERSION = "2.2.4"') === -1, "plus de 2.2.4 : bump effectue");
});
