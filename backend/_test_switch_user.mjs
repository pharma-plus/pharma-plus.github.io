// =============================================================================
// TESTS 17.C (caisse partagee / changement d'utilisateur PIN) + association
// employe <-> compte + 17.F (isolation deux pharmacies).
// Usage : node _test_switch_user.mjs
// =============================================================================
import { Client } from "pg";
import "dotenv/config";

const BASE =
  "https://lwepnnecnrqdzadesyqo.supabase.co/functions/v1/pharma-api/api/v1";

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
  const t =
    r.json?.accessToken || r.json?.data?.accessToken || null;
  return { status: r.status, token: t, json: r.json };
}

// Purge des residus de runs precedents (soft-deletes + comptes de test).
await cleanupResidue("avant :");

// ---------------------------------------------------------------- SETUP
console.log("=== SETUP ===");
const admin = await login(
  "superadmin@pharmamarocgold.com",
  "SuperAdmin_2026!",
);
check(!!admin.token, "login superadmin");
const T1 = admin.token;

const usersRes = await req("GET", "/users?limit=50", { token: T1 });
const users = usersRes.json?.data ?? [];
const byEmail = (e) => users.find((u) => (u.email ?? "").toLowerCase() === e);
const dach = byEmail("d.ach@pharma.ma");
const userRbac = byEmail("test.rbac@pharma-demo.ma");
check(!!dach, "utilisateur caissier d.ach present");
check(!!userRbac, "utilisateur test.rbac present");

// PINs connus pour le test
const pinDach = await req("PUT", `/users/${dach.id}/pin`, {
  token: T1,
  body: { pin: "1234" },
});
check(pinDach.status === 200, "PUT /users/:id/pin (d.ach = 1234)", `status=${pinDach.status}`);
const pinRbac = await req("PUT", `/users/${userRbac.id}/pin`, {
  token: T1,
  body: { pin: "5678" },
});
check(pinRbac.status === 200, "PUT /users/:id/pin (test.rbac = 5678)", `status=${pinRbac.status}`);
const pinOwn = await req("PUT", "/auth/pin", {
  token: T1,
  body: { pin: "9876" },
});
check(pinOwn.status === 200, "PUT /auth/pin (superadmin = 9876)", `status=${pinOwn.status}`);

const rolesRes = await req("GET", "/roles?limit=50", { token: T1 });
const roles = rolesRes.json?.data ?? [];
const roleCaissier =
  roles.find((r) => /caiss/i.test(String(r.name ?? "")))?.id ??
  roles[0]?.id ??
  null;
check(!!roleCaissier, "role pour le compte de test", `role=${roleCaissier}`);

// Compte de test DEDIQUE sans PIN (fixture autonome : un compte demo peut
// porter un PIN selon les seeds — l'etat ne doit jamais etre suppose).
const noPinEmail = "sanspin.switch@test.ma";
const noPinCreate = await req("POST", "/users", {
  token: T1,
  body: {
    email: noPinEmail,
    password: "SansPinTest123!",
    role_id: roleCaissier,
    first_name: "Sans",
    last_name: "PIN",
  },
});
check(
  noPinCreate.status === 200 || noPinCreate.status === 201,
  "creation du compte sans PIN",
  `status=${noPinCreate.status}`,
);
const noPinId = noPinCreate.json?.data?.id ?? null;

// ------------------------------------------------- 17.C : CAISSE PARTAGEE
console.log("\n=== 17.C CAISSE PARTAGEE / SWITCH-USER ===");

const lock = await req("POST", "/auth/lock", { token: T1, body: {} });
check(lock.status === 200, "verrouillage d'ecran (POST /auth/lock)", `status=${lock.status}`);

const lockedGet = await req("GET", "/users?limit=1", { token: T1 });
check(
  lockedGet.status === 423 && lockedGet.json?.error?.code === "SESSION_LOCKED",
  "session verrouillee : GET /users repond 423",
  `status=${lockedGet.status} code=${lockedGet.json?.error?.code}`,
);

// Switch WHILE locked (LOCK_EXEMPT) : nouveau caissier identifie par PIN
const sw1 = await req("POST", "/auth/switch-user", {
  token: T1,
  body: { identifier: "d.ach@pharma.ma", pin: "1234" },
});
const T2 = sw1.json?.data?.accessToken ?? sw1.json?.accessToken ?? null;
check(
  sw1.status === 200 && !!T2,
  "switch (verrouille) d.ach@pharma.ma + PIN 1234 -> nouvelle session",
  `status=${sw1.status}`,
);
check(T2 && T2 !== T1, "jeton du cible different du jeton appelant");

