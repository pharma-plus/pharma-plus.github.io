import { requireIsolatedTestEnv, assertNonProductionDb } from "./scripts/test_env.mjs";
const { BASE: ORIGIN, email, password } = requireIsolatedTestEnv({ script: "_pos_e2e_sale.mjs", mutations: true });
assertNonProductionDb(process.env.DATABASE_URL, { script: "_pos_e2e_sale.mjs" });
const API = ORIGIN + "/functions/v1/pharma-api";
// VENTE RÉELLE DE BOUT EN BOUT — validation du fix POS TVA 0 (Edge 2.4.1).
// Login super admin (.env, jamais affiché) → POST /sales sur l'API publiée
// avec un médicament TVA 0 → vérifs métier DB + idempotence rejeu.
import "dotenv/config";
import pg from "pg";

const PID = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa";

const raw = process.env.DATABASE_URL;
const c = new pg.Client({ connectionString: raw.replace(/[?&]sslmode=[^&]*/g, ""), ssl: { rejectUnauthorized: false } });
await c.connect();

const out = [];
const ok = (name, cond, extra = "") => { out.push(`${cond ? "PASS" : "FAIL"} | ${name}${extra ? " | " + extra : ""}`); return cond; };

// 1) Version live
const root = await fetch(API + "/").then((r) => r.json()).catch(() => null);
ok("Edge live = 2.4.1", root?.version === "2.4.1", `v=${root?.version}`);

// 2) Login super admin via l'Edge (POST /auth/login)
const login = await fetch(API + "/auth/login", {
  method: "POST",
  headers: { "content-type": "application/json" },
  body: JSON.stringify({ email: email, password: password }),
}).then((r) => r.json());
const token = login?.data?.accessToken;
ok("Login super admin", Boolean(token), token ? "" : "pas de token");
if (!token) { console.log(out.join("\n")); process.exit(1); }

// 3) Médicament TVA 0 avec stock > 0 (pharmacie de test)
const { rows: [med] } = await c.query(`
  SELECT m.id, m.name, m.price_sale, m.tva_rate, sb.quantity
  FROM medications m
  JOIN stock_balances sb ON sb.medication_id = m.id AND sb.pharmacy_id = m.pharmacy_id
  WHERE m.pharmacy_id = $1 AND m.status = 'available' AND m.tva_rate = 0
    AND sb.branch_id IS NOT NULL AND sb.quantity >= 2
  LIMIT 1`, [PID]);
ok("Médicament TVA 0 avec stock", Boolean(med), med ? `${med.name} stock=${med.quantity} prix=${med.price_sale}` : "aucun");
if (!med) { console.log(out.join("\n")); process.exit(1); }

const { rows: [branch] } = await c.query(
  `SELECT sb.branch_id AS id, b.name FROM stock_balances sb JOIN branches b ON b.id = sb.branch_id
   WHERE sb.pharmacy_id = $1 AND sb.medication_id = $2 AND sb.quantity >= 2 LIMIT 1`, [PID, med.id]);
ok("Branch avec stock", Boolean(branch), branch?.name ?? "");

const { rows: [stockBefore] } = await c.query(
  `SELECT COALESCE(SUM(quantity),0) AS q FROM stock_balances WHERE pharmacy_id=$1 AND medication_id=$2`, [PID, med.id]);

const clientSaleId = `test-pos-fix-${Date.now()}`;
const saleBody = {
  branchId: branch.id,
  saleType: "pos",
  clientSaleId,
  items: [{ medication_id: med.id, quantity: 1, unit_price: Number(med.price_sale) }],
  payments: [{ method: "cash", amount: Number(med.price_sale), received: Number(med.price_sale), change: 0 }],
  notes: "VENTE DE TEST correction POS TVA 0 (2.4.1)",
};

