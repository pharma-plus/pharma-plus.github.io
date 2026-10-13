import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const edge = readFileSync(
  new URL("../../supabase/functions/pharma-api/index.ts", import.meta.url),
  "utf8",
);

test("receive : fn_next_number est appele avec le parametre reel p_pharmacy", () => {
  const at = edge.indexOf('path.match(/^purchases\\/orders\\/');
  assert.ok(at >= 0, "route /purchases/orders/:id/receive absente");
  const b = edge.slice(at, at + 2500);
  assert.match(b, /p_pharmacy:\s*pid/);
  assert.ok(
    !/p_pharmacy_id:/.test(b),
    "p_pharmacy_id inexistant : echec PostgREST silencieux + repli timestamp",
  );
});

test("receive : AUCUN repli timestamp — echec de numerotation = refus explicite", () => {
  const at = edge.indexOf('path.match(/^purchases\\/orders\\/');
  const b = edge.slice(at, at + 2500);
  assert.ok(
    !/RCP-\$\{Date\.now\(\)\}/.test(b),
    "repli RCP-<timestamp> residuel : numerotation non sequentielle",
  );
  assert.match(b, /NUMBERING_FAILED/);
  assert.match(b, /reception annulee/);
});

test("ventes : AUCUN repli timestamp — echec de numerotation = refus explicite", () => {
  const at = edge.indexOf('path === "sales" && req.method === "POST"');
  assert.ok(at >= 0, "route POST /sales absente");
  const b = edge.slice(at, at + 9000);
  assert.ok(
    !/POS-\$\{Date\.now\(\)\}/.test(b),
    "repli POS-<timestamp> residuel : numerotation non sequentielle",
  );
  assert.match(b, /NUMBERING_FAILED/);
  assert.match(b, /vente annulee/);
});