const me2 = await req("GET", "/auth/me", { token: T2 });
const email2 =
  me2.json?.data?.email ?? me2.json?.email ?? me2.json?.data?.user?.email ?? "";
check(
  String(email2).toLowerCase() === "d.ach@pharma.ma",
  "GET /auth/me (T2) = d.ach@pharma.ma (identite appliquee)",
  `email=${email2}`,
);

const browse = await req("GET", "/catalog/medications?limit=1", { token: T2 });
check(browse.status === 200, "T2 (caissier) browse catalogue", `status=${browse.status}`);

const usersT2 = await req("GET", "/users?limit=1", { token: T2 });
check(
  usersT2.status === 403 || usersT2.status === 401,
  "T2 (caissier) sans acces a la gestion des utilisateurs",
  `status=${usersT2.status}`,
);

// Erreurs de switch
const swBad = await req("POST", "/auth/switch-user", {
  token: T1,
  body: { identifier: "d.ach@pharma.ma", pin: "0000" },
});
check(
  swBad.status === 401 && swBad.json?.error?.code === "INVALID_CREDENTIALS",
  "PIN incorrect -> 401 INVALID_CREDENTIALS",
  `status=${swBad.status} code=${swBad.json?.error?.code}`,
);
const swUnknown = await req("POST", "/auth/switch-user", {
  token: T1,
  body: { identifier: "inconnu@nullepart.ma", pin: "1234" },
});
check(
  swUnknown.status === 401 && swUnknown.json?.error?.code === "INVALID_CREDENTIALS",
  "identifiant inconnu -> 401 (pas d'enumeration)",
  `status=${swUnknown.status}`,
);
const swNoPin = await req("POST", "/auth/switch-user", {
  token: T1,
  body: { identifier: noPinEmail, pin: "1234" },
});
check(
  swNoPin.status === 400 && swNoPin.json?.error?.code === "PIN_NOT_SET",
  "compte sans PIN -> 400 PIN_NOT_SET",
  `status=${swNoPin.status} code=${swNoPin.json?.error?.code}`,
);

// Retour vers le superadmin (session generale preservee)
const swBack = await req("POST", "/auth/switch-user", {
  token: T1,
  body: { identifier: "superadmin@pharmamarocgold.com", pin: "9876" },
});
const T3 = swBack.json?.data?.accessToken ?? swBack.json?.accessToken ?? null;
check(
  swBack.status === 200 && !!T3,
  "retour switch -> superadmin@pharmamarocgold.com",
  `status=${swBack.status}`,
);
const me3 = await req("GET", "/auth/me", { token: T3 });
const email3 = String(me3.json?.data?.email ?? me3.json?.email ?? "").toLowerCase();
check(email3 === "superadmin@pharmamarocgold.com", "T3 = superadmin", `email=${email3}`);

// L'autre appareil (T2, caissier) n'a PAS ete deconnecte par les switches
const stillT2 = await req("GET", "/auth/me", { token: T2 });
check(
  stillT2.status === 200,
  "session T2 (autre employe) toujours valide apres switches",
  `status=${stillT2.status}`,
);

// Deverrouillage T1 pour la suite
const unlock = await req("POST", "/auth/pin/verify", {
  token: T1,
  body: { pin: "9876" },
});
check(
  unlock.status === 200,
  "deverrouillage T1 via POST /auth/pin/verify",
  `status=${unlock.status}`,
);
const unlock2 = await req("POST", "/auth/pin/verify", {
  token: T1,
  body: { pin: "9876" },
});
if (unlock.status !== 200) {
  // parfois 400 si deja debloquee : on accepte les deux
  check(
    unlock2.status === 200 || unlock2.status === 400,
    "verif PIN (deverrouillage idempotent)",
    `status=${unlock2.status}`,
  );
}
const afterUnlock = await req("GET", "/users?limit=1", { token: T1 });
check(
  afterUnlock.status === 200,
  "T1 deverrouillee : GET /users 200",
  `status=${afterUnlock.status}`,
);

// Retrait du compte sans PIN (T1 deverrouillee ici — sinon 423 SESSION_LOCKED)
if (noPinId) {
  const delNoPin = await req("DELETE", `/users/${noPinId}`, { token: T1 });
  check(delNoPin.status === 200 || delNoPin.status === 204, "retrait du compte sans PIN", `status=${delNoPin.status}`);
}

