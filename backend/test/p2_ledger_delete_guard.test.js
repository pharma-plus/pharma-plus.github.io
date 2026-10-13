import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const edge = readFileSync(
  new URL("../../supabase/functions/pharma-api/index.ts", import.meta.url),
  "utf8",
);

test("proxy : DELETE interdit sur sales, sale_items et stock_movements", () => {
  const at = edge.indexOf("Integrite ledger");
  assert.ok(at >= 0, "garde-fou ledger absent");
  const block = edge.slice(at, at + 900);
  assert.match(block, /req\.method === "DELETE"/);
  for (const t of ["sales", "sale_items", "stock_movements"]) {
    assert.ok(block.includes(`"${t}"`), `table absente du garde-fou: ${t}`);
  }
  assert.match(block, /"METHOD_NOT_ALLOWED"/);
  assert.match(block, /405/);
  assert.match(block, /\/sales\/returns/);
});

test("proxy : le garde-fou precede l'appel proxyToTable", () => {
  const at = edge.indexOf("Integrite ledger");
  const guard = edge.indexOf("return json(", at);
  const proxied = edge.indexOf("proxyToTable(serviceKey, supabaseUrl, req, table", at);
  assert.ok(guard >= 0 && proxied > guard, "l'ordre garde-fou/proxy est incorrect");
});
