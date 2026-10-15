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
const headers = { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' };

// Tester TOUS les produits en stock (27)
const stockRes = await fetch(`${BASE}/stock/balances?limit=50`, { headers });
const stockData = await stockRes.json();
const balances = stockData.data || stockData;

console.log(`=== ${balances.length} produits avec stock ===\n`);

// Grouper par medication_id (un produit peut avoir plusieurs lignes de lot)
const byMed = new Map();
for (const b of balances) {
  const id = b.medication_id;
  byMed.set(id, (byMed.get(id) ?? 0) + Number(b.quantity ?? 0));
}

// Vérifier chaque produit
for (const [medId, totalStock] of byMed) {
  const r = await fetch(`${BASE}/catalog/medications/stock?ids=${medId}`, { headers });
  const d = await r.json();
  const qty = (d.data || d)[0]?.quantity ?? 0;
  const nameRes = await fetch(`${BASE}/catalog/medications?q=&limit=1`, { headers }); // skip name
  console.log(`  ${medId.slice(0, 8)}... | stock: ${qty}`);
}

console.log(`\nTotal produits uniques en stock: ${byMed.size}`);

// Vente test sur Doliprane (produit démo b0000000-...-0001)
const dolipraneId = 'b0000000-0000-0000-0000-000000000001';
const stockBefore = await fetch(`${BASE}/catalog/medications/stock?ids=${dolipraneId}`, { headers });
const sbData = await stockBefore.json();
const before = (sbData.data || sbData)[0]?.quantity ?? 0;
console.log(`\n=== Doliprane stock AVANT: ${before} ===`);

// Vente de 1 unité
const saleRes = await fetch(`${BASE}/sales`, {
  method: 'POST',
  headers,
  body: JSON.stringify({
    branchId: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    saleType: 'pos',
    clientSaleId: `test-global-${Date.now()}`,
    items: [{ medication_id: dolipraneId, quantity: 1, unit_price: 4.2 }],
  }),
});
const saleData = await saleRes.json();
if (saleData.error) {
  console.error('ERREUR:', JSON.stringify(saleData.error));
} else {
  console.log(`Vente: ${saleData.data?.number} — total: ${saleData.data?.total}`);
}

// Stock APRÈS
const stockAfter = await fetch(`${BASE}/catalog/medications/stock?ids=${dolipraneId}`, { headers });
const saData = await stockAfter.json();
const after = (saData.data || saData)[0]?.quantity ?? 0;
console.log(`Doliprane stock APRÈS: ${after}`);
console.log(before === after + 1 ? '✅ DÉCRÉMENTÉ' : '❌ PAS DÉCRÉMENTÉ');
