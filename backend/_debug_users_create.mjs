const BASE =
  "https://lwepnnecnrqdzadesyqo.supabase.co/functions/v1/pharma-api/api/v1";

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

const login = await req("POST", "/auth/login", {
  body: {
    email: "superadmin@pharmamarocgold.com",
    password: "SuperAdmin_2026!",
  },
});
const token = login.json?.accessToken || login.json?.data?.accessToken;
console.log("login:", login.status);

const r = await req("POST", "/users", {
  token,
  body: {
    email: "pin.flow2@test.ma",
    password: "PinFlowTest123!",
    first_name: "Pin",
    last_name: "Flow",
  },
});
console.log("POST /users:", r.status, JSON.stringify(r.json).slice(0, 500));

// Nettoyage de ce compte de debug.
const { Client } = await import("pg");
const url = (process.env.DATABASE_URL ?? "").replace(/[?&]sslmode=[^&]*/g, "");
const db = new Client({ connectionString: url, ssl: { rejectUnauthorized: false } });
await db.connect();
await db.query("delete from users where email = 'pin.flow2@test.ma'");
await db.query("delete from auth.users where email = 'pin.flow2@test.ma'");
await db.end();
console.log("cleanup ok");