// --------------------------------------------- ASSOCIATION EMPLOYE-COMPTE
console.log("\n=== ASSOCIATION EMPLOYE <-> COMPTE UTILISATEUR ===");

// Emails horodatés : re-execution sans collision (DELETE /users est un
// soft-delete volontaire — la vraie purge se fait en fin de script).
const TS = Date.now();
const EMPLINK = `emp.link.${TS}@pharma-demo.ma`;
const EMPLINK2 = `emp.link2.${TS}@pharma-demo.ma`;

const EMP = {
  y: "f0000000-0000-0000-0000-000000000101", // Youssef
  s: "f0000000-0000-0000-0000-000000000102", // Salma
  k: "f0000000-0000-0000-0000-000000000103", // Karim
};

const create1 = await req("POST", "/users", {
  token: T1,
  body: {
    email: EMPLINK,
    password: "TestPass123!",
    first_name: "Emp",
    last_name: "Link",
    role_id: roleCaissier,
    employee_id: EMP.y,
  },
});
check(
  create1.status >= 200 && create1.status < 300,
  "POST /users avec employee_id (creation + association)",
  `status=${create1.status} ${create1.json?.error?.message ?? ""}`,
);
const afterCreate1 = await req("GET", "/users?limit=100", { token: T1 });
const newUser1 =
  (afterCreate1.json?.data ?? []).find((u) => u.email === EMPLINK)?.id ??
  create1.json?.data?.id;
check(!!newUser1, "compte emp.link cree", `id=${newUser1}`);

const listAfter1 = await req("GET", "/users?limit=100", { token: T1 });
const row1 = (listAfter1.json?.data ?? []).find(
  (u) => u.email === EMPLINK,
);
check(
  row1?.employee_id === EMP.y,
  "GET /users : employee_id renseigne",
  `employee_id=${row1?.employee_id}`,
);
check(
  String(row1?.employee_name ?? "").includes("Youssef"),
  "GET /users : employee_name enrichi",
  `employee_name=${row1?.employee_name}`,
);

// Conflit : meme employe pour un 2e compte
const create2 = await req("POST", "/users", {
  token: T1,
  body: {
    email: EMPLINK2,
    password: "TestPass123!",
    first_name: "Emp",
    last_name: "Link2",
    role_id: roleCaissier,
    employee_id: EMP.y,
  },
});
check(
  create2.status === 409,
  "employe deja rattache -> 409 CONFLICT",
  `status=${create2.status} code=${create2.json?.error?.code}`,
);

// Relien (changement d'employe)
const relink = await req("PUT", `/users/${newUser1}`, {
  token: T1,
  body: { employee_id: EMP.s },
});
check(
  relink.status === 200,
  "PUT /users/:id employee_id=Salma (relien)",
  `status=${relink.status} ${relink.json?.error?.message ?? ""}`,
);
const listAfter2 = await req("GET", "/users?limit=100", { token: T1 });
const row2 = (listAfter2.json?.data ?? []).find(
  (u) => u.email === EMPLINK,
);
check(row2?.employee_id === EMP.s, "employee_id = Salma apres relien");

// Deliaison
const unlink = await req("PUT", `/users/${newUser1}`, {
  token: T1,
  body: { employee_id: null },
});
check(
  unlink.status === 200,
  "PUT /users/:id employee_id=null (deliaison)",
  `status=${unlink.status} ${unlink.json?.error?.message ?? ""}`,
);
const listAfter3 = await req("GET", "/users?limit=100", { token: T1 });
const row3 = (listAfter3.json?.data ?? []).find(
  (u) => u.email === EMPLINK,
);
check(row3?.employee_id == null, "employee_id nul apres deliaison");

// Desactivation (DELETE /users = soft-delete volontaire : l'historique
// et l'audit sont conserves, la vraie purge se fait en fin de script).
const del = await req("DELETE", `/users/${newUser1}`, { token: T1 });
check(
  del.status === 200 && del.json?.data?.status === "inactive",
  "DELETE /users/:id -> desactivation (soft-delete, statut inactive)",
  `status=${del.status} status_retourne=${del.json?.data?.status}`,
);

// ------------------------------------- 17.F : ISOLATION DEUX PHARMACIES
console.log("\n=== 17.F ISOLATION MULTI-PHARMACIES ===");

