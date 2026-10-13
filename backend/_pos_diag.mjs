import "dotenv/config";
import pg from "pg";
const raw = process.env.DATABASE_URL;
const c = new pg.Client({ connectionString: raw.replace(/[?&]sslmode=[^&]*/g, ""), ssl: { rejectUnauthorized: false } });
await c.connect();
// Colonnes sale_items : générées ?
const cols = await c.query(`
  SELECT column_name, data_type, is_generated, generation_expression, column_default
  FROM information_schema.columns
  WHERE table_name='sale_items' AND column_name IN ('line_total','tax_rate','tva_rate','unit_price','quantity','discount_percent')`);
console.log("SALE_ITEMS_COLS:", JSON.stringify(cols.rows, null, 1));
// Triggers sur sale_items / sales
const trg = await c.query(`
  SELECT tgname, pg_get_triggerdef(oid) AS def FROM pg_trigger WHERE NOT tgisinternal
  AND tgrelid IN ('sale_items'::regclass, 'sales'::regclass, 'payments'::regclass)`);
console.log("TRIGGERS:", JSON.stringify(trg.rows, null, 1));
// Dernières ventes : cohérence tax_total vs somme line_total
const last = await c.query(`
  SELECT s.id, s.number, s.subtotal, s.tax_total, s.total, s.paid_amount, s.payment_method, s.status, s.created_at,
         (SELECT COALESCE(SUM(line_total),0) FROM sale_items si WHERE si.sale_id=s.id) AS lines_sum,
         (SELECT COUNT(*) FROM sale_items si WHERE si.sale_id=s.id) AS n_items,
         (SELECT COALESCE(SUM(amount),0) FROM payments p WHERE p.sale_id=s.id) AS paid_sum
  FROM sales s ORDER BY s.created_at DESC LIMIT 5`);
console.log("LAST_SALES:", JSON.stringify(last.rows, null, 1));
// TVA settings pharmacie + médicaments
const tva = await c.query(`
  SELECT settings->'tva' AS tva FROM pharmacies WHERE id='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'`);
console.log("PHARM_TVA:", JSON.stringify(tva.rows[0]));
const tdist = await c.query(`
  SELECT tva_rate, count(*)::int AS n FROM medications WHERE pharmacy_id='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' AND status='available' GROUP BY tva_rate ORDER BY n DESC LIMIT 5`);
console.log("MEDS_TVA_DIST:", JSON.stringify(tdist.rows));
await c.end();
