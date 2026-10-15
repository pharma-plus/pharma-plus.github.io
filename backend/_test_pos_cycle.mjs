// Cycle POS complet : vente + paiement cash réel + validations + cleanup.
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
if (!token) {
  console.error('LOGIN FAILED:', JSON.stringify(loginData).slice(0, 300));
  process.exit(1);
}
console.log('✓ Login OK');
const H = {
  'Content-Type': 'application/json',
  Authorization: `Bearer ${token}`,
};

// Produit de test connu
const sr = await fetch(`${BASE}/catalog/medications?q=TEST_PHARMA_PLUS_StockNormal_A&limit=5`, { headers: H });
const rows = (await sr.json()).data || [];
if (!rows.length) { console.error('PRODUIT TEST ABSENT'); process.exit(1); }
const p = rows[0];
const pid = p.id;
const price = Number(p.price_sale ?? p.priceSale);
const stockBefore = Number(p.stock_quantity ?? p.stockQuantity);
console.log(`Produit: ${p.name} prix=${price} stock=${stockBefore} tva=${p.tva_rate ?? p.tvaRate ?? '?'}`);

// Vente 1x cash montant exact
const saleBody = {
  branch_id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  sale_type: 'direct',
  items: [{ medication_id: pid, quantity: 1, unit_price: price, tva_rate: 0, tax_rate: 0, discount: 0 }],
  payments: [{ method: 'cash', amount: price }],
  customer_id: null,
  notes: 'CYCLE_POS_TEST',
};
const cr = await fetch(`${BASE}/sales`, { method: 'POST', headers: H, body: JSON.stringify(saleBody) });
const created = await cr.json();
if (!cr.ok) {
  console.error('CREATE FAILED:', JSON.stringify(created).slice(0, 500));
  process.exit(1);
}
const sale = created.data ?? created;
console.log(`✓ Vente ${sale.number} total=${sale.total} subtotal=${sale.subtotal} tax=${sale.tax_total} status=${sale.status}`);

// Stock après
const sr2 = await fetch(`${BASE}/catalog/medications?q=TEST_PHARMA_PLUS_StockNormal_A&limit=5`, { headers: H });
const rows2 = (await sr2.json()).data || [];
const stockAfter = Number(rows2[0]?.stock_quantity ?? rows2[0]?.stockQuantity);
console.log(`Stock: ${stockBefore} → ${stockAfter} (${stockAfter - stockBefore})`);

// Écart TVA Edge vs DB (formule historique 20 %)
const div = await fetch(`${BASE}/sales/${sale.id}`, { headers: H });
const saleFull = (await div.json()).data ?? {};
console.log(`Vente relue: tax_total=${saleFull.tax_total}`);

let pass = 0, fail = 0;
const check = (name, ok, extra = '') => {
  if (ok) { pass++; console.log(`  ✓ ${name} ${extra}`); }
  else { fail++; console.log(`  ✗ ${name} ${extra}`); }
};
check('paiement créé (nb >= 1)', Number(sale.paid_amount ?? 0) >= price, `paid=${sale.paid_amount}`);
check('stock décrémenté de 1', stockAfter === stockBefore - 1, `${stockBefore}→${stockAfter}`);
check('total = prix (TVA 0)', Math.abs(Number(sale.total) - price) < 0.011, `total=${sale.total}`);
check('tax_total = 0', Math.abs(Number(sale.tax_total ?? 0)) < 0.011, `tax=${sale.tax_total}`);
check('montant payé = total', Math.abs(Number(sale.paid_amount ?? 0) - Number(sale.total)) < 0.011,
  `paid=${sale.paid_amount} total=${sale.total}`);

// Cleanup : suppression de la vente de test
const del = await fetch(`${BASE}/sales/${sale.id}`, { method: 'DELETE', headers: H });
console.log(`Cleanup DELETE /sales/${sale.id} → ${del.status}`);

// Vérifier que le stock est restauré (trigger) ou constater
const sr3 = await fetch(`${BASE}/catalog/medications?q=TEST_PHARMA_PLUS_StockNormal_A&limit=5`, { headers: H });
const rows3 = (await sr3.json()).data || [];
const stockFinal = Number(rows3[0]?.stock_quantity ?? rows3[0]?.stockQuantity);
console.log(`Stock après suppression vente: ${stockFinal} (attendu restauré ${stockBefore} si trigger, sinon ${stockAfter})`);

console.log(`\nRESULTAT: ${pass} pass / ${fail} fail`);
process.exit(fail ? 1 : 0);
