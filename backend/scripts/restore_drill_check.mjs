// restore_drill_check.mjs — Exercice de restauration (restore-drill).
// Compare la base RESTAURÉE (locale, isolée) avec la base LIVE en lecture
// seule. Sortie : compteurs + écarts (noms de tables uniquement, aucun secret).
// Code retour 0 = parité acceptable ; 1 = écart métier inacceptable.
//
// Env requis :
//   DRILL_LOCAL_URL  — base restaurée (cluster isolé)
//   DATABASE_URL     — base live (lecture seule)
import 'dotenv/config';
import pg from 'pg';

const VOLATILE = /(^|\.)(sessions|refresh_tokens|mfa_amr_claims|audit_log_entries|audit_log|user_sessions|login_attempts|notifications|backups|objects|backup_logs)$/;
const ALLOW_MISSING_IN_RESTORED = new Set(['vault.secrets']);

const clean = (u) => (u ?? '').replace(/[?&]sslmode=[^&]*/g, '').replace(/[?&]ssl=[^&]*/g, '');

async function counts(connectionString, label, useSsl) {
  const c = new pg.Client({
    connectionString: clean(connectionString),
    // Live : TLS requis (pooler Supabase, sans vérif de CA — identique au
    // comportement de src/db/pool.js). Local : cluster isolé sans SSL.
    ...(useSsl ? { ssl: { rejectUnauthorized: false } } : {}),
    connectionTimeoutMillis: 20000,
  });
  await c.connect();
  const t = await c.query(`SELECT table_schema || '.' || table_name AS tn
    FROM information_schema.tables
    WHERE table_schema NOT IN ('pg_catalog','information_schema')
      AND table_type='BASE TABLE' ORDER BY 1`);
  const map = new Map();
  for (const r of t.rows) {
    const [sch, tbl] = [r.tn.split('.')[0], r.tn.split('.')[1].replace(/"/g, '""')];
    const q = await c.query(`SELECT count(*) AS n FROM "${sch}"."${tbl}"`);
    map.set(r.tn, Number(q.rows[0].n));
  }
  await c.end();
  return { label, map };
}

const live = await counts(process.env.DATABASE_URL, 'live', true);
const rest = await counts(process.env.DRILL_LOCAL_URL, 'restored', false);

if (rest.map.size === 0) {
  console.log(JSON.stringify({ ok: false, raison: 'restauration vide (0 table)' }));
  process.exit(1);
}

const failures = [];
const volatileDiffs = [];
let compared = 0;

for (const [t, n] of rest.map) {
  if (!live.map.has(t)) {
    failures.push(`${t}: presente dans le restaure, ABSENTE du live (n=${n})`);
    continue;
  }
  compared++;
  const lv = live.map.get(t);
  if (lv === n) continue;
  if (VOLATILE.test(t)) volatileDiffs.push(`${t}: live=${lv} restored=${n}`);
  else failures.push(`${t}: ECARTE MÉTIER live=${lv} restored=${n}`);
}

for (const [t, n] of live.map) {
  if (rest.map.has(t)) continue;
  if (ALLOW_MISSING_IN_RESTORED.has(t) && n === 0) {
    volatileDiffs.push(`${t}: absente du restaure (live=0, table plateforme interne)`);
    continue;
  }
  failures.push(`${t}: absente du restaure (live=${n})`);
}

console.log(JSON.stringify({
  ok: failures.length === 0,
  tables_live: live.map.size,
  tables_restored: rest.map.size,
  comparees: compared,
  ecarts_volatils: volatileDiffs,
  ecarts_metier: failures,
}));

process.exit(failures.length === 0 ? 0 : 1);
