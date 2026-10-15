// Cycle POS complet : sous-paiement refusé (400) + vente TTC correcte +
// stock décrémenté (RPC medication_stock_map) + cohérence TVA interne.
// Nettoyage : la vente porte notes=CYCLE_POS_TEST →
// `node scripts/cleanup_test_sales.mjs --yes` la supprime (DELETE /sales : 405
// par conception, jamais de dure suppression via l'API).
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
console.log('> Login OK');
const H = { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` };

const stockOf = async (id) => {
  const r = await fetch(`${BASE}/catalog/medications/stock?ids=${id}`, { headers: H });
  const j = await r.json();
  const row = (j.data ?? []).find((e) => e.medication_id === id);
  return Number(row?.quantity ?? NaN);
};

// Produit de test connu (fiche = source de vérité TVA)
const sr = await fetch(`${BASE}/catalog/medications?q=TEST_PHARMA_PLUS_StockNormal_A&limit=5`, { headers: H });
const rows = (await sr.json()).data || [];
if (!rows.length) { console.error('PRODUIT TEST ABSENT'); process.exit(1); }
const p = rows[0];
const pid = p.id;
const price = Number(p.price_sale);
const tva = Number(p.tva_rate);
const stockBefore = await stockOf(pid);
console.log(`Produit: ${p.name} prix=${price} stock=${stockBefore} tva=${tva}`);

const saleBody = (payAmount) => ({
  branch_id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  sale_type: 'pos',
  items: [{ medication_id: pid, quantity: 1, unit_price: price, tva_rate: tva, discount: 0 }],
  payments: [{ method: 'cash', amount: payAmount }],
  customer_id: null,
  notes: 'CYCLE_POS_TEST',
});

let pass = 0, fail = 0;
const check = (name, ok, extra = '') => {
  if (ok) { pass++; console.log(`  OK ${name} ${extra}`); }
  else { fail++; console.log(`  ECHEC ${name} ${extra}`); }
};

// ---- 1) Test négatif : sous-paiement du total TTC → 400 PAYMENT_INSUFFISANT
const expectedTax = Math.round(price * tva) / 100;
const expectedTotal = price + expectedTax;
const under = await fetch(`${BASE}/sales`, {
  method: 'POST', headers: H, body: JSON.stringify(saleBody(price)),
});
const underJ = await under.json();
check('sous-paiement refuse', under.status === 400 && underJ.error?.code === 'PAYMENT_INSUFFISANT',
  `status=${under.status} code=${underJ.error?.code}`);

// ---- 2) Test positif : règlement TTC + 10 de marge (monnaie rendue)
const paid = Math.round((expectedTotal + 10) * 100) / 100;
const cr = await fetch(`${BASE}/sales`, {
  method: 'POST', headers: H, body: JSON.stringify(saleBody(paid)),
});
const created = await cr.json();
if (!cr.ok) {
  console.error('CREATE FAILED:', JSON.stringify(created).slice(0, 500));
  check('creation vente', false, `status=${cr.status}`);
} else {
  const sale = created.data ?? created;
  console.log(`> Vente ${sale.number} total=${sale.total}`);
  check('creation vente', !!sale.id && sale.number?.startsWith('POS-'), `${sale.number}`);

  const div = await fetch(`${BASE}/sales/${sale.id}`, { headers: H });
  const s = (await div.json()).data ?? {};
  const net = Number(s.subtotal), tax = Number(s.tax_total),
    tot = Number(s.total), disc = Number(s.discount_total ?? 0),
    paidSrv = Number(s.paid_amount), changeSrv = Number(s.change_amount);
  check('coherence interne total = subtotal + tva - remise',
    Math.abs(net + tax - disc - tot) < 0.011,
    `sub=${net} tva=${tax} disc=${disc} tot=${tot}`);
  check('TVA depuis fiche produit', Math.abs(tax - (Math.round(net * tva) / 100)) < 0.021,
    `tax=${tax} attendu≈${expectedTax} (tva=${tva}%)`);
  check('encaisse >= total TTC', paidSrv + 0.009 >= tot, `paid=${paidSrv} tot=${tot}`);
  check('monnaie rendue = encaisse - total', Math.abs(changeSrv - (paidSrv - tot)) < 0.011,
    `change=${changeSrv}`);
  check('statut completed', s.status === 'completed', `status=${s.status}`);

  const stockAfter = await stockOf(pid);
  check('stock decremente de 1', stockAfter === stockBefore - 1,
    `${stockBefore} -> ${stockAfter}`);
  console.log(`> Vente CYCLE_POS_TEST a nettoyer : node scripts/cleanup_test_sales.mjs --yes`);
}

console.log(`\nRESULTAT: ${pass} pass / ${fail} fail`);
process.exit(fail ? 1 : 0);