// 4) POST /sales — total serveur doit ÊTRE le prix (TVA 0), pas +20 %
const auth = { authorization: `Bearer ${token}`, "content-type": "application/json", "x-pharmacy-id": PID };
const saleRes = await fetch(API + "/sales", { method: "POST", headers: auth, body: JSON.stringify(saleBody) }).then((r) => r.json());
const saleId = saleRes?.data?.id;
ok("POST /sales acceptée", Boolean(saleId), `number=${saleRes?.data?.number ?? "-"} dup=${saleRes?.data?.duplicate ?? false}`);
const expected = Number(Number(med.price_sale).toFixed(2));
ok("Total = prix TVA 0 (pas +20%)", Number(saleRes?.data?.total) === expected,
  `serveur=${saleRes?.data?.total} attendu=${expected} (ancien bug: ${ (expected*1.2).toFixed(2) })`);

// 5) Vérifs DB métier (pas seulement HTTP 200)
if (saleId) {
  const { rows: [s] } = await c.query(`SELECT * FROM sales WHERE id=$1`, [saleId]);
  ok("DB sale: status=completed", s?.status === "completed", s?.status);
  ok("DB sale: tax_total=0", Number(s?.tax_total) === 0, s?.tax_total);
  ok("DB sale: paid=total", Number(s?.paid_amount) === Number(s?.total), `paid=${s?.paid_amount} total=${s?.total}`);
  const { rows: [li] } = await c.query(`SELECT tax_rate, line_total FROM sale_items WHERE sale_id=$1`, [saleId]);
  ok("DB sale_items: tax_rate=0", Number(li?.tax_rate) === 0, li?.tax_rate);
  ok("DB sale_items: line_total=net (pas +20%)", Number(li?.line_total) === expected, `line_total=${li?.line_total}`);
  const { rows: [p] } = await c.query(`SELECT amount, status FROM payments WHERE sale_id=$1`, [saleId]);
  ok("DB payment: completed + montant", p?.status === "completed" && Number(p?.amount) === expected, `${p?.status} ${p?.amount}`);
  const { rows: [mv] } = await c.query(
    `SELECT COUNT(*)::int AS n FROM stock_movements WHERE reference_type='sale' AND reference_id=$1 AND movement_type='sale'`, [saleId]);
  ok("Stock: exactement 1 mouvement de vente", mv?.n === 1, `n=${mv?.n}`);
  const { rows: [stockAfter] } = await c.query(
    `SELECT COALESCE(SUM(quantity),0) AS q FROM stock_balances WHERE pharmacy_id=$1 AND medication_id=$2`, [PID, med.id]);
  ok("Stock: diminué d'une seule unité", Number(stockAfter.q) === Number(stockBefore.q) - 1, `${stockBefore.q} -> ${stockAfter.q}`);

  // 6) Rejeu idempotent (double clic / réseau lent)
  const replay = await fetch(API + "/sales", { method: "POST", headers: auth, body: JSON.stringify(saleBody) }).then((r) => r.json());
  ok("Rejeu: duplicate=true, même vente", replay?.data?.duplicate === true && replay?.data?.id === saleId, `id=${replay?.data?.id}`);
  const { rows: [cnt] } = await c.query(`SELECT COUNT(*)::int AS n FROM sales WHERE client_sale_id=$1`, [clientSaleId]);
  ok("Rejeu: 1 seule vente en base", cnt?.n === 1, `n=${cnt?.n}`);
  const { rows: [stockReplay] } = await c.query(
    `SELECT COALESCE(SUM(quantity),0) AS q FROM stock_balances WHERE pharmacy_id=$1 AND medication_id=$2`, [PID, med.id]);
  ok("Rejeu: stock inchangé", Number(stockReplay.q) === Number(stockAfter.q), `${stockAfter.q} -> ${stockReplay.q}`);
}

console.log(out.join("\n"));
const fails = out.filter((l) => l.startsWith("FAIL")).length;
console.log(`\nVENTE_BOUT_EN_BOUT: ${out.length - fails}/${out.length} ${fails === 0 ? "REUSSI" : "ECHECS"}`);
await c.end();
process.exit(fails === 0 ? 0 : 1);
