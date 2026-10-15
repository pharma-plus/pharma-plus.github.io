// =============================================================================
// PHARMA+ — WORKER DE SAUVEGARDE (P1, 15/10/2026)
// pg_dump → SHA-256 → chiffrement AES-256-GCM → téléversement Edge/Storage.
//
// Usage :
//   node scripts/backup_worker.mjs                 traite toutes les jobs pending
//   node scripts/backup_worker.mjs --create        crée une job puis la traite
//   node scripts/backup_worker.mjs --verify        vérifie la dernière job completed
//   node scripts/backup_worker.mjs --verify <id>   vérifie une job précise
//   node scripts/backup_worker.mjs --decrypt <id> <fichier>   déschiffre en local
//
// Restauration (manuelle, non automatisée — risque destructeur) :
//   1) node scripts/backup_worker.mjs --decrypt <id> dump.dump
//   2) pg_restore --clean --if-exists --dbname="<DATABASE_URL>" dump.dump
//      (approbation backups:approve requise côté API pour toute action restore)
//
// Variables (backend/.env) : DATABASE_URL, BACKUP_ENCRYPTION_KEY,
//   BACKUP_DIR, SUPER_ADMIN_EMAIL, SUPER_ADMIN_PASSWORD.
// Sortie : bucket Storage `backups` + copie locale BACKUP_DIR + table `backups`.
// Aucun secret n'est journalisé.
// =============================================================================
import { Client } from "pg";
import "dotenv/config";
import { createHash, createCipheriv, createDecipheriv } from "node:crypto";
import { spawnSync } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync, mkdirSync, existsSync, readdirSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve, dirname, basename } from "node:path";
import { fileURLToPath } from "node:url";

const API =
  "https://lwepnnecnrqdzadesyqo.supabase.co/functions/v1/pharma-api/api/v1";
const MAGIC = Buffer.from("PHB1"); // magic + version du conteneur chiffré
const IV_LEN = 12;
const TAG_LEN = 16;

const args = process.argv.slice(2);
const has = (f) => args.includes(f);
const val = (f, i = 1) => {
  const k = args.indexOf(f);
  return k >= 0 ? args[k + i] : undefined;
};

// --------------------------------------------------------------- connexions
const rawDbUrl = process.env.DATABASE_URL ?? "";
const pgUrl = rawDbUrl.replace(/[?&]sslmode=[^&]*/g, "");
if (!rawDbUrl || !process.env.BACKUP_ENCRYPTION_KEY || !process.env.SUPER_ADMIN_EMAIL) {
  console.error("ENV manquante : DATABASE_URL, BACKUP_ENCRYPTION_KEY, SUPER_ADMIN_EMAIL");
  process.exit(2);
}
let db = new Client({ connectionString: pgUrl, ssl: { rejectUnauthorized: false } });
await db.connect();
{
  const who = await db.query("select current_database() as db, current_user as u");
  console.log(`connecte : db=${who.rows[0].db} user=${who.rows[0].u}`);
}
// Reconnexion apres spawnSync(pg_dump) : le pooler Supabase peut re-router la
// session pendant que le process bloque l'event-loop — une requete suivante
// partait alors vers une base sans la table `backups` (42P01).
async function reconnectDb() {
  try { await db.end(); } catch (_) {}
  db = new Client({ connectionString: pgUrl, ssl: { rejectUnauthorized: false } });
  await db.connect();
  const w = await db.query(
    "select current_database() as db, to_regclass('backups') as bak",
  );
  console.log(`reconnecte : db=${w.rows[0].db} backups=${w.rows[0].bak ?? "ABSENT"}`);
}

const BACKUP_DIR = resolve(process.env.BACKUP_DIR || join(dirname(fileURLToPath(import.meta.url)), "..", "backups"));

function die(msg) {
  console.error(`ERREUR : ${msg}`);
  process.exit(1);
}

// ------------------------------------------------------------- pg_dump bin
function findPgDump() {
  if (process.env.PG_DUMP_PATH && existsSync(process.env.PG_DUMP_PATH))
    return process.env.PG_DUMP_PATH;
  if (process.platform === "win32") {
    const base = "C:\\Program Files\\PostgreSQL";
    if (existsSync(base)) {
      for (const v of readdirSync(base).sort().reverse()) {
        const p = join(base, v, "bin", "pg_dump.exe");
        if (existsSync(p)) return p;
      }
    }
  }
  return "pg_dump"; // PATH (Linux/macOS/CI)
}

function dumpConnectionUrl() {
  let u = rawDbUrl;
  if (/supabase\.co/.test(u) && !/sslmode=/.test(u))
    u += (u.includes("?") ? "&" : "?") + "sslmode=require";
  return u;
}

