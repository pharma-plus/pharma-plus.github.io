import { requireIsolatedTestEnv } from "./scripts/test_env.mjs";
const { BASE: ORIGIN, email, password } = requireIsolatedTestEnv({ script: "_test_stock_decrement.mjs", mutations: true });
const BASE = ORIGIN + "/functions/v1/pharma-api/api/v1";
// Login
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
const headers = { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' };

// 1. Trouver un produit TEST avec du stock
const searchRes = await fetch(`${BASE}/catalog/medications?q=TEST_PHARMA_PLUS_StockNormal_A&limit=1`, { headers });
const searchData = await searchRes.json();
const med = (searchData.data || searchData)[0];
if (!med) { console.error('PRODUIT TEST NON TROUVÉ'); process.exit(1); }
console.log(`Produit: ${med.name} (id=${med.id})`);

// 2. Vérifier le stock AVANT
const stockRes = await fetch(`${BASE}/catalog/medications/stock?ids=${med.id}`, { headers });
const stockData = await stockRes.json();
const stockBefore = (stockData.data || stockData)[0]?.quantity ?? 0;
console.log(`Stock AVANT: ${stockBefore}`);

// 3. Vente de 2 unités
const saleBody = {
  branchId: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  saleType: 'pos',
  clientSaleId: `test-stock-${Date.now()}`,
  items: [
    {
      medication_id: med.id,
      quantity: 2,
      unit_price: med.price_sale,
    },
  ],
};
const saleRes = await fetch(`${BASE}/sales`, {
  method: 'POST',
  headers,
  body: JSON.stringify(saleBody),
});
const saleData = await saleRes.json();
if (saleData.error) {
  console.error('ERREUR VENTE:', JSON.stringify(saleData.error));
  process.exit(1);
}
console.log(`Vente créée: ${saleData.data?.number ?? saleData.data?.id} — total: ${saleData.data?.total}`);

// 4. Vérifier le stock APRÈS
const stockRes2 = await fetch(`${BASE}/catalog/medications/stock?ids=${med.id}`, { headers });
const stockData2 = await stockRes2.json();
const stockAfter = (stockData2.data || stockData2)[0]?.quantity ?? 0;
console.log(`Stock APRÈS: ${stockAfter}`);
console.log(`Différence: ${stockBefore} → ${stockAfter} (-${stockBefore - stockAfter})`);

if (stockAfter === stockBefore - 2) {
  console.log('✅ STOCK DÉCRÉMENTÉ CORRECTEMENT');
} else {
  console.log('❌ STOCK NON DÉCRÉMENTÉ');
}
