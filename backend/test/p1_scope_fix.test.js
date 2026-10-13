import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

/**
 * CORRECTION ISOLATION MULTI-PHARMACIES — garde-fou statique sur la
 * migration 20261009123000_security_definer_scope_fix.sql.
 *
 * Le comportement est valide sur un Postgres reel en local (harnais
 * PGlite, 21/21) : ici on verifie que le fichier de migration ne
 * contient que l'objet necessaire, reste idempotent, conserve les
 * privileges de 20261009120000, et n'utilise plus `current_user`
 * (defaut constate en production).
 */

const dir = fileURLToPath(new URL('../../supabase/migrations/', import.meta.url));
const fixPath = `${dir}20261009123000_security_definer_scope_fix.sql`;
const sql = readFileSync(fixPath, 'utf8');
/* code SQL seul, commentaires retires (les commentaires deplorent le defaut) */
const code = sql.replace(/\/\*[\s\S]*?\*\//g, '').replace(/--.*$/gm, '');

test('isolation : la migration corrective existe et suit la precedente', () => {
  const files = readdirSync(dir).filter((f) => f.endsWith('.sql')).sort();
  assert.ok(files.includes('20261009123000_security_definer_scope_fix.sql'));
  assert.ok(files.indexOf('20261009123000_security_definer_scope_fix.sql') >
    files.indexOf('20261009120000_security_definer_hardening.sql'),
    'la correction doit etre appliquee apres le durcissement');
});

test('isolation : portee stricte — un seul objet, aucun DROP ni donnee', () => {
  const creates = [...code.matchAll(/create or replace function\s+public\.([a-z0-9_]+)/gi)]
    .map((m) => m[1]);
  assert.deepEqual(creates, ['fn_tenant_scope'], 'une seule fonction recreee');
  assert.ok(!/\b(DROP|ALTER|TRUNCATE|DELETE)\b/i.test(code), 'aucune destruction ni alteration');
  assert.ok(!/\bUPDATE\s+[a-z_]+\s+SET\b/i.test(code), 'aucune modification de donnee');
  assert.ok(!/grant\s|revoke\s/i.test(code),
    'aucun privilege touche : CREATE OR REPLACE conserve le proacl de 20261009120000');
});

test('isolation : signature identique a la fonction deployee', () => {
  assert.ok(sql.includes('create or replace function public.fn_tenant_scope(p_requested uuid)'));
  assert.match(sql, /returns uuid/i);
  assert.match(sql, /language plpgsql/i);
  assert.match(sql, /stable/i);
  assert.match(sql, /security definer/i);
  assert.match(sql, /set search_path = public, pg_temp/i);
});

test('isolation : plus aucun usage de current_user (le defaut)', () => {
  assert.ok(!/current_user/i.test(code),
    'current_user vaut le proprietaire dans un SECURITY DEFINER');
  assert.match(code, /current_setting\('request\.jwt\.claims'/,
    'le role d execution vient des claims JWT verifies');
});

test('isolation : seul service_role est un pilote de confiance', () => {
  assert.match(code, /v_role = 'service_role'/);
  assert.ok(!/'postgres'|'supabase_admin'/.test(code),
    'aucun autre role ouvert sans preuve d appartenance');
  assert.ok(!/in \('postgres'/.test(code), 'plus de liste de roles privilegies par current_user');
});

test('isolation : contexte JWT robuste (JSON absent, corrompu, non objet)', () => {
  assert.match(sql, /nullif\(current_setting\('request\.jwt\.claims', true\), ''\)::jsonb/);
  assert.match(sql, /jsonb_typeof\(v_claims\) <> 'object'/);
  assert.match(sql, /exception when others then\s*v_claims := null;/);
  assert.match(sql, /auth\.role\(\)/, 'repli sur l aide Supabase pour le role');
  assert.match(sql, /exception when others then\s*v_role := '';/);
});

test('isolation : appartenance recalculee cote serveur, echec ferme', () => {
  assert.ok(sql.includes("~* '^[0-9a-f]{8}-"), 'sub valide avant conversion uuid');
  assert.ok(!/min\(u\.pharmacy_id\)/.test(sql), 'min(uuid) n existe pas en Postgres');
  assert.match(sql, /\(array_agg\(u\.pharmacy_id\)\)\[1\]/, 'resolution email sans agregat interdit');
  assert.match(sql, /v_cnt = 1/, 'email doit designer exactement un compte (ambiguite refusee)');
  assert.match(sql, /u\.pharmacy_id/, 'pharmacie lue dans public.users, jamais dans la requete');
  const refus = [...sql.matchAll(/errcode = '42501'/g)].length;
  assert.ok(refus >= 3, `au moins 3 refus explicites 42501, trouves ${refus}`);
  assert.match(sql, /if p_requested is null then\s*return null;/,
    'pas de perimetre par defaut quand la pharmacie est absente');
  assert.match(sql, /not v_resolved or v_self is null/,
    'contexte absent/invalide/non prouve => refus');
});

test('isolation : la Edge conserve le client service_role pour le catalogue', () => {
  const edge = readFileSync(
    fileURLToPath(new URL('../../supabase/functions/pharma-api/index.ts', import.meta.url)),
    'utf8',
  );
  assert.match(edge, /const sb = createClient\(supabaseUrl, serviceKey/);
  assert.ok(!/sbAuth\.rpc\(/.test(edge));
});
