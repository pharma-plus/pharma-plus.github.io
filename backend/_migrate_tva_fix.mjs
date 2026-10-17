// MIGRATION TVA (autorisée 15/10/2026) :
//  1) corrige les lignes sale_items dont tax_rate diverge du produit vendu
//  2) supprime le DEFAULT 20.00 silencieux (tax_rate devient explicite)
//  3) trigger BEFORE INSERT : tax_rate = tva_rate du produit (jamais l'inverse)
import { Client } from "pg";
import "dotenv/config";

const url = (process.env.DATABASE_URL ?? "").replace(/[?&]sslmode=[^&]*/g, "");
const db = new Client({ connectionString: url, ssl: { rejectUnauthorized: false } });
await db.connect();
try {
  await db.query("BEGIN");

  const upd = await db.query(`
    UPDATE sale_items si
       SET tax_rate = m.tva_rate
      FROM medications m
     WHERE m.id = si.medication_id
       AND si.tax_rate IS DISTINCT FROM m.tva_rate`);
  console.log("1) lignes divergentes corrigees =", upd.rowCount);

  await db.query("ALTER TABLE sale_items ALTER COLUMN tax_rate DROP DEFAULT");
  console.log("2) DEFAULT 20.00 supprime sur sale_items.tax_rate");

  await db.query(`
    CREATE OR REPLACE FUNCTION fn_sale_item_tax_from_product() RETURNS trigger AS $$
    BEGIN
      NEW.tax_rate := COALESCE(
        (SELECT tva_rate FROM medications WHERE id = NEW.medication_id),
        NEW.tax_rate);
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql`);
  await db.query("DROP TRIGGER IF EXISTS trg_sale_item_tax_from_product ON sale_items");
  await db.query(`
    CREATE TRIGGER trg_sale_item_tax_from_product
      BEFORE INSERT ON sale_items
      FOR EACH ROW EXECUTE FUNCTION fn_sale_item_tax_from_product()`);
  console.log("3) trigger trg_sale_item_tax_from_product actif (BEFORE INSERT)");

  await db.query("COMMIT");
  console.log("COMMIT OK");
} catch (e) {
  await db.query("ROLLBACK");
  console.error("ROLLBACK :", e.message);
  process.exit(1);
} finally {
  await db.end();
}
