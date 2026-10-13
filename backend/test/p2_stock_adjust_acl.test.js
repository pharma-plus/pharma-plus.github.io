import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

// Migration preparee (NON appliquee en production : autorisation requise)
// durcissant l'ACL de public.fn_stock_adjust, sur le meme modele que
// 20261009120000 (8 fonctions REVOKEes de PUBLIC/anon).
const migration = readFileSync(
  new URL(
    "../../supabase/migrations/20261010100000_stock_adjust_acl_hardening.sql",
    import.meta.url,
  ),
  "utf8",
);

// Fonction d'origine (20261009130000) : doit toujours creer la fonction
// SANS revocation inline (le durcissement vit dans sa propre migration).
const create = readFileSync(
  new URL(
    "../../supabase/migrations/20261009130000_stock_adjustments_rpc.sql",
    import.meta.url,
  ),
  "utf8",
);

test("acl migration : REVOKE PUBLIC/anon sur fn_stock_adjust", () => {
  assert.match(
    migration,
    /revoke execute on function public\.fn_stock_adjust\(uuid, jsonb, text, uuid, uuid\)/i,
  );
  assert.match(migration, /from public, anon/i);
});

test("acl migration : GRANT aux roles applicatifs (postgres, service_role, authenticated, supabase_admin)", () => {
  assert.match(
    migration,
    /grant execute on function public\.fn_stock_adjust\(uuid, jsonb, text, uuid, uuid\)/i,
  );
  for (const role of ["postgres", "supabase_admin", "authenticated", "service_role"]) {
    assert.ok(
      new RegExp(`to .*\\b${role}\\b`, "i").test(migration),
      `role absent du GRANT: ${role}`,
    );
  }
  assert.ok(!/\banon\b/i.test(migration.split("grant")[1] ?? ""), "anon ne doit pas recevoir GRANT");
});

test("acl migration : idempotente, sans donnee ni corps de fonction modifie", () => {
  assert.ok(!/insert into|update |delete from|drop function/i.test(migration), "aucune ecriture de donnee");
  assert.ok(!/create or replace function/i.test(migration), "aucun corps de fonction modifie");
  // revoke/grant sont nativement idempotents en Postgres.
});

test("migration d'origine : signature exacte attendue par le REVOKE", () => {
  // Types dans l'ordre : (uuid, jsonb, text, uuid, uuid) — c'est par types
  // d'arguments que Postgres identifie la cible du REVOKE/GRANT.
  assert.match(
    create,
    /create or replace function public\.fn_stock_adjust\s*\(\s*p_branch_id uuid,\s*p_items jsonb,\s*p_reason text default null,\s*p_idempotency_key uuid default null,\s*p_user_id uuid default null\s*\)/i,
  );
});

test("edge : stock/adjustments et write-off passent par service_role (GRANT couvre l'appel)", () => {
  const edge = readFileSync(
    new URL("../../supabase/functions/pharma-api/index.ts", import.meta.url),
    "utf8",
  );
  assert.match(edge, /fn_stock_adjust/);
  // L'admin (Edge) utilise la cle service_role : le GRANT la couvre.
  assert.match(edge, /service_role/i);
});
