import { Client } from "pg";
import "dotenv/config";
const url = (process.env.DATABASE_URL ?? "").replace(/[?&]sslmode=[^&]*/g, "");
const db = new Client({ connectionString: url, ssl: { rejectUnauthorized: false } });
await db.connect();
try {
  const s = await db.query(`select id, number, subtotal, discount_total, tax_total, total, paid_amount, change_amount, status, created_at from sales where number in ('POS-2026-000105','POS-2026-000106','POS-2026-000107','POS-2026-000108') order by number`);
  for (const r of s.rows) {
    console.log("== " + r.number + " " + r.created_at.toISOString().slice(0,16) + " sub=" + r.subtotal + " disc=" + r.discount_total + " tax=" + r.tax_total + " total=" + r.total + " paid=" + r.paid_amount + " change=" + r.change_amount + " status=" + r.status);
    const si = await db.query("select quantity, unit_price, tax_rate, tva_rate, discount, discount_percent, line_total from sale_items where sale_id=$1", [r.id]);
    si.rows.forEach(x => console.log("   q=" + x.quantity + " pu=" + x.unit_price + " tax_rate=" + x.tax_rate + " tva=" + x.tva_rate + " disc=" + x.discount + " disc%=" + x.discount_percent + " line_total=" + x.line_total));
    const pay = await db.query("select method, amount, status from payments where sale_id=$1", [r.id]);
    pay.rows.forEach(x => console.log("   pay " + x.method + " amount=" + x.amount + " status=" + x.status));
  }
  const chk = await db.query(`select s.id, s.number, s.subtotal, s.tax_total, s.discount_total, s.total,
    coalesce((select sum(quantity*unit_price) from sale_items si where si.sale_id=s.id),0) as ht,
    coalesce((select sum(quantity*unit_price*tva_rate/100) from sale_items si where si.sale_id=s.id),0) as tax_calc
    from sales s`);
  let bad = 0;
  for (const r of chk.rows) {
    const attendu = Number(r.subtotal) - Number(r.discount_total ?? 0) + Number(r.tax_total ?? 0);
    const ok = Math.abs(Number(r.total) - attendu) < 0.011
      && Math.abs(Number(r.subtotal) - Number(r.ht)) < 0.011
      && Math.abs(Number(r.tax_total ?? 0) - Number(r.tax_calc)) < 0.02;
    if (!ok) { bad++; console.log(" KO " + r.number + " sub=" + r.subtotal + " ht=" + r.ht + " tax=" + r.tax_total + " taxcalc=" + Number(r.tax_calc).toFixed(2) + " disc=" + r.discount_total + " total=" + r.total + " attendu=" + attendu.toFixed(2)); }
  }
  console.log("FORMULES: " + chk.rows.length + " ventes, incoherences=" + bad);
  const tv = await db.query("select tva_rate, count(*)::int n from sale_items group by tva_rate order by tva_rate");
  console.log("TVA: " + tv.rows.map(r => r.tva_rate + "%x" + r.n).join(", "));
  // stock: coherence balances vs somme des mouvements (echantillon global)
  const stk = await db.query(`select
    (select count(*)::int from stock_balances) as balances,
    (select coalesce(sum(quantity),0)::int from stock_balances) as qte_totale,
    (select coalesce(sum(quantity*cost_price),0)::numeric(14,2) from stock_balances) as valorisation_cost`);
  console.log("STOCK: balances=" + stk.rows[0].balances + " qte=" + stk.rows[0].qte_totale + " valorisation_prix_de_revient=" + stk.rows[0].valorisation_cost);
} finally { await db.end(); }