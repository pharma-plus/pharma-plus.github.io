import "dotenv/config";

const BASE = process.env.EDGE_BASE || "https://lwepnnecnrqdzadesyqo.supabase.co/functions/v1/pharma-api";
const EMAIL = process.env.SUPER_ADMIN_EMAIL;
const PASSWORD = process.env.SUPER_ADMIN_PASSWORD;

const loginRes = await fetch(`${BASE}/auth/login`, {
  method: "POST", headers: { "Content-Type": "application/json" },
  body: JSON.stringify({ email: EMAIL, password: PASSWORD }),
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
