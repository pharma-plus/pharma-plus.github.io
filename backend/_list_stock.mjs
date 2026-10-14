const BASE = 'https://lwepnnecnrqdzadesyqo.supabase.co/functions/v1/pharma-api/api/v1';

const loginRes = await fetch(`${BASE}/auth/login`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    email: 'superadmin@pharmamarocgold.com',
    password: 'SuperAdmin_2026!',
  }),
});
const loginData = await loginRes.json();
const token = loginData.accessToken || loginData.data?.accessToken;
if (!token) { console.error('LOGIN FAILED'); process.exit(1); }

// Stock balances
const r = await fetch(`${BASE}/stock/balances?limit=200`, {
  headers: { Authorization: `Bearer ${token}` },
});
const data = await r.json();
const rows = data.data || data;
console.log(`GET /stock/balances: ${Array.isArray(rows) ? rows.length : 0} lignes`);
console.log('\n=== TOUS LES PRODUITS EN STOCK ===');
for (const row of rows) {
  console.log(`med_id=${row.medication_id} | qty=${row.quantity} | name=${row.medication_name || 'N/A'}`);
}
