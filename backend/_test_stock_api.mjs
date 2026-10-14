const BASE = 'https://lwepnnecnrqdzadesyqo.supabase.co/functions/v1/pharma-api/api/v1';

// Login
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

// Test /stock/balances
const r = await fetch(`${BASE}/stock/balances?limit=200`, {
  headers: { Authorization: `Bearer ${token}` },
});
const data = await r.json();
const rows = data.data || data;
console.log(`GET /stock/balances: ${Array.isArray(rows) ? rows.length : 0} lignes`);
if (Array.isArray(rows) && rows.length > 0) {
  console.log(`\nPremières lignes:`);
  for (const row of rows.slice(0, 5)) {
    console.log(JSON.stringify(row).slice(0, 200));
  }
  // Compter combien sont des produits TEST
  const testRows = rows.filter(r => 
    (r.name && r.name.includes('TEST_PHARMA_PLUS')) ||
    (r.medication_name && r.medication_name.includes('TEST_PHARMA_PLUS'))
  );
  console.log(`\nProduits TEST dans les résultats: ${testRows.length}`);
}