// ------------------------------------------------------------- chiffrement
function key() {
  return createHash("sha256").update(String(process.env.BACKUP_ENCRYPTION_KEY)).digest();
}
function encrypt(plain) {
  const iv = Buffer.alloc(IV_LEN);
  for (let i = 0; i < IV_LEN; i += 4)
    iv.writeUInt32LE((Math.random() * 0xffffffff) >>> 0, i);
  const c = createCipheriv("aes-256-gcm", key(), iv);
  const ct = Buffer.concat([c.update(plain), c.final()]);
  return Buffer.concat([MAGIC, iv, c.getAuthTag(), ct]);
}
function decrypt(blob) {
  if (blob.subarray(0, 4).toString() !== "PHB1") throw new Error("magic PHB1 absent");
  const iv = blob.subarray(4, 4 + IV_LEN);
  const tag = blob.subarray(4 + IV_LEN, 4 + IV_LEN + TAG_LEN);
  const ct = blob.subarray(4 + IV_LEN + TAG_LEN);
  const d = createDecipheriv("aes-256-gcm", key(), iv);
  d.setAuthTag(tag);
  return Buffer.concat([d.update(ct), d.final()]);
}
const sha256 = (b) => createHash("sha256").update(b).digest("hex");

// ------------------------------------------------------------------- Edge
async function edge(method, path, { token, body, raw, headers } = {}) {
  const res = await fetch(`${API}${path}`, {
    method,
    headers: {
      ...(body !== undefined || raw !== undefined ? { "Content-Type": "application/json" } : {}),
      ...(raw !== undefined ? { "Content-Type": "application/octet-stream" } : {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(headers ?? {}),
    },
    body: raw !== undefined ? raw : body === undefined ? undefined : JSON.stringify(body),
  });
  if (path.endsWith("/artifact") && method === "GET") {
    if (!res.ok) throw new Error(`artifact GET ${res.status}`);
    return Buffer.from(await res.arrayBuffer());
  }
  let json = null;
  try {
    json = await res.json();
  } catch (_) {}
  return { status: res.status, json };
}
async function login() {
  const r = await edge("POST", "/auth/login", {
    body: { email: process.env.SUPER_ADMIN_EMAIL, password: process.env.SUPER_ADMIN_PASSWORD },
  });
  const t = r.json?.accessToken || r.json?.data?.accessToken;
  if (!t) die(`login Edge échoué (status ${r.status})`);
  return t;
}

async function failJob(id, message) {
  try {
    await db.query(
      "update backups set status='failed', error=$1, completed_at=now() where id=$2",
      [String(message).slice(0, 500), id],
    );
  } catch (e2) {
    console.error(`  failJob : update impossible (${e2.message}) — reconnexion + 1 nouvelle tentative`);
    try {
      await reconnectDb();
      await db.query(
        "update backups set status='failed', error=$1, completed_at=now() where id=$2",
        [String(message).slice(0, 500), id],
      );
      console.log(`  failJob : marquee failed apres reconnexion`);
    } catch (e3) {
      console.error(`  failJob : echec definitif (${e3.message}) — job ${id} laissee en l'etat`);
    }
  }
}

// ------------------------------------------------------------------- jobs
async function createJob() {
  const u = await db.query(
    "select pharmacy_id from users where email=$1",
    [process.env.SUPER_ADMIN_EMAIL],
  );
  if (!u.rowCount) die("superadmin introuvable");
  const r = await db.query(
    `insert into backups (pharmacy_id, type, scope, status)
     values ($1, 'manual', 'full', 'pending') returning id`,
    [u.rows[0].pharmacy_id],
  );
  console.log(`job créée : ${r.rows[0].id}`);
  return r.rows[0].id;
}

async function processJob(id, token) {
  const { rows } = await db.query(
    "select id, pharmacy_id, status from backups where id=$1",
    [id],
  );
  if (!rows[0]) return console.log(`job ${id} introuvable — ignorée`);
  const job = rows[0];
  if (job.status !== "pending")
    return console.log(`job ${job.id} status=${job.status} — ignorée (pending seulement)`);

  await db.query(
    "update backups set status='running', started_at=now(), error=null where id=$1",
    [job.id],
  );
  console.log(`job ${job.id} : pg_dump…`);
  const t0 = Date.now();
  const tmp = mkdtempSync(join(tmpdir(), "pharma-bak-"));
  const dumpPath = join(tmp, "pg.dump");
  try {
    const pgd = findPgDump();
    const r = spawnSync(pgd, [`--dbname=${dumpConnectionUrl()}`, "--format=custom", "--no-owner", "--no-privileges", "-f", dumpPath], {
      encoding: "utf8",
      maxBuffer: 64 * 1024 * 1024,
    });
    await reconnectDb();
    if (r.status !== 0)
      throw new Error(`pg_dump exit ${r.status} : ${(r.stderr || "").split("\n").slice(0, 3).join(" | ")}`);
    const { statSync } = await import("node:fs");
    const dumpSize = statSync(dumpPath).size;
    const dumpBytes = (await import("node:fs")).readFileSync(dumpPath);
    const sum = sha256(dumpBytes);
    const enc = encrypt(dumpBytes);
    console.log(
      `  dump ${(dumpSize / 1024 / 1024).toFixed(2)} Mo → chiffré ${(enc.length / 1024 / 1024).toFixed(2)} Mo (${Date.now() - t0} ms)`,
    );

    // copie locale de défense
    const localDir = join(BACKUP_DIR, job.pharmacy_id);
    mkdirSync(localDir, { recursive: true });
    const localFile = join(localDir, `${new Date().toISOString().replace(/[:.]/g, "-")}-${job.id}.dump.enc`);
    writeFileSync(localFile, enc);

    // téléversement (Edge met la ligne completed)
    const up = await edge("POST", `/backups/${job.id}/artifact`, {
      token,
      raw: enc,
      headers: { "x-checksum": sum },
    });
    if (up.status !== 201)
      throw new Error(`upload artifact status ${up.status} : ${up.json?.error?.message ?? "?"}`);

    const after = await db.query("select status, size_bytes, checksum from backups where id=$1", [job.id]);
    const a = after.rows[0];
    const ok = a.status === "completed" && a.checksum === sum;
    console.log(
      `  OK job ${job.id} status=${a.status} size=${a.size_bytes} sha=${sum.slice(0, 12)}… | local ${basename(localFile)}`,
    );
    if (!ok) throw new Error(`état final inattendu (status=${a.status})`);
  } catch (e) {
    await failJob(job.id, e.message);
    console.error(`  FAIL job ${job.id} : ${e.message}`);
    process.exitCode = 1;
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
}

async function verifyJob(id, token) {
  const { rows } = await db.query(
    "select id, status, checksum from backups where id=$1",
    [id],
  );
  const job = rows[0];
  if (!job) return console.log(`job ${id} introuvable`);
  if (job.status !== "completed" && job.status !== "verified")
    return console.log(`job ${id} status=${job.status} — rien à vérifier`);
  try {
    const blob = await edge("GET", `/backups/${id}/artifact`, { token });
    const plain = decrypt(blob);
    const sum = sha256(plain);
    if (sum !== job.checksum) throw new Error(`SHA-256 différent (corruption ?)`);
    await db.query(
      "update backups set status='verified', error=null where id=$1",
      [id],
    );
    console.log(`job ${id} VÉRIFIÉ : déchiffré ${(plain.length / 1024 / 1024).toFixed(2)} Mo, SHA-256 identique`);
  } catch (e) {
    await db.query(
      "update backups set status='failed', error=$1 where id=$2",
      [`vérification: ${e.message}`.slice(0, 500), id],
    );
    console.error(`job ${id} VÉRIFICATION ÉCHOUÉE : ${e.message}`);
    process.exitCode = 1;
  }
}

async function decryptToFile(id, outFile) {
  const token = await login();
  const blob = await edge("GET", `/backups/${id}/artifact`, { token });
  const plain = decrypt(blob);
  const { rows } = await db.query("select checksum from backups where id=$1", [id]);
  if (rows[0]?.checksum && sha256(plain) !== rows[0].checksum)
    die("SHA-256 mismatch — artefact corrompu, restauration refusée");
  writeFileSync(resolve(outFile), plain);
  console.log(`déschiffré → ${resolve(outFile)} (${(plain.length / 1024 / 1024).toFixed(2)} Mo)`);
}

// ------------------------------------------------------------------ run
try {
  if (has("--decrypt")) {
    const id = val("--decrypt");
    const out = val("--decrypt", 2);
    if (!id || !out) die("--decrypt <id> <fichier>");
    await decryptToFile(id, out);
  } else if (has("--verify")) {
    const token = await login();
    let id = val("--verify");
    if (!id || id.startsWith("--")) {
      const r = await db.query(
        "select id from backups where status in ('completed','verified') order by created_at desc limit 1",
      );
      id = r.rows[0]?.id;
      if (!id) die("aucune job completed à vérifier");
    }
    await verifyJob(id, token);
  } else {
    if (has("--create")) await createJob();
    const token = await login();
    const { rows } = await db.query(
      "select id from backups where status='pending' order by created_at asc",
    );
    if (!rows.length) {
      console.log("aucune job pending — utilise --create pour en créer une");
    } else {
      console.log(`${rows.length} job(s) pending`);
      for (const r of rows) await processJob(r.id, token);
    }
  }
} finally {
  await db.end();
}
