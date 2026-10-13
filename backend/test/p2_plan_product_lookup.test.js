import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const plan = readFileSync(
  new URL(
    "../../frontend/lib/features/floor_plan/pharmacy_plan_page.dart",
    import.meta.url,
  ),
  "utf8",
);

test("plan 3D : lookup catalogue AVANT de pousser CatalogPage", () => {
  // Le panneau de zone ne pousse plus le catalogue a l'aveugle :
  // il interroge /catalog/medications?q=... et n navigue que si
  // un produit correspond (libelles de meuble 'Caisse', 'TPE'...).
  const at = plan.indexOf("onProductTap: (product) async");
  assert.ok(at >= 0, "onProductTap doit etre asynchrone (verification prealable)");
  const block = plan.slice(at, at + 2000);
  assert.match(block, /\/catalog\/medications/);
  assert.match(block, /'q': product/);
  // Navigation conditionnelle a un resultat non vide.
  assert.match(block, /items\.isNotEmpty/);
  // Sinon, message honnete au lieu d'une recherche vide.
  assert.match(block, /showSnackBar/);
  assert.match(block, /S\.t\('noResults'/);
});

test("plan 3D : CatalogPage(initialQuery) ne subsiste que derriere le garde-fou", () => {
  // Toute occurrence de CatalogPage(initialQuery: product) doit etre
  // dans le bloc conditionnel items.isNotEmpty.
  const occurrences = plan.split("CatalogPage(initialQuery: product)").length - 1;
  assert.equal(occurrences, 1, "une seule navigation produit, guardée");
  const at = plan.indexOf("CatalogPage(initialQuery: product)");
  const guardAt = plan.lastIndexOf("items.isNotEmpty", at);
  assert.ok(guardAt >= 0 && at > guardAt, "la navigation doit suivre le garde-fou items.isNotEmpty");
});
