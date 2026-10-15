// Audit DB lecture seule : defaults TVA, colonnes, RLS tables privees.
import { Client } from "pg";
import "dotenv/config";

const url = (process.env.DATABASE_URL ?? "").replace(/[?&]sslmode=[^&]*/g, "");
const c = new Client({ connectionString: url, ssl: { rejectUnauthorized: false } });
await c.connect();
try {
  console.log("=== Defaults TVA (column_default) ===");
  const tva = await c.query(`
    select table_name, column_name, column_default, data_type
    from information_schema.columns
    where column_name like '%vat%' or column_name like '%tax%'
    order by table_name, column_name`);
  console.table(tva.rows);

  console.log("=== RLS actif ? (tables privees) ===");
  const rls = await c.query(`
    select c.relname, c.relrowsecurity
    from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relkind='r'
      and c.relname in ('audit_logs','roles','permissions','role_permissions',
        'users','employees','sales','sale_items','payments','stock_movements',
        'user_sessions','suppliers','customers','medications','stock_balances','branches','pharmacies')
    order by c.relname`);
  console.table(rls.rows.map(r => ({ table: r.relname, rls: r.relrowsecurity })));

  console.log("=== Politiques RLS audit_logs/roles/role_permissions ===");
  const pol = await c.query(`
    select tablename, policyname, cmd, qual, with_check
    from pg_policies
    where schemaname='public'
      and tablename in ('audit_logs','roles','role_permissions','permissions','user_sessions')
    order by tablename, policyname`);
  console.table(pol.rows);

  console.log("=== Ventes sans lignes ou sans paiement / montants incoherents ===");
  const s = await c.query(`
    select
      (select count(*) from sales) as nb_sales,
      (select count(*) from sales s2 where not exists (select 1 from sale_items si where si.sale_id=s2.id)) as sales_sans_lignes,
      (select count(*) from sales s3 where not exists (select 1 from payments p where p.sale_id=s3.id)) as sales_sans_paiement,
      (select count(*) from sales where total < 0) as total_negatif`);
  console.table(s.rows);

  console.log("=== soldes stock negatifs ===");
  const neg = await c.query(`
    select count(*) as n from stock_balances where quantity < 0`);
  console.table(neg.rows);
} finally {
  await c.end();
}
