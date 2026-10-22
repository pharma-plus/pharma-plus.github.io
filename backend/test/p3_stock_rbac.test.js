import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

// Tests statiques du renforcement RBAC du module stock :
//  - POST /stock/write-off exige stock:edit (ROUTE_MODULE + ROUTE_FORCE)
//  - /inventory/sessions* exige inventory:view|create (+ approve au close)
//  - /stock/alerts reste hors matrice (dashboard/caisse : lecture seule
//    sans permission stock — ne jamais la mapper ici).
const edge = readFileSync(
  new URL("../../supabase/functions/pharma-api/index.ts", import.meta.url),
  "utf8",
);

function sliceAfter(marker, length = 900) {
  const i = edge.indexOf(marker);
  assert.ok(i >= 0, `marqueur absent: ${marker}`);
  return edge.slice(i, i + length);
}

const MODULE_BLOCK = sliceAfter("const ROUTE_MODULE", 2400);

test("RBAC : write-off mappe le module stock", () => {
  assert.match(MODULE_BLOCK, /"stock\/write-off": "stock"/);
  // Les routes voisines restent mappées.
  assert.match(MODULE_BLOCK, /"stock\/adjustments": "stock"/);
  assert.match(MODULE_BLOCK, /"stock\/balances": "stock"/);
});

test("RBAC : write-off force l'action edit (pas create derive du POST)", () => {
  const block = sliceAfter("const ROUTE_FORCE", 700);
  assert.match(block, /\{ test: \/\^stock\\\/write-off\$\/, method: "POST", action: "edit" \}/);
  assert.ok(
    !/"stock\/write-off": "stock"[\s\S]{0,120}ROUTE_FORCE/.test(block),
    "write-off bien couvert par ROUTE_FORCE",
  );
});

test("RBAC : inventory/sessions mappe le module inventory", () => {
  assert.match(MODULE_BLOCK, /"inventory\/sessions": "inventory"/);
  // La clôture conserve son garde explicite inventory:approve
  // (route appariée par regex : /^inventory\/sessions\/...\/close$/i).
  assert.match(edge, /inventory:approve/);
  const closeBlock = sliceAfter(
    "mm = path.match(/^inventory\\/sessions\\/([0-9a-f-]{36})\\/close$/i);",
    500,
  );
  assert.match(closeBlock, /inventory:approve/);
  assert.match(closeBlock, /"inventory:approve",/);
});

test("RBAC : /stock/alerts reste hors matrice (dashboard accesible)", () => {
  assert.ok(
    !/"stock\/alerts"/.test(MODULE_BLOCK),
    "stock/alerts ne doit PAS etre mappee : le dashboard (tous roles) l'appelle",
  );
  // Et aucune force ne touche alerts.
  const force = sliceAfter("const ROUTE_FORCE", 700);
  assert.ok(!/stock\\\/alerts/.test(force));
});

test("Frontend : actions de correction gatees par permissions", () => {
  const dart = readFileSync(
    new URL("../../frontend/lib/features/stock/stock_page.dart", import.meta.url),
    "utf8",
  );
  assert.match(dart, /permissions\.contains\('stock:edit'\)/);
  assert.match(dart, /permissions\.contains\('stock:create'\)/);
  // La page d'inventaire demande une confirmation des ecarts avant close.
  const inv = readFileSync(
    new URL(
      "../../frontend/lib/features/stock/inventory_page.dart",
      import.meta.url,
    ),
    "utf8",
  );
  assert.match(inv, /Valider l\\'inventaire \?/);
  assert.match(inv, /post\('\/inventory\/sessions\/\$sessionId\/close'/);
});
