import { requireIsolatedTestEnv } from "./scripts/test_env.mjs";
const { BASE: ORIGIN, email, password } = requireIsolatedTestEnv({ script: "_test_dashboard.mjs", mutations: false });
const BASE = ORIGIN + "/functions/v1/pharma-api/api/v1";
const loginRes = await fetch(`${BASE}/auth/login`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    email: email,
    password: password,
  }),
});
const loginData = await loginRes.json();
const token = loginData.accessToken || loginData.data?.accessToken;
if (!token) { console.error('LOGIN FAILED'); process.exit(1); }

// Dashboard stats
const r = await fetch(`${BASE}/dashboard/overview`, {
  headers: { Authorization: `Bearer ${token}` },
});
const data = await r.json();
console.log('=== DASHBOARD STATS ===');
console.log(JSON.stringify(data, null, 2).slice(0, 2000));
