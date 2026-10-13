import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const edge = readFileSync(
  new URL("../../supabase/functions/pharma-api/index.ts", import.meta.url),
  "utf8",
);
const migration = readFileSync(
  new URL(
    "../../supabase/migrations/20261009130000_stock_adjustments_rpc.sql",
    import.meta.url,
  ),
  "utf8",
);
const ddl = readFileSync(
  new URL("../../database/schema/004_stock.sql", import.meta.url),
  "utf8",
);
const dart = readFileSync(
  new URL("../../frontend/lib/features/stock/stock_page.dart", import.meta.url),
  "utf8",
);

const CHECK_TYPES = [
  ...ddl
    .match(/movement_type\s+IN\s*\(([^)]+)\)/s)?.[1]
    ?.match(/'([a-z_]+)'/g)
    ?.map((m) => m.slice(1, -1)) ?? [],
];
const RPC_ALLOWED_TYPES = [
  "inventory_in",
  "inventory_out",
  "write_off",
  "expiry_loss",
];

test("base : CHECK movement_type extraite du DDL (source de verite)", () => {
  assert.ok(CHECK_TYPES.length >= 12, `types CHECK: ${CHECK_TYPES.join(",")}`);
  for (const t of RPC_ALLOWED_TYPES) {
    assert.ok(CHECK_TYPES.includes(t), `${t} absent de la CHECK`);
  }
  for (const bad of ["entry", "exit", "correction"]) {
    assert.ok(!CHECK_TYPES.includes(bad), `${bad} ne doit pas exister en base`);
  }
});

test("Edge : les deux routes passent par le bloc contrat unique", () => {
  assert.match(edge, /path === "stock\/adjustments" \|\| path === "stock\/write-off"/);
  assert.ok(
    !/from\("stock_movements"\)\.insert\(\{\s*\.\.\.body/.test(edge),
    "plus d'insert spread du body brut (branchId/items seraient rejetez)",
  );
  assert.ok(
    !edge.includes("WRITEOFF_FAILED"),
    "ancienne route write-off supprimee du code",
  );
});

test("Edge : branch_id toujours present sur tout insert stock_movements", () => {
  const inserts = [...edge.matchAll(/from\("stock_movements"\)\s*\.insert\(/g)];
  assert.ok(inserts.length >= 1, "au moins un insert (chemin repli)");
  for (const m of inserts) {
    const block = edge.slice(m.index, m.index + 600);
    assert.match(block, /branch_id:/, "insert stock_movements sans branch_id");
    assert.doesNotMatch(
      block,
      /branchId\s*:/,
      "la cle SQL est branch_id (pas branchId camelCase)",
    );
  }
  assert.match(edge, /p_branch_id: branchId/, "la RPC recoit la branche");
});

test("Edge : types de mouvement emis conformes a la CHECK", () => {
  const emitted = [
    ...edge.matchAll(/mType = (?:delta > 0 \? "([a-z_]+)" : "([a-z_]+)")|(?:it\.expired \? "([a-z_]+)" : "([a-z_]+)")/g),
  ].flatMap((m) => m.slice(1).filter(Boolean));
  assert.ok(emitted.length >= 4, `types emis: ${emitted.join(",")}`);
  for (const t of emitted) {
    assert.ok(
      CHECK_TYPES.includes(t),
      `type emis ${t} interdit par la CHECK de stock_movements`,
    );
  }
  for (const bad of ["entry", "exit", "correction"]) {
    assert.ok(!emitted.includes(bad), `legacy ${bad} emis tel quel`);
  }
});

test("RPC : contrat atomique, perimetre par branche, idempotence", () => {
  assert.match(migration, /create or replace function public\.fn_stock_adjust/);
  assert.match(migration, /security definer/i);
  assert.match(migration, /set search_path = public, pg_temp/);
  assert.match(migration, /p_branch_id uuid/);
  assert.match(migration, /p_idempotency_key uuid/);
  assert.doesNotMatch(
    migration,
    /p_pharmacy/,
    "la pharmacie doit derive de la branche, jamais d'un parametre client",
  );
  assert.match(
    migration,
    /select b\.pharmacy_id into v_pharmacy\s+from public\.branches/,
  );
  assert.match(
    migration,
    /reference_type = 'stock_adjust'\s+and m\.reference_id = p_idempotency_key/,
  );
  assert.match(migration, /'inventory_in'/);
  assert.match(migration, /'inventory_out'/);
  assert.match(migration, /'write_off'/);
  assert.match(migration, /'expiry_loss'/);
  assert.doesNotMatch(migration, /'(entry|exit|correction)'/);
  assert.match(migration, /v_delta = 0[\s\S]{0,80}continue/, "delta nul ignore");
});

test("Frontend : payloads attendus par le contrat", () => {
  assert.match(dart, /post\('\/stock\/adjustments', body: \{/);
  assert.match(dart, /'branchId': branchId/);
  assert.match(dart, /'medication_id': medicationId/);
  assert.match(dart, /'new_quantity': newQuantity/);
  assert.match(dart, /post\('\/stock\/write-off', body: \{/);
  assert.match(dart, /'quantity': amount/);
  assert.match(dart, /'expired': expired/);
});

test("Edge : echec d'audit toujours visible sur le contrat stock", () => {
  const block = edge.slice(
    edge.indexOf('path === "stock/adjustments"'),
    edge.indexOf("USERS — reset-password"),
  );
  assert.ok(block.length > 0, "bloc stock extrait");
  assert.match(block, /await _logAction/);
  assert.match(block, /AUDIT_FAILED/);
  assert.match(block, /p_idempotency_key: idempotencyKey/);
  assert.match(block, /rpcMissing/, "repli si la RPC n'est pas encore appliquee");
});
