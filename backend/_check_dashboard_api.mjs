const BASE = 'https://lwepnnecnrqdzadesyqo.supabase.co/functions/v1/pharma-api/api/v1';

const loginRes = await fetch(`${BASE}/auth/login`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ email: 'superadmin@pharmamarocgold.com', password: 'SuperAdmin_2026!' }),
});
const loginData = await loginRes.json();
const token = loginData.accessToken || loginData.data?.accessToken;
const headers = { Authorization: `Bearer ${token}` };

const r = await fetch(`${BASE}/dashboard/overview`, { headers });
const d = await r.json();
const data = d.data || d;

console.log('=== DASHBOARD OVERVIEW ===');
console.log('medications (catalogue):', data.medications);
console.log('products_in_stock:', data.products_in_stock);
console.log('low_stock:', data.low_stock);
console.log('stock_units:', data.stock_units);
console.log('sales_today:', data.sales_today);
console.log('revenue_today:', data.revenue_today);
console.log('');
console.log('=== ALERTS ===');
console.log(JSON.stringify(data.alerts, null, 2));