const slugIso = `pharma-test-iso-${Date.now()}`;
const createPh = await req("POST", "/pharmacies", {
  token: T1,
  body: {
    name: "Pharmacie Test ISO",
    slug: slugIso,
    city: "Casablanca",
    admin_email: "iso.admin@test.ma",
    admin_password: "IsolationB_2026!",
  },
});
check(
  createPh.status === 201 && !!createPh.json?.data?.id,
  "POST /pharmacies (creation pharmacie B + admin)",
  `status=${createPh.status} ${createPh.json?.error?.message ?? ""}`,
);
const phB = createPh.json?.data?.id ?? null;
check(!!createPh.json?.data?.admin_user_id, "compte admin pharmacie B provisionne");

const loginB = await login("iso.admin@test.ma", "IsolationB_2026!");
check(!!loginB.token, "login admin pharmacie B", `status=${loginB.status}`);
const TB = loginB.token;

if (TB) {
  const listB = await req("GET", "/users?limit=100", { token: TB });
  const emailsB = (listB.json?.data ?? []).map((u) => (u.email ?? "").toLowerCase());
  check(
    emailsB.length > 0 &&
        !emailsB.includes("d.ach@pharma.ma") &&
        !emailsB.includes("superadmin@pharmamarocgold.com"),
    "B ne voit AUCUN utilisateur de la pharmacie A",
    `count=${emailsB.length}`,
  );

  const aUser = dach.id;
  const getForeign = await req("GET", `/users/${aUser}`, { token: TB });
  check(
    getForeign.status === 404 || getForeign.status === 403,
    "GET /users/{id A} depuis B -> 404/403",
    `status=${getForeign.status}`,
  );

  const patchForeign = await req("PATCH", `/employees/${EMP.y}`, {
    token: TB,
    body: { salary: 1 },
  });
  check(
    patchForeign.status === 404,
    "PATCH /employees/{id A} depuis B -> 404 (pas de faux succes)",
    `status=${patchForeign.status}`,
  );

  const empAfter = await req("GET", `/employees/${EMP.y}`, { token: T1 });
  check(
    (empAfter.json?.data?.salary ?? 0) !== 1,
    "salaire employe A intact apres tentative B",
    `salary=${empAfter.json?.data?.salary}`,
  );

  const linkForeign = await req("POST", "/users", {
    token: TB,
    body: {
      email: "x.employees.a@test.ma",
      password: "TestPass123!",
      first_name: "X",
      last_name: "Y",
      employee_id: EMP.y,
    },
  });
  check(
    linkForeign.status === 400,
    "POST /users B avec employee_id de A -> 400 employe inconnu",
    `status=${linkForeign.status} code=${linkForeign.json?.error?.code}`,
  );

  const switchForeign = await req("POST", "/auth/switch-user", {
    token: TB,
    body: { identifier: "d.ach@pharma.ma", pin: "1234" },
  });
  check(
    switchForeign.status === 401,
    "switch-user B vers utilisateur de A -> 401 (cross-tenant interdit)",
    `status=${switchForeign.status} code=${switchForeign.json?.error?.code}`,
  );

  // Nettoyage pharmacie B (si le FK le permet)
  if (phB) {
    const delPh = await req("DELETE", `/pharmacies/${phB}`, { token: T1 });
    console.log(
      `  INFO  DELETE pharmacie B (test) -> status=${delPh.status} ${delPh.json?.error?.message ?? ""}`,
    );
  }
}

// ------------------------------------------------- NETTOYAGE DB (residus)
async function cleanupResidue(label) {
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
      const un = await db.query(
        "update employees set user_id = null where user_id in (select id from users where email like 'emp.link%')",
      );
      const d1 = await db.query(
        "delete from users where email like 'emp.link%' or email like 'x.employees%' or email like 'sanspin.switch%'",
      );
      const d2 = await db.query(
        "delete from auth.users where email like 'emp.link%' or email like 'x.employees%' or email like 'sanspin.switch%' or email = 'iso.admin@test.ma'",
      );
      const d3 = await db.query(
        "delete from pharmacies where slug like 'pharma-test-iso%'",
      );
      console.log(
        `  ${label} employes delies=${un.rowCount} | public.users=${d1.rowCount} | auth.users=${d2.rowCount} | pharmacies test=${d3.rowCount}`,
      );
    } finally {
      await db.end();
    }
  } catch (e) {
    console.log(`  INFO  nettoyage impossible : ${e.message}`);
  }
}

console.log("\n=== NETTOYAGE DB (residus de test) ===");
await cleanupResidue("apres :");

// ------------------------------------------------------------------ RESUME
console.log(`\n=== RESUME : ${pass} PASS / ${fail} FAIL ===`);
if (failures.length) {
  console.log("Echecs :");
  for (const f of failures) console.log(`  - ${f}`);
}
process.exit(fail ? 1 : 0);
