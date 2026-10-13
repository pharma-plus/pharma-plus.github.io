import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const migration = readFileSync(
  new URL(
    "../../supabase/migrations/20261009150000_live_schema_reconciliation.sql",
    import.meta.url,
  ),
  "utf8",
);
const ddl013 = readFileSync(
  new URL("../../database/schema/013_reference.sql", import.meta.url),
  "utf8",
);
const ddl938 = readFileSync(
  new URL("../../database/schema/938_doctor_role.sql", import.meta.url),
  "utf8",
);

const DDL_FILES = {
  "006_purchases.sql": ["purchase_order_id", "discount_percent", "tax_rate"],
  "007_sales.sql": ["unit_cost", "discount_percent", "tax_rate", "issued_at"],
  "010_accounting.sql": ["date", "total_debit", "total_credit", "status", "created_at"],
  "014_cameras.sql": ["port", "is_active"],
  "005_partners.sql": ["credit_used", "is_insured"],
  "008_prescriptions.sql": ["prescribed_date"],
  "009_hr.sql": ["created_at"],
  "011_ops.sql": ["started_at", "updated_at", "is_published"],
};

test("DDL versionne : les 22 colonnes de production sont presentes", () => {
  for (const [file, cols] of Object.entries(DDL_FILES)) {
    const src = readFileSync(
      new URL(`../../database/schema/${file}`, import.meta.url),
      "utf8",
    );
    for (const c of cols) {
      assert.ok(
        new RegExp(`\\b${c}\\b`).test(src),
        `${file}: colonne ${c} absente du DDL versionne`,
      );
    }
  }
});

test("reference_categories : DDL local aligne sur la production (code PK)", () => {
  const block = ddl013.slice(
    ddl013.indexOf("CREATE TABLE IF NOT EXISTS reference_categories"),
    ddl013.indexOf(");", ddl013.indexOf("CREATE TABLE IF NOT EXISTS reference_categories")),
  );
  assert.match(block, /code\s+text PRIMARY KEY/);
  assert.match(block, /created_at\s+timestamptz NOT NULL DEFAULT now\(\)/);
  assert.ok(!/\bid\b/.test(block.split("\n")[1]), "013 ne doit plus porter de colonne id sur reference_categories");
  const ddl930 = readFileSync(
    new URL("../../database/schema/930_reference_tables.sql", import.meta.url),
    "utf8",
  );
  assert.match(ddl930, /code\s+text PRIMARY KEY/, "930 deja aligne");
});

test("migration : additive, idempotente, role MEDECIN versionne", () => {
  assert.match(migration, /ADD COLUMN IF NOT EXISTS|ADD COLUMN %I|ADD COLUMN purchase_order_id/);
  assert.match(migration, /to_regclass\('public\./, "garde-fou sur tables absentes");
  assert.match(migration, /website_settings_pkey PRIMARY KEY \(id\)/);
  assert.match(migration, /website_settings_pharmacy_id_key UNIQUE \(pharmacy_id\)/);
  assert.match(migration, /ON CONFLICT \(id\) DO NOTHING/);
  assert.match(migration, /r\.code = 'doctor'/);
  for (const code of ["dashboard:view", "catalog:view", "customers:view",
    "prescriptions:view", "sales:view"]) {
    assert.ok(ddl938.includes(code) && migration.includes(code),
      `permission ${code} absente de 938 ou de la migration`);
  }
  assert.ok(
    !/DELETE|TRUNCATE|DROP TABLE/i.test(migration),
    "aucune operation destructive dans la migration de reconciliation",
  );
});
