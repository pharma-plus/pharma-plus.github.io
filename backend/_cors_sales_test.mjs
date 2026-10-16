import { requireIsolatedTestEnv } from "./scripts/test_env.mjs";
const { BASE: ROOT, email, password } = requireIsolatedTestEnv({ script: "_cors_sales_test.mjs", mutations: true });
const API = ROOT + "/functions/v1/pharma-api";
// Reproduit EXACTEMENT le fetch du front web (Origin Pages + headers).
const ORIGIN = "https://pharma-plus.github.io";

// 1) Preflight OPTIONS (déclenché par POST avec Content-Type json + Authorization)
const opt = await fetch(API + "/sales", {
  method: "OPTIONS",
  headers: {
    "Origin": ORIGIN,
    "Access-Control-Request-Method": "POST",
    "Access-Control-Request-Headers": "authorization,content-type,x-pharmacy-id,accept",
  },
});
console.log("OPTIONS status:", opt.status);
for (const [k, v] of opt.headers) {
  if (k.toLowerCase().startsWith("access-control")) console.log("  ", k + ":", v);
}

// 2) Login puis POST /sales avec Origin (comme le front)
const login = await fetch(API + "/auth/login", {
  method: "POST",
  headers: { "content-type": "application/json", "Origin": ORIGIN },
  body: JSON.stringify({ email: email, password: password }),
}).then((r) => r.json());
const token = login?.data?.accessToken;

const res = await fetch(API + "/sales", {
  method: "POST",
  headers: {
    "Origin": ORIGIN,
    "authorization": "Bearer " + token,
    "content-type": "application/json",
    "x-pharmacy-id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
    "accept": "application/json",
  },
  body: JSON.stringify({
    branchId: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
    saleType: "pos",
    clientSaleId: "cors-test-" + Date.now(),
    items: [{ medication_id: "00000000-0000-0000-0000-000000000000", quantity: 1, unit_price: 1 }],
    payments: [{ method: "cash", amount: 1, received: 1, change: 0 }],
  }),
});
console.log("POST /sales status:", res.status);
for (const [k, v] of res.headers) {
  if (k.toLowerCase().startsWith("access-control")) console.log("  ", k + ":", v);
}
const bodyText = await res.text();
console.log("body:", bodyText.slice(0, 250));
