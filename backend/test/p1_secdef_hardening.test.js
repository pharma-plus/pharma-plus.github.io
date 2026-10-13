import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

/**
 * PHASE 1 — garde-fou statique sur le durcissement des 7 fonctions
 * SECURITY DEFINER du catalogue POS.
 *
 * Postgres/Deno ne sont pas disponibles ici : on verifie donc (a) la
 * migration 20261009120000_security_definer_hardening.sql appliquee telle
 * quelle par `supabase db push`, et (b) que la seule voie d'appel
 * (Edge Function pharma-api) utilise bien le client service_role avec la
 * pharmacie issue du JWT verifie.
 */

const sqlPath = fileURLToPath(
  new URL(
    '../../supabase/migrations/20261009120000_security_definer_hardening.sql',
    import.meta.url,
  ),
);
const sql = readFileSync(sqlPath, 'utf8');

const edge = readFileSync(
  fileURLToPath(
    new URL('../../supabase/functions/pharma-api/index.ts', import.meta.url),
  ),
  'utf8',
);

/* Signatures exactes deployees a distance (lecture pg_proc du
   2026-10-09) : CREATE OR REPLACE exige identiques sinon erreur. */
const CATALOG_FNS = {
  catalog_pos_facets: {
    args: 'p_pharmacy uuid',
    ret: 'table(kind text, label text, value text, total bigint)',
    table: 'public.medications',
  },
  catalog_pos_facets_dosages: {
    args: 'p_pharmacy uuid',
    ret: 'table(label text, total bigint)',
    table: 'public.medications',
  },
  catalog_pos_facets_labs: {
    args: 'p_pharmacy uuid',
    ret: 'table(label text, value text, total bigint)',
    table: 'public.medications',
  },
  catalog_pos_facets_statuses: {
    args: 'p_pharmacy uuid',
    ret: 'table(label text, total bigint)',
    table: 'public.medications',
  },
  catalog_pos_indications_count: {
    args: 'p_pharmacy uuid',
    ret: 'bigint',
    table: 'public.medicine_indications',
  },
  catalog_stock_ids: {
    args: 'p_pharmacy uuid',
    ret: 'table(medication_id uuid)',
    table: 'public.stock_balances',
  },
  medication_stock_map: {
    args: 'p_pharmacy uuid, p_ids uuid[]',
    ret: 'table(medication_id uuid, quantity numeric)',
    table: 'public.stock_balances',
  },
};

const HELPER_SIG = 'p_requested uuid';

function fnBlock(name, args) {
  const start = sql.indexOf(`create or replace function public.${name}(${args})`);
  assert.ok(start > 0, `signature absente de la migration : ${name}(${args})`);
  const end = sql.indexOf('$fn$;', start);
  assert.ok(end > start, `bloc $fn$ non ferme pour ${name}`);
  return sql.slice(start, end);
}

test('phase 1 : migration additive — aucun DROP/UPDATE/DELETE/TRUNCATE', () => {
  assert.ok(
    !/\b(DROP|DELETE|TRUNCATE)\b/i.test(sql),
    'la migration de durcissement ne doit rien supprimer',
  );
  assert.ok(
    !/\bUPDATE\s+[a-z_]+\s+SET\b/i.test(sql),
    'la migration ne doit modifier aucune donnee',
  );
  assert.ok(!/ALTER\s+TABLE/i.test(sql), 'la migration ne doit pas alterer de table');
});

test('phase 1 : helper fn_tenant_scope est SECURITY DEFINER + search_path epingle', () => {
  const h = fnBlock('fn_tenant_scope', HELPER_SIG);
  assert.match(h, /language plpgsql/i);
  assert.match(h, /security definer/i);
  assert.match(h, /set search_path = public, pg_temp/i);
  assert.match(h, /current_user/i, 'le helper doit inspecter le role appelant');
  assert.match(h, /postgres.*supabase_admin.*service_role|service_role.*postgres/s,
    'le pilote service doit rester autorise');
  assert.match(h, /errcode = '42501'/, 'denier doit etre un refus SQL explicite');
  assert.match(h, /auth\.uid\(\)/, 'l appartenance se prouve via le JWT');
});

