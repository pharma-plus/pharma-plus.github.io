import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const migration = readFileSync(
  new URL(
    "../../supabase/migrations/20261009140000_trigger_stock_direction_fix.sql",
    import.meta.url,
  ),
  "utf8",
);
const ddl = readFileSync(
  new URL("../../database/schema/012_triggers_views.sql", import.meta.url),
  "utf8",
);

const incomingList = (src) =>
  src
    .match(/movement_type\s+IN\s*\(([^)]+)\)/i)?.[1]
    ?.match(/'([a-z_]+)'/g)
    ?.map((m) => m.slice(1, -1)) ?? [];

test("trigger : release retire de la branche entrante (bug prod)", () => {
  const lists = [...migration.matchAll(/movement_type\s+in\s*\(([^)]+)\)/gi)].map(
    (m) => m[1].match(/'([a-z_]+)'/g)?.map((s) => s.slice(1, -1)) ?? [],
  );
  assert.ok(lists.length >= 2, "deux listes de types (entrees/sorties)");
  const flat = lists.flat();
  assert.ok(!flat.includes("release"), "release ne doit plus etre dans une liste de direction");
  assert.match(migration, /movement_type = 'release'/);
  assert.match(migration, /reserved_quantity - abs\(NEW\.quantity\)/);
  assert.match(migration, /reserved_quantity \+ abs\(NEW\.quantity\)/);
});

test("trigger : direction par le type, ELSE refuse, anti-negatif avant ecriture", () => {
  assert.match(migration, /'purchase_receipt', 'sale_return', 'inventory_in',\s*'transfer_in'/);
  assert.match(migration, /'sale', 'inventory_out', 'transfer_out', 'write_off', 'expiry_loss'/);
  assert.match(migration, /movement_type = 'adjustment'/);
  assert.match(migration, /raise exception 'movement_type % non gere/);
  assert.match(migration, /Stock insuffisant pour % \(manque %\)/);
  assert.ok(
    migration.indexOf("for r in") < migration.indexOf("exit when v_remain <= 0"),
    "sortie repartie ligne a ligne",
  );
  assert.match(migration, /lot_id is null/, "NULL-lot agrege (ON CONFLICT ne couvre pas NULL)");
});

test("trigger : DDL source 012 resynchronise avec la migration", () => {
  assert.ok(ddl.includes("fn_apply_stock_movement"), "fonction presente dans 012");
  const lists = incomingList(ddl);
  assert.ok(!lists.includes("release"), "012 : release retire de la liste entrante");
  assert.match(ddl, /Type non géré[\s\S]{0,80}REFUSÉ|non géré par fn_apply_stock_movement/i);
  assert.match(ddl, /movement_type = 'release'/);
  assert.match(ddl, /v_remain/);
  const migBody = migration.slice(migration.indexOf("as $fn$"), migration.lastIndexOf("$fn$"));
  const ddlBody = ddl.slice(ddl.indexOf("fn_apply_stock_movement"), ddl.indexOf("$$ LANGUAGE plpgsql", ddl.indexOf("fn_apply_stock_movement")));
  assert.equal(
    (migBody.match(/v_remain/g) ?? []).length,
    (ddlBody.match(/v_remain/g) ?? []).length,
    "meme logique de decomposition dans les deux versions",
  );
});
