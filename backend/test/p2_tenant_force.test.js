import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const edge = readFileSync(
  new URL("../../supabase/functions/pharma-api/index.ts", import.meta.url),
  "utf8",
);

const proxyBody = () => {
  const at = edge.indexOf("async function proxyToTable");
  assert.ok(at >= 0, "proxyToTable absent");
  return edge.slice(at, at + 6000);
};

test("proxy : POST force pharmacy_id a la session (jamais celui du client)", () => {
  const b = proxyBody();
  const at = b.indexOf("if (HAS_PHARMACY)");
  assert.ok(at >= 0, "bloc HAS_PHARMACY absent");
  const postBlock = b.slice(at, at + 400);
  assert.match(postBlock, /parsed\.pharmacy_id = pid/);
  // Plus d'injection conditionnelle fiablee au client sur l'ecriture.
  assert.ok(
    !/if \(!parsed\.pharmacy_id && table !== "pharmacies"\)/.test(b),
    "l'ancien injecteur conditionnel (confiance au client) ne doit pas subsister",
  );
});

test("proxy : PATCH/DELETE imposent le filtre pharmacy_id (couvre ?id=eq.)", () => {
  const b = proxyBody();
  // Derniere occurrence : le bloc PATCH/DELETE (la premiere est le GET).
  const at = b.lastIndexOf('targetUrl.searchParams.set("pharmacy_id", `eq.${pid}`)');
  assert.ok(at >= 0, "filtre force absent");
  // Le bloc ne doit plus dependre d'un uuid-subpath : la condition couvre
  // tout appel ecriture non-GET/POST sur table isolee.
  const condStart = b.lastIndexOf("if (", at);
  const cond = b.slice(condStart, at);
  assert.ok(!/uuidRe\.test\(subpath\)/.test(cond), "la condition ne doit plus exiger un uuid-subpath");
  assert.match(cond, /method !== "GET"/);
  assert.match(cond, /method !== "POST"/);
  assert.match(cond, /HAS_PHARMACY/);
});

test("proxy : HAS_PHARMACY exclut globales, pharmacies et roles", () => {
  const b = proxyBody();
  assert.match(b, /const HAS_PHARMACY\s*=/);
  const at = b.indexOf("const HAS_PHARMACY");
  const def = b.slice(at, at + 250);
  assert.match(def, /!GLOBAL_TABLES\.has\(table\)/);
  assert.match(def, /table !== "pharmacies"/);
  assert.match(def, /table !== "roles"/);
});

test("proxy : GLOBAL_TABLES present avant tout usage de HAS_PHARMACY", () => {
  const b = proxyBody();
  const globals = b.indexOf("const GLOBAL_TABLES");
  const has = b.indexOf("const HAS_PHARMACY");
  assert.ok(globals >= 0 && has > globals, "ordre de declaration incorrect");
});
