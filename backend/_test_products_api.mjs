import { requireIsolatedTestEnv } from "./scripts/test_env.mjs";
import "dotenv/config";

const { BASE: ORIGIN, email, password } = requireIsolatedTestEnv({ script: "_test_products_api.mjs", mutations: false });
const BASE = ORIGIN + "/functions/v1/pharma-api";

const loginRes = await fetch(`${BASE}/auth/login`, {
  method: "POST", headers: { "Content-Type": "application/json" },
  body: JSON.stringify({ email: email, password: password }),
});
const login = await loginRes.json();
const token = login?.data?.accessToken;
const H = { "Content-Type": "application/json", Authorization: `Bearer ${token}` };

const r = await fetch(`${BASE}/reports/products`, { headers: H });
const j = await r.json();
console.log("products rows:");
for (const row of j?.data ?? []) console.log(" ", JSON.stringify(row));

const r2 = await fetch(`${BASE}/reports/employees`, { headers: H });
const j2 = await r2.json();
console.log("\nemployees rows:", JSON.stringify(j2?.data ?? []).slice(0, 400));
