import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const edge = readFileSync(
  new URL("../../supabase/functions/pharma-api/index.ts", import.meta.url),
  "utf8",
);

const saleBlock = () => {
  const at = edge.indexOf('if (path === "sales" && req.method === "POST")');
  assert.ok(at >= 0, "bloc sales POST absent");
  return edge.slice(at, at + 16000);
};

test("sales : erreur sale_items -> compensation (jamais de vente orpheline)", () => {
  const b = saleBlock();
  assert.match(b, /if \(itemErr\) \{/);
  const at = b.indexOf("if (itemErr)");
  const after = b.slice(at, at + 500);
  assert.match(after, /compensateSale/);
});

test("sales : erreur stock_movements -> STOCK_INSUFFISANT + compensation", () => {
  const b = saleBlock();
  assert.match(b, /if \(mvErr\) \{/);
  const at = b.indexOf("if (mvErr)");
  const after = b.slice(at, at + 600);
  assert.match(after, /compensateSale/);
  assert.match(after, /"STOCK_INSUFFISANT"/);
  assert.match(after, /409/);
});

test("sales : erreur payment -> PAYMENT_FAILED + compensation", () => {
  const b = saleBlock();
  assert.match(b, /if \(payErr\) \{/);
  const at = b.indexOf("if (payErr)");
  const after = b.slice(at, at + 500);
  assert.match(after, /compensateSale/);
  assert.match(after, /"PAYMENT_FAILED"/);
});

test("sales : la compensation insere des mouvements inverses (ledger honest)", () => {
  const b = saleBlock();
  const at = b.indexOf("const compensateSale");
  assert.ok(at >= 0, "compensateSale absent");
  const fn = b.slice(at, at + 1800);
  // Mouvement inverse de type accepte par la CHECK, signe oppose.
  assert.match(fn, /movement_type: "inventory_in"/);
  assert.match(fn, /Math\.abs\(Number\(m\.quantity\)\)/);
  assert.match(fn, /reference_type: "sale_compensation"/);
  // Puis suppression des lignes et de la vente.
  assert.match(fn, /await sb\.from\("sale_items"\)\.delete\(\)\.eq\("sale_id", sale\.id\)/);
  assert.match(fn, /await sb\.from\("sales"\)\.delete\(\)\.eq\("id", sale\.id\)/);
});

test("sales : les mouvements appliques sont tracks (applied.push)", () => {
  const b = saleBlock();
  assert.match(b, /applied\.push\(/);
  // Le push n'a lieu qu'APRES le controle d'erreur du mouvement.
  const mvErr = b.indexOf("if (mvErr)");
  const push = b.indexOf("applied.push(");
  assert.ok(push > mvErr, "applied.push doit suivre le controle mvErr");
});
