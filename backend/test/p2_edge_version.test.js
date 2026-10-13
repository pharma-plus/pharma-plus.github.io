import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const edge = readFileSync(
  new URL("../../supabase/functions/pharma-api/index.ts", import.meta.url),
  "utf8",
);

test("version Edge : une seule constante, utilisee par /health et /", () => {
  const defs = [...edge.matchAll(/const EDGE_VERSION = "([0-9]+\.[0-9]+\.[0-9]+)"/g)];
  assert.equal(defs.length, 1, "constante EDGE_VERSION unique attendue");
  assert.match(edge, /version: EDGE_VERSION,/);
  assert.equal(
    (edge.match(/version: EDGE_VERSION,/g) ?? []).length,
    2,
    "/health et / doivent partager la constante",
  );
});

test("version Edge : plus de version hardcodee dans les reponses", () => {
  assert.ok(
    !/version:\s*"[0-9]+\.[0-9]+\.[0-9]+"/.test(edge),
    "aucune version literal ne doit rester dans les reponses",
  );
});
