const BASE = 'https://lwepnnecnrqdzadesyqo.supabase.co/functions/v1/pharma-api/api/v1';

const loginRes = await fetch(`${BASE}/auth/login`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ email: 'superadmin@pharmamarocgold.com', password: 'SuperAdmin_2026!' }),
});
const loginData = await loginRes.json();
const token = loginData.accessToken || loginData.data?.accessToken;
const headers = { Authorization: `Bearer ${token}` };

// Récupérer les stock_balances
const balRes = await fetch(`${BASE}/stock/balances?limit=50`, { headers });
const balData = await balRes.json();
const balances = balData.data || balData;
const ids = [...new Set(balances.map(b => b.medication_id).filter(Boolean))];
console.log(`Stock balances: ${balances.length} lignes, ${ids.length} produits uniques`);

// Test filtre id=in.(...)
const url = `${BASE}/catalog/medications?limit=500&id=in.(${ids.join(',')})`;
const medRes = await fetch(url, { headers });
const medData = await medRes.json();
const meds = medData.data || medData;
console.log(`Médicaments retournés: ${meds.length}`);

// Afficher les 5 premiers
for (const m of meds.slice(0, 5)) {
  console.log(`  ${m.name} — ${m.price_sale} MAD — ${m.dosage ?? ''} ${m.form ?? ''}`);
}
