import { Client } from "pg";
import "dotenv/config";
const url = (process.env.DATABASE_URL ?? "").replace(/[?&]sslmode=[^&]*/g, "");
const db = new Client({ connectionString: url, ssl: { rejectUnauthorized: false } });
await db.connect();
try {
  await db.query("BEGIN");
  const ph = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa";
  const br = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb";
  const uid = "00000000-0000-0000-0000-0000000000aa";
  const s = await db.query(
    `insert into sales (pharmacy_id, branch_id, number, sale_type, status, user_id)
     values ($1,$2,'TRIGGER-TVA-PROOF','pos','completed',$3) returning id`, [ph, br, uid]);
  const sid = s.rows[0].id;
  const p20 = await db.query("select id from medications where tva_rate = 20 limit 1");
  const p0 = await db.query("select id from medications where tva_rate = 0 limit 1");
  if (!p20.rowCount || !p0.rowCount) throw new Error("produit tva 20 ou 0 introuvable");
  await db.query(
    `insert into sale_items (pharmacy_id, sale_id, medication_id, quantity, unit_price, tva_rate, tax_rate)
     values ($1,$2,$3,1,10,20,99)`, [ph, sid, p20.rows[0].id]);
  await db.query(
    `insert into sale_items (pharmacy_id, sale_id, medication_id, quantity, unit_price, tva_rate, tax_rate)
     values ($1,$2,$3,1,10,0,99)`, [ph, sid, p0.rows[0].id]);
  const r = await db.query(
    `select m.tva_rate as produit, si.tax_rate as stocke
     from sale_items si join medications m on m.id = si.medication_id
     where si.sale_id = $1 order by m.tva_rate desc`, [sid]);
  let ok = true;
  for (const row of r.rows) {
    const pass = Number(row.stocke) === Number(row.produit) && Number(row.stocke) !== 99;
    console.log(`  produit=${row.produit} ecrit=99 stocke=${row.stocke} -> ${pass ? "TRIGGER OK" : "ECHEC"}`);
    if (!pass) ok = false;
  }
  await db.query("ROLLBACK");
  console.log("ROLLBACK effectue (aucune donnee ecrite) :", ok ? "PREUVE VALIDE" : "PREUVE INVALIDE");
  if (!ok) process.exit(1);
} catch (e) {
  await db.query("ROLLBACK").catch(() => {});
  console.error("ERREUR:", e.message);
  process.exit(1);
} finally { await db.end(); }


