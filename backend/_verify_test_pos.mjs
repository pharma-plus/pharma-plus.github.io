import { requireIsolatedTestEnv } from "./scripts/test_env.mjs";
const { BASE: ORIGIN, email, password } = requireIsolatedTestEnv({ script: "_verify_test_pos.mjs", mutations: false });
const BASE = ORIGIN + "/functions/v1/pharma-api/api/v1";
// Login super admin
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
if (!token) {
  console.error('LOGIN FAILED:', JSON.stringify(loginData).slice(0, 300));
  process.exit(1);
}
console.log('✓ Login OK');

// Rechercher les produits TEST dans le catalogue POS
const searchRes = await fetch(`${BASE}/catalog/medications?q=TEST_PHARMA_PLUS&limit=25`, {
  headers: { Authorization: `Bearer ${token}` },
});
const searchData = await searchRes.json();
const rows = searchData.data || searchData;
console.log(`\n=== RÉSULTATS POS: ${Array.isArray(rows) ? rows.length : 0} produits ===`);

if (Array.isArray(rows)) {
  for (const r of rows) {
    console.log(`${r.name} | prix=${r.price_sale ?? r.priceSale} | stock=${r.stock_quantity ?? r.stockQuantity ?? 'N/A'}`);
  }
}

// Vérifier le stock via l'endpoint dédié
if (Array.isArray(rows) && rows.length > 0) {
  const ids = rows.map(r => r.id).join(',');
  const stockRes = await fetch(`${BASE}/catalog/medications/stock?ids=${ids}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  const stockData = await stockRes.json();
  const stockRows = stockData.data || stockData;
  console.log(`\n=== STOCK: ${Array.isArray(stockRows) ? stockRows.length : 0} entrées ===`);
  if (Array.isArray(stockRows)) {
    for (const s of stockRows) {
      console.log(`${s.medication_id}: ${s.quantity ?? s.stock ?? JSON.stringify(s)}`);
    }
  }
}
