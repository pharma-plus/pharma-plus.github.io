-- ============================================================
-- 20261009120000_security_definer_hardening.sql
-- Durcissement des 7 fonctions SECURITY DEFINER du catalogue POS.
--
-- Constat (audit _validation_backup/RAPPORT_LEVEE_BLOQUANTS.md) :
--   * les 7 fonctions ont SECURITY DEFINER + EXECUTE pour `anon` :
--     un appelant non authentifie passe p_pharmacy = uuid d'une autre
--     pharmacie et recoit agregats / ids / quantites (fuite) ;
--   * aucun SET search_path n'est epingle ;
--   * 4 des 7 n'existent dans aucun DDL du depot (divergence Phase 6).
--
-- Correctif (additif + idempotent) :
--   1. helper public.fn_tenant_scope(p_requested uuid) qui n'autorise
--      que le service_role/postgres (chemin Edge, pilote serveur) ou
--      l'appartenance prouvee via le JWT (auth.uid) ;
--   2. re-creation des 7 fonctions : filtre par le helper, references
--      qualifiees public.*, search_path epingle ;
--   3. EXECUTE retire de PUBLIC et de `anon`, conserve pour
--      authenticated/service_role/postgres.
--
-- Aucune table, colonne, donnee ni policy n'est modifiee.
-- Application sur la base de production : voir RAPPORT_CORRECTIONS_FINALES.md
--   (supabase db push --project-ref lwepnnecnrqdzadesyqo
--    ou SQL Editor de la console Supabase).
-- ============================================================

-- ------------------------------------------------------------
-- 1. Helper : verrou de perimetre pharmacie (SECURITY DEFINER)
-- ------------------------------------------------------------
create or replace function public.fn_tenant_scope(p_requested uuid)
returns uuid
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $fn$
declare
  v_role name := current_user;
  v_self uuid;
begin
  -- Pilote de confiance : le backend Edge utilise le service role et
  -- verifie deja le JWT + la pharmacie avant d'appeller.
  if v_role in ('postgres', 'supabase_admin', 'service_role') then
    return p_requested;
  end if;

  -- Appelant JWT : pharmacie du profil depuis le jeton verifie.
  begin
    select u.pharmacy_id into v_self
      from public.users u
     where u.id = auth.uid()
        or (u.email is not null
            and u.email = lower(coalesce(auth.jwt() ->> 'email', chr(0))));
  exception when undefined_function then
    v_self := null;
  end;

  if p_requested is null then
    return v_self;
  end if;
  if v_self is not distinct from p_requested then
    return p_requested;
  end if;

  raise exception 'pharmacy scope violation: caller may not read requested pharmacy'
    using errcode = '42501';
end;
$fn$;

-- ------------------------------------------------------------
-- 2. Les 7 fonctions, filtrees par le helper + search_path epingle
-- ------------------------------------------------------------
create or replace function public.catalog_pos_facets(p_pharmacy uuid)
returns table(kind text, label text, value text, total bigint)
language sql
stable
security definer
set search_path = public, pg_temp
as $fn$
  SELECT 'form', form, form, count(*)
  FROM public.medications
  WHERE pharmacy_id = public.fn_tenant_scope(p_pharmacy)
    AND form IS NOT NULL AND form <> ''
  GROUP BY form
  ORDER BY count(*) DESC
  LIMIT 12;
$fn$;

create or replace function public.catalog_pos_facets_dosages(p_pharmacy uuid)
returns table(label text, total bigint)
language sql
stable
security definer
set search_path = public, pg_temp
as $fn$
  SELECT dosage, count(*)
  FROM public.medications
  WHERE pharmacy_id = public.fn_tenant_scope(p_pharmacy)
    AND dosage IS NOT NULL AND dosage <> ''
  GROUP BY dosage
  ORDER BY count(*) DESC, dosage
  LIMIT 40;
$fn$;

create or replace function public.catalog_pos_facets_labs(p_pharmacy uuid)
returns table(label text, value text, total bigint)
language sql
stable
security definer
set search_path = public, pg_temp
as $fn$
  SELECT laboratory_name, laboratory_name, count(*)
  FROM public.medications
  WHERE pharmacy_id = public.fn_tenant_scope(p_pharmacy)
    AND laboratory_name IS NOT NULL AND laboratory_name <> ''
  GROUP BY laboratory_name
  ORDER BY count(*) DESC
  LIMIT 12;
$fn$;

create or replace function public.catalog_pos_facets_statuses(p_pharmacy uuid)
returns table(label text, total bigint)
language sql
stable
security definer
set search_path = public, pg_temp
as $fn$
  SELECT status, count(*)
  FROM public.medications
  WHERE pharmacy_id = public.fn_tenant_scope(p_pharmacy)
    AND status IS NOT NULL
  GROUP BY status
  ORDER BY count(*) DESC;
$fn$;

create or replace function public.catalog_pos_indications_count(p_pharmacy uuid)
returns bigint
language sql
stable
security definer
set search_path = public, pg_temp
as $fn$
  SELECT count(*)
  FROM public.medicine_indications
  WHERE pharmacy_id = public.fn_tenant_scope(p_pharmacy);
$fn$;

create or replace function public.catalog_stock_ids(p_pharmacy uuid)
returns table(medication_id uuid)
language sql
stable
security definer
set search_path = public, pg_temp
as $fn$
  SELECT DISTINCT sb.medication_id
  FROM public.stock_balances sb
  WHERE sb.pharmacy_id = public.fn_tenant_scope(p_pharmacy)
    AND sb.quantity > 0;
$fn$;

create or replace function public.medication_stock_map(p_pharmacy uuid, p_ids uuid[])
returns table(medication_id uuid, quantity numeric)
language sql
stable
security definer
set search_path = public, pg_temp
as $fn$
  SELECT sb.medication_id, sum(sb.quantity)::numeric
  FROM public.stock_balances sb
  WHERE sb.pharmacy_id = public.fn_tenant_scope(p_pharmacy)
    AND sb.medication_id = ANY(p_ids)
  GROUP BY sb.medication_id;
$fn$;

-- ------------------------------------------------------------
-- 3. Privileges : PUBLIC et `anon` perdent EXECUTE.
--    Seuls les roles presents en base recoivent un GRANT explicite.
-- ------------------------------------------------------------
do $$
declare
  f text;
  r record;
  fns constant text[] := array[
    'fn_tenant_scope(uuid)',
    'catalog_pos_facets(uuid)',
    'catalog_pos_facets_dosages(uuid)',
    'catalog_pos_facets_labs(uuid)',
    'catalog_pos_facets_statuses(uuid)',
    'catalog_pos_indications_count(uuid)',
    'catalog_stock_ids(uuid)',
    'medication_stock_map(uuid,uuid[])'
  ];
  grant_roles constant text[] := array['authenticated', 'service_role', 'postgres', 'supabase_admin'];
begin
  foreach f in array fns loop
    execute format('revoke execute on function public.%s from public', f);

    for r in
      select rolname from pg_roles where rolname = 'anon'
    loop
      execute format('revoke execute on function public.%s from %I', f, r.rolname);
    end loop;

    for r in
      select g.rolname
        from unnest(grant_roles) as g(rolname)
       where exists (select 1 from pg_roles p where p.rolname = g.rolname)
    loop
      execute format('grant execute on function public.%s to %I', f, r.rolname);
    end loop;
  end loop;
end $$;
