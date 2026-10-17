// Audit TVA live : défaut colonne, triggers, divergences produit vs sale_items.
import { Client } from "pg";
import "dotenv/config";

const url = (process.env.DATABASE_URL ?? "").replace(/[?&]sslmode=[^&]*/g, "");
const db = new Client({ connectionString: url, ssl: { rejectUnauthorized: false } });
await db.connect();
try {
  const def = await db.query(
    `select column_default, is_nullable, data_type
     from information_schema.columns
     where table_name = 'sale_items' and column_name = 'tax_rate'`,
  );
  console.log("DEFAULT sale_items.tax_rate =", JSON.stringify(def.rows[0]));

  const trg = await db.query(
    `select tgname, tgtype, pg_get_triggerdef(oid) as def
     from pg_trigger where tgrelid = 'sale_items'::regclass and not tgisinternal`,
  );
  console.log("TRIGGERS sale_items =", trg.rowCount);
  for (const t of trg.rows) console.log("  -", t.tgname, "|", t.def);

  const trgSales = await db.query(
    `select tgname from pg_trigger where tgrelid = 'sales'::regclass and not tgisinternal`,
  );
  console.log("TRIGGERS sales =", trgSales.rows.map((r) => r.tgname).join(", "));

  const dist = await db.query(
    `select tax_rate, count(*) as n from sale_items group by tax_rate order by n desc`,
  );
  console.log("DISTRIBUTION sale_items.tax_rate :");
  for (const r of dist.rows) console.log(`  ${r.tax_rate} -> ${r.n}`);

  // Divergences : tax_rate stocké ≠ tva_rate du produit
  const div = await db.query(
    `select count(*)::int as n
     from sale_items si join medications m on m.id = si.medication_id
     where si.tax_rate is distinct from m.tva_rate`,
  );
  console.log("DIVERGENCES (sale_items.tax_rate != medications.tva_rate) =", div.rows[0].n);

  const divDetail = await db.query(
    `select m.tva_rate, si.tax_rate, count(*)::int as n
     from sale_items si join medications m on m.id = si.medication_id
     where si.tax_rate is distinct from m.tva_rate
     group by m.tva_rate, si.tax_rate order by n desc limit 10`,
  );
  for (const r of divDetail.rows)
    console.log(`  produit=${r.tva_rate} stocke=${r.tax_rate} -> ${r.n}`);

  // tva_rate des médicaments
  const med = await db.query(
    `select tva_rate, count(*)::int as n from medications group by tva_rate order by n desc`,
  );
  console.log("DISTRIBUTION medications.tva_rate :");
  for (const r of med.rows) console.log(`  ${r.tva_rate} -> ${r.n}`);
} finally {
  await db.end();
}
