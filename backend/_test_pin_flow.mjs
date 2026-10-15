// =============================================================================
// §3D — Tests PIN : état, création, vérification valide/invalide, sans PIN,
// désactivation, permissions, switch-user + attribution de vente.
// Compte de test dédié créé puis supprimé (aucun compte de production touché).
// Usage : node _test_pin_flow.mjs
// =============================================================================
import { Client } from "pg";
import "dotenv/config";

const BASE =
  "https://lwepnnecnrqdzadesyqo.supabase.co/functions/v1/pharma-api/api/v1";
const TEST_EMAIL = "pin.flow@test.ma";
const TEST_PASS = "PinFlowTest123!";

let pass = 0;
let fail = 0;
const failures = [];
function check(cond, label, extra = "") {
  if (cond) {
    pass++;
    console.log(`  PASS  ${label}${extra ? " — " + extra : ""}`);
  } else {
    fail++;
    failures.push(label);
    console.log(`  FAIL  ${label}${extra ? " — " + extra : ""}`);
  }
}

async function req(method, path, { token, body } = {}) {
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  let json = null;
  try {
    json = await res.json();
  } catch (_) {}
  return { status: res.status, json };
}

async function login(email, password) {
  const r = await req("POST", "/auth/login", { body: { email, password } });
  return {
    status: r.status,
    token: r.json?.accessToken || r.json?.data?.accessToken || null,
    json: r.json,
  };
}

async function dbCleanup() {
  try {
    const dbUrl = (process.env.DATABASE_URL ?? "").replace(
      /[?&]sslmode=[^&]*/g,
      "",
    );
    const db = new Client({
      connectionString: dbUrl,
      ssl: { rejectUnauthorized: false },
    });
    await db.connect();
    try {
      const d1 = await db.query(
        "delete from users where email = $1",
        [TEST_EMAIL],
      );
      const d2 = await db.query(
        "delete from auth.users where email = $1",
        [TEST_EMAIL],
      );
      console.log(
        `  NETTOYAGE public.users=${d1.rowCount} auth.users=${d2.rowCount}`,
      );
    } finally {
      await db.end();
    }
  } catch (e) {
    console.log(`  INFO  nettoyage impossible : ${e.message}`);
  }
}

// Purge des résidus d'un run précédent.
await dbCleanup();

// ---------------------------------------------------------------- SETUP
console.log("=== SETUP ===");
const admin = await login(
  "superadmin@pharmamarocgold.com",
  "SuperAdmin_2026!",
);
check(!!admin.token, "login superadmin");
const T1 = admin.token;

// 1) /auth/me expose has_pin et JAMAIS pin_hash.
const me1 = await req("GET", "/auth/me", { token: T1 });
check(me1.status === 200, "GET /auth/me superadmin", `status=${me1.status}`);
check(
  typeof me1.json?.data?.has_pin === "boolean",
  "has_pin present dans /auth/me",
  `has_pin=${me1.json?.data?.has_pin}`,
);
check(
  me1.json?.data?.pin_hash === undefined,
  "pin_hash JAMAIS expose dans /auth/me",
);

// 2) GET /users expose has_pin sans pin_hash.
const usersRes = await req("GET", "/users?limit=50", { token: T1 });
const users = usersRes.json?.data ?? [];
check(
  users.every((u) => u.pin_hash === undefined && typeof u.has_pin === "boolean"),
  "GET /users : has_pin present, pin_hash absent",
);
const dach = users.find((u) => (u.email ?? "").toLowerCase() === "d.ach@pharma.ma");
const rbac = users.find(
  (u) => (u.email ?? "").toLowerCase() === "test.rbac@pharma-demo.ma",
);
check(!!dach && !!rbac, "comptes de demo presents");

// Rôle requis pour la création (POST /users exige role_id).
const rolesRes = await req("GET", "/roles?limit=50", { token: T1 });
const roles = rolesRes.json?.data ?? [];
const roleCaissier =
  roles.find((r) => /caiss/i.test(String(r.name ?? "")))?.id ?? roles[0]?.id ?? null;
check(!!roleCaissier, "role pour le compte de test", `role=${roleCaissier}`);

if (dach) {
  const p = await req("PUT", `/users/${dach.id}/pin`, {
    token: T1,
    body: { pin: "1234" },
  });
  check(p.status === 200, "PUT /users/:id/pin d.ach=1234", `status=${p.status}`);
}

// 3) Création du compte de test (session propre, PIN personnel).
const created = await req("POST", "/users", {
  token: T1,
  body: {
    email: TEST_EMAIL,
    password: TEST_PASS,
    first_name: "Pin",
    last_name: "Flow",
    role_id: roleCaissier,
  },
});
check(created.status === 201, "POST /users compte de test", `status=${created.status}`);
const testId = created.json?.data?.id ?? null;

const t = await login(TEST_EMAIL, TEST_PASS);
check(!!t.token, "login compte de test");
const TT = t.token;

// ------------------------------------------------------- PIN NON CONFIGURE
console.log("\n=== PIN NON CONFIGURE ===");
const meNoPin = await req("GET", "/auth/me", { token: TT });
check(
  meNoPin.json?.data?.has_pin === false,
  "has_pin=false avant configuration",
);
const verifyNoPin = await req("POST", "/auth/pin/verify", {
  token: TT,
  body: { pin: "1234" },
});
check(
  verifyNoPin.status === 400,
  "verify sans PIN configure -> 400 (PIN_NOT_SET)",
  `status=${verifyNoPin.status} code=${verifyNoPin.json?.error?.code}`,
);

