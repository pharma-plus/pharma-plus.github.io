import "dotenv/config";

const BASE = process.env.EDGE_BASE || "https://lwepnnecnrqdzadesyqo.supabase.co/functions/v1/pharma-api";
const EMAIL = process.env.SUPER_ADMIN_EMAIL;
const PASSWORD = process.env.SUPER_ADMIN_PASSWORD;

if (!EMAIL || !PASSWORD) { console.error("MISSING CREDS"); process.exit(1); }

const loginRes = await fetch(`${BASE}/auth/login`, {
  method: "POST", headers: { "Content-Type": "application/json" },
  body: JSON.stringify({ email: EMAIL, password: PASSWORD }),
});
const login = await loginRes.json();
const token = login?.data?.accessToken || login?.data?.token || login?.token;
if (!token) { console.error("LOGIN FAIL", JSON.stringify(login).slice(0,300)); process.exit(1); }

const H = { "Content-Type": "application/json", Authorization: `Bearer ${token}` };

async function t(label, url) {
  const r = await fetch(url, { headers: H });
  const j = await r.json().catch(() => ({}));
  const rows = j?.data;
  console.log(`--- ${label} [${r.status}]`);
  if (Array.isArray(rows)) {
    console.log(`  rows=${rows.length}  first=${JSON.stringify(rows[0] ?? null).slice(0,140)}`);
  } else {
    console.log(`  ${JSON.stringify(rows).slice(0,300)}`);
  }
}

await t("financial", `${BASE}/reports/financial`);
await t("sales", `${BASE}/reports/sales`);
await t("products", `${BASE}/reports/products`);
await t("stock", `${BASE}/reports/stock`);
await t("employees", `${BASE}/reports/employees`);
await t("stock-balance", `${BASE}/stock/balances?limit=3`);
console.log("DONE");
