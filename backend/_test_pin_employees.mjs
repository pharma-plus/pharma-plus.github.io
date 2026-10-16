import { requireIsolatedTestEnv } from "./scripts/test_env.mjs";
const { BASE: ORIGIN, email, password } = requireIsolatedTestEnv({ script: "_test_pin_employees.mjs", mutations: true });
const BASE = ORIGIN + "/functions/v1/pharma-api/api/v1";
const loginRes = await fetch(`${BASE}/auth/login`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ email: email, password: password }),
});
const loginData = await loginRes.json();
const token = loginData.accessToken || loginData.data?.accessToken;
if (!token) { console.error('LOGIN FAILED'); process.exit(1); }
const headers = { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' };

// 1. Lister les utilisateurs
const usersRes = await fetch(`${BASE}/users?limit=10`, { headers });
const usersData = await usersRes.json();
const users = usersData.data || usersData;
console.log(`Utilisateurs: ${users.length}`);
for (const u of users) {
  console.log(`  ${u.id} | ${u.email} | role=${u.role_id ? 'oui' : 'non'} | status=${u.status}`);
}

// 2. Test PUT /users/{id}/pin sur le 2e user (pas le superadmin)
const target = users.find(u => !u.email?.includes('superadmin'));
if (!target) { console.error('Pas de cible'); process.exit(1); }
console.log(`\n=== Test PUT /users/${target.id.slice(0, 8)}/pin ===`);

// PIN invalide (3 chiffres)
const badRes = await fetch(`${BASE}/users/${target.id}/pin`, {
  method: 'PUT', headers, body: JSON.stringify({ pin: '123' }),
});
const bad = await badRes.json();
console.log(`PIN invalide (123): status=${badRes.status} => ${JSON.stringify(bad.error || bad.data)}`);

// PIN valide
const okRes = await fetch(`${BASE}/users/${target.id}/pin`, {
  method: 'PUT', headers, body: JSON.stringify({ pin: '1234' }),
});
const ok = await okRes.json();
console.log(`PIN valide (1234): status=${okRes.status} => ${JSON.stringify(ok.error || ok.data)}`);

// 3. Test PUT /auth/pin (son propre PIN)
const ownRes = await fetch(`${BASE}/auth/pin`, {
  method: 'PUT', headers, body: JSON.stringify({ pin: '9876' }),
});
const own = await ownRes.json();
console.log(`PUT /auth/pin (9876): status=${ownRes.status} => ${JSON.stringify(own.error || own.data)}`);

// 4. Vérifier la colonne employees cnss/address via API
const empRes = await fetch(`${BASE}/employees?limit=1`, { headers });
const empData = await empRes.json();
const emp = (empData.data || empData)[0];
console.log(`\nEmployee cols: ${emp ? Object.keys(emp).join(', ') : 'aucun'}`);
console.log(`cnss: ${emp && 'cnss' in emp ? 'PRESENT' : 'ABSENT'}`);
console.log(`address: ${emp && 'address' in emp ? 'PRESENT' : 'ABSENT'}`);
