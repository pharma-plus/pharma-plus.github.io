import { requireIsolatedTestEnv, assertNonProductionDb } from "./scripts/test_env.mjs";
const { BASE: ORIGIN, email, password } = requireIsolatedTestEnv({ script: "_neg_hash_test.mjs", mutations: true });
assertNonProductionDb(process.env.DATABASE_URL, { script: "_neg_hash_test.mjs" });
const API = ORIGIN + "/functions/v1/pharma-api";
import "dotenv/config";
import pg from "pg";
const raw = process.env.DATABASE_URL;
const c = new pg.Client({ connectionString: raw.replace(/[?&]sslmode=[^&]*/g, ""), ssl: { rejectUnauthorized: false } });
await c.connect();
const login = await fetch(API + "/auth/login", {
  method: "POST", headers: { "content-type": "application/json" },
  body: JSON.stringify({ email: email, password: password }),
}).then((r) => r.json());
const token = login?.data?.accessToken;
const PID = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa";
const { rows: [med] } = await c.query(`
  SELECT m.id, m.price_sale FROM medications m
  JOIN stock_balances sb ON sb.medication_id = m.id AND sb.pharmacy_id = m.pharmacy_id
  WHERE m.pharmacy_id=$1 AND m.status='available' AND m.tva_rate=0 AND sb.quantity>=1 LIMIT 1`, [PID]);
const { rows: [br] } = await c.query(
  `SELECT branch_id AS id FROM stock_balances WHERE pharmacy_id=$1 AND medication_id=$2 AND branch_id IS NOT NULL LIMIT 1`, [PID, med.id]);

// Payload IDENTIQUE au panel Flutter, clientSaleId NEGATIF (hashCode Dart)
const body = {
  branchId: br.id, saleType: "pos", clientSaleId: "-1847293847",
  items: [{ medication_id: med.id, quantity: 1, unit_price: Number(med.price_sale), discount: 0 }],
  payments: [{ method: "cash", amount: Number(med.price_sale), received: Number(med.price_sale), change: 0 }],
};
const r = await fetch(API + "/sales", {
  method: "POST",
  headers: { authorization: `Bearer ${token}`, "content-type": "application/json", "x-pharmacy-id": PID },
  body: JSON.stringify(body),
});
const j = await r.json();
console.log("STATUS", r.status);
console.log("OK/ERR", JSON.stringify(j).slice(0, 300));
await c.end();