test('phase 1 : les 7 fonctions passent par fn_tenant_scope', () => {
  for (const [name, spec] of Object.entries(CATALOG_FNS)) {
    const b = fnBlock(name, spec.args);
    assert.match(b, /security definer/i, `${name} doit rester SECURITY DEFINER`);
    assert.match(b, /set search_path = public, pg_temp/i, `${name} : search_path epingle`);
    assert.ok(
      b.includes('public.fn_tenant_scope(p_pharmacy)'),
      `${name} doit filtrer via public.fn_tenant_scope`,
    );
    assert.ok(b.includes(spec.table), `${name} doit lire ${spec.table}`);
    assert.ok(
      !new RegExp(`(?:from|join)\\s+${spec.table.replace('public.', '')}\\b`, 'i').test(b),
      `${name} : reference non qualifiee a ${spec.table}`,
    );
  }
});

test('phase 1 : signatures conservees (CREATE OR REPLACE sans derive)', () => {
  for (const [name, spec] of Object.entries(CATALOG_FNS)) {
    const start = sql.indexOf(`create or replace function public.${name}(${spec.args})`);
    assert.ok(start > 0, `${name} : signature d arguments modifiee`);
    const end = sql.indexOf('$fn$', start);
    const head = sql.slice(start, end);
    assert.match(
      head,
      new RegExp(`returns\\s+${spec.ret.replace(/[()]/g, '\\$&')}`, 'i'),
      `${name} : type de retour modifie`,
    );
  }
});

test('phase 1 : PUBLIC et anon perdent EXECUTE, grants limites', () => {
  assert.match(sql, /revoke execute on function public\.%s from public/);
  assert.match(sql, /rolname = 'anon'/, 'anon doit etre explicitement retire');
  assert.match(sql, /'authenticated', 'service_role', 'postgres', 'supabase_admin'/);
  assert.ok(!/grant execute on function public\.%s to public/i.test(sql));
  assert.ok(!/grant execute on function public\.%s to anon/i.test(sql));

  const expected = [
    'fn_tenant_scope(uuid)',
    'catalog_pos_facets(uuid)',
    'catalog_pos_facets_dosages(uuid)',
    'catalog_pos_facets_labs(uuid)',
    'catalog_pos_facets_statuses(uuid)',
    'catalog_pos_indications_count(uuid)',
    'catalog_stock_ids(uuid)',
    'medication_stock_map(uuid,uuid[])',
  ];
  for (const sig of expected) {
    assert.ok(sql.includes(`'${sig}'`), `liste de privileges incomplete : ${sig}`);
  }
});

test('phase 1 : Edge — appel des 7 RPC via le client service_role uniquement', () => {
  assert.match(edge, /const sb = createClient\(supabaseUrl, serviceKey/,
    'le client data doit etre service_role');
  assert.ok(!/sbAuth\.rpc\(/.test(edge), 'aucun RPC via le client anon (sbAuth)');

  const rpcCalls = [...edge.matchAll(/\b(\w+)\.rpc\("([a-z_0-9]+)"/g)]
    .map((m) => ({ client: m[1], fn: m[2] }));
  const catalogFns = new Set(Object.keys(CATALOG_FNS));
  const catalogCalls = rpcCalls.filter((c) => catalogFns.has(c.fn));
  assert.equal(catalogCalls.length, catalogFns.size,
    `appels RPC catalogue attendus : ${catalogFns.size}, trouves ${catalogCalls.length}`);
  for (const c of catalogCalls) {
    assert.equal(c.client, 'sb', `RPC ${c.fn} doit passer par le client service_role`);
  }
});

test('phase 1 : Edge — p_pharmacy vient du JWT verifie, jamais du client', () => {
  for (const name of Object.keys(CATALOG_FNS)) {
    const at = edge.indexOf(`.rpc("${name}"`);
    assert.ok(at > 0, `appel RPC manquant dans la Edge : ${name}`);
    const site = edge.slice(at, at + 220);
    assert.match(site, /p_pharmacy:\s*pid\b/,
      `${name} : p_pharmacy doit provenir du JWT verifie (pid)`);
  }
  assert.ok(!/p_pharmacy:\s*(?:url|searchParams|body|xPharmacy)/i.test(edge),
    'aucun p_pharmacy lu dans la requete');

  const pub = edge.indexOf('if (PUBLIC_PATHS.has(');
  assert.ok(pub > 0, 'bloc PUBLIC_PATHS manquant');
  const window = edge.slice(pub, pub + 400);
  assert.match(window, /publicPharmacyId\(req\)/);
  assert.ok(
    !edge.slice(pub, pub + 400).includes('catalog'),
    'aucune route catalogue ne doit etre publique',
  );
  assert.match(edge, /const PUBLIC_PATHS = new Set\(\[\s*"health",\s*"auth\/login",\s*"auth\/refresh",\s*"auth\/verify-2fa",\s*\]\)/s,
    'seules les routes auth/health sont publiques');
});