// ------------------------------------------------------- VALIDATION FORMAT
console.log("\n=== VALIDATION FORMAT ===");
const badAlpha = await req("PUT", "/auth/pin", { token: TT, body: { pin: "abcd" } });
check(badAlpha.status === 400, "PUT /auth/pin alpha -> 400", `status=${badAlpha.status}`);
const badShort = await req("PUT", "/auth/pin", { token: TT, body: { pin: "12" } });
check(badShort.status === 400, "PUT /auth/pin 2 chiffres -> 400", `status=${badShort.status}`);

// ------------------------------------------------------- CREATION PIN
console.log("\n=== CREATION / MODIFICATION PIN ===");
const setPin = await req("PUT", "/auth/pin", { token: TT, body: { pin: "1357" } });
check(setPin.status === 200, "PUT /auth/pin valide (1357)", `status=${setPin.status}`);
const mePin = await req("GET", "/auth/me", { token: TT });
check(mePin.json?.data?.has_pin === true, "has_pin=true apres configuration");
check(
  mePin.json?.data?.pin_hash === undefined,
  "pin_hash toujours absent de /auth/me",
);

// ------------------------------------------------------- VERIFICATION
console.log("\n=== VERIFICATION PIN ===");
const okPin = await req("POST", "/auth/pin/verify", { token: TT, body: { pin: "1357" } });
check(okPin.status === 200, "verify PIN valide -> 200", `status=${okPin.status}`);
const badPin = await req("POST", "/auth/pin/verify", { token: TT, body: { pin: "9999" } });
check(badPin.status === 401, "verify PIN invalide -> 401", `status=${badPin.status}`);

// ------------------------------------------------------- SWITCH USER + VENTE
console.log("\n=== SWITCH USER + ATTRIBUTION VENTE ===");
const sw = await req("POST", "/auth/switch-user", {
  token: TT,
  body: { identifier: "d.ach@pharma.ma", pin: "1234" },
});
check(sw.status === 200, "switch-user vers d.ach (PIN 1234)", `status=${sw.status}`);
const swToken = sw.json?.accessToken || sw.json?.data?.accessToken || null;
check(!!swToken, "session swappee fournie");
if (swToken) {
  const meSw = await req("GET", "/auth/me", { token: swToken });
  check(
    meSw.json?.data?.id === dach?.id,
    "session swappee = d.ach",
    `id=${meSw.json?.data?.id}`,
  );
  // Vente attribuée à la personne authentifiée (d.ach), pas au compte d'origine.
  const sale = await req("POST", "/sales", {
    token: swToken,
    body: {
      branch_id: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
      sale_type: "direct",
      items: [
        {
          medication_id: "c08f0ba8-a4ce-4689-83c7-a07fe4e2ac46",
          quantity: 1,
          unit_price: 35,
        },
      ],
      payments: [{ method: "cash", amount: 35 }],
      notes: "PIN_FLOW_TEST",
    },
  });
  check(sale.status === 200 || sale.status === 201, "vente en session swappee", `status=${sale.status}`);
  const saleId = sale.json?.data?.id ?? null;
  if (saleId) {
    try {
      const dbUrl = (process.env.DATABASE_URL ?? "").replace(/[?&]sslmode=[^&]*/g, "");
      const db = new Client({ connectionString: dbUrl, ssl: { rejectUnauthorized: false } });
      await db.connect();
      try {
        const r = await db.query("select user_id from sales where id = $1", [saleId]);
        check(
          r.rows[0]?.user_id === dach?.id,
          "vente attribuee a d.ach (pas au compte d'origine)",
          `user_id=${r.rows[0]?.user_id}`,
        );
      } finally {
        await db.end();
      }
    } catch (e) {
      check(false, "lecture DB de la vente", e.message);
    }
  }
}

// ------------------------------------------------------- PERMISSIONS
console.log("\n=== PERMISSIONS ===");
if (swToken && rbac) {
  // d.ach (caissier) n'a pas users:edit : PUT /users/:id/pin doit être 403.
  const denied = await req("PUT", `/users/${rbac.id}/pin`, {
    token: swToken,
    body: { pin: "2468" },
  });
  check(
    denied.status === 403,
    "PUT /users/:id/pin sans users:edit -> 403",
    `status=${denied.status}`,
  );
  const deniedDel = await req("DELETE", `/users/${rbac.id}/pin`, {
    token: swToken,
  });
  check(
    deniedDel.status === 403,
    "DELETE /users/:id/pin sans users:edit -> 403",
    `status=${deniedDel.status}`,
  );
}

// ------------------------------------------------------- DESACTIVATION PIN
console.log("\n=== DESACTIVATION PIN ===");
if (testId) {
  const clear = await req("DELETE", `/users/${testId}/pin`, { token: T1 });
  check(clear.status === 200, "DELETE /users/:id/pin (admin)", `status=${clear.status}`);
  const meCleared = await req("GET", "/auth/me", { token: TT });
  check(meCleared.json?.data?.has_pin === false, "has_pin=false apres desactivation");
  const verifyCleared = await req("POST", "/auth/pin/verify", {
    token: TT,
    body: { pin: "1357" },
  });
  check(
    verifyCleared.status === 400,
    "verify apres desactivation -> 400 (PIN_NOT_SET)",
    `status=${verifyCleared.status} code=${verifyCleared.json?.error?.code}`,
  );
}

// ------------------------------------------------------- NETTOYAGE
console.log("\n=== NETTOYAGE ===");
await dbCleanup();

console.log(`\n=== RESUME : ${pass} PASS / ${fail} FAIL ===`);
if (failures.length) {
  console.log("Echecs :");
  for (const f of failures) console.log(`  - ${f}`);
}
process.exit(fail ? 1 : 0);
