import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const edge = readFileSync(
  new URL("../../supabase/functions/pharma-api/index.ts", import.meta.url),
  "utf8",
);

const handlerBlock = (startMarker, len = 4500) => {
  const at = edge.indexOf(startMarker);
  assert.ok(at >= 0, `marqueur absent: ${startMarker}`);
  return edge.slice(at, at + len);
};

test("POST /medications : DCI vide n'est plus un doublon (409 a tort)", () => {
  const b = handlerBlock('path === "medications" && req.method === "POST"');
  // La recherche de doublon n'a lieu QUE si dciNorm est non vide.
  assert.match(b, /const dciNorm = String\(dci \?\? ""\)\.trim\(\)/);
  assert.match(b, /if \(dciNorm\) \{/);
  // L'insertion normalise le DCI vide en null (colonne nullable).
  assert.match(b, /dci: dciNorm \|\| null/);
});

test("POST /medications : prix et quantite valides (finis, >= 0)", () => {
  const b = handlerBlock('path === "medications" && req.method === "POST"');
  assert.match(b, /Number\.isFinite\(priceSale\) \|\| priceSale < 0/);
  assert.match(b, /Number\.isFinite\(qty\) \|\| qty < 0/);
  assert.match(b, /"VALIDATION", message: "prix ou quantit/);
});

test("PUT /medications : doublon DCI interdit (hors soi-meme), prix/quantite valides", () => {
  const b = handlerBlock("/* Construire les champs à mettre à jour */", 3000);
  // Doublon : cherche un AUTRE médicament (.neq id) avec la même DCI.
  assert.match(b, /\.neq\("id", paramId\)/);
  assert.match(b, /"CONFLICT"/);
  // Normalisation DCI vide -> null.
  assert.match(b, /patch\.dci = String\(dci \?\? ""\)\.trim\(\) \|\| null/);
  // Validation des nombres.
  assert.match(b, /Number\.isFinite\(n\) \|\| n < 0/);
});
