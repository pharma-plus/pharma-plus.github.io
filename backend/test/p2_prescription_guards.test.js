import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const edge = readFileSync(
  new URL("../../supabase/functions/pharma-api/index.ts", import.meta.url),
  "utf8",
);

const statusAt = edge.indexOf("const prescStatusMatch = path.match(/^prescriptions\\/");
const dispAt = edge.indexOf('if (/^prescriptions\\/[^/]+\\/dispense$/');

test("statut 'filled' refuse sur ordonnance sans ligne (NO_ITEMS 409)", () => {
  assert.ok(statusAt >= 0, "route /status absente");
  const b = edge.slice(statusAt, statusAt + 2200);
  assert.match(b, /status === "filled"/);
  assert.match(b, /NO_ITEMS/);
  assert.match(b, /delivrance impossible/);
  assert.match(b, /from\("prescription_items"\)/);
});

test("dispense refusee sur ordonnance sans ligne (NO_ITEMS 409)", () => {
  assert.ok(dispAt >= 0, "route dispense absente");
  const b = edge.slice(dispAt, dispAt + 2200);
  assert.match(b, /NO_ITEMS/);
  assert.match(b, /delivrance impossible/);
  assert.match(b, /from\("prescription_items"\)/);
  assert.match(b, /eq\("pharmacy_id", pid\)/);
});

test("create refuse toujours une ordonnance sans ligne (VALIDATION)", () => {
  const at = edge.indexOf('path === "prescriptions" && req.method === "POST"');
  assert.ok(at >= 0, "route POST /prescriptions absente");
  const b = edge.slice(at, at + 1500);
  assert.match(b, /au moins une ligne requise/);
});
