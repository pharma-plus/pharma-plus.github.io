-- ============================================================
-- 20261009130000_stock_adjustments_rpc.sql
-- Contrat unique des ajustements de stock (frontend / Edge / SQL).
--
-- Constat (audit + tests) :
--   * le frontend envoie { branchId, items:[{medication_id,
--     new_quantity}] } vers /stock/adjustments et
--     { branchId, items:[{medication_id, quantity, reason,
--     expired}] } vers /stock/write-off ;
--   * la route Edge attend un objet unique (medication_id,
--     quantity, movement_type) et n'ecrit JAMAIS branch_id
--     (NOT NULL dans stock_movements) -> insert refuse ;
--   * elle accepte movement_type entry/exit/correction, refuses
--     par la CHECK de stock_movements (12 valeurs autorisees).
--
-- Correctif : une seule fonction atomique et idempotente,
--   * la pharmacie derive de la BRANCHE (jamais d'identifiant cru
--     du client) ;
--   * perimetre : service_role (Edge) ou appartenance prouvee
--     (meme logique que public.fn_tenant_scope) ;
--   * new_quantity => delta = cible - solde, type inventory_in /
--     inventory_out ; quantity (+expired) => write_off ou
--     expiry_loss ; deltas nuls ignores ;
--   * une ligne de stock_movements par article ; le trigger
--     trg_stock_movement_apply applique les soldes et refuse les
--     soldes negatifs (rollback de TOUTE la demande) ;
--   * p_idempotency_key : une meme cle ne produit qu'un seul
--     applique (rejeu sans double mouvement).
--
-- AUCUNE table, colonne, donnee ni policy n'est modifiee.
-- NON APPLIQUEE en production (application subordonnee a autorisation).
-- ============================================================

create or replace function public.fn_stock_adjust(
  p_branch_id uuid,
  p_items jsonb,
  p_reason text default null,
  p_idempotency_key uuid default null,
  p_user_id uuid default null
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public, pg_temp
as $fn$
declare
  uuid_re constant text := '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
  num_re  constant text := '^-?[0-9]+(\.[0-9]+)?$';
  v_claims   jsonb := null;
  v_role     text  := '';
  v_sub      uuid  := null;
  v_email    text  := '';
  v_self     uuid  := null;
  v_cnt      integer := 0;
  v_resolved boolean := false;
  v_pharmacy uuid  := null;
  v_item     jsonb;
  v_med      uuid;
  v_lot      uuid  := null;
  v_current  numeric := 0;
  v_target   numeric := 0;
  v_wipe     numeric := 0;
  v_delta    numeric := 0;
  v_type     text;
  v_mov_id   uuid;
  v_applied  integer := 0;
  v_skipped  integer := 0;
  v_movements jsonb := '[]'::jsonb;
begin
  if p_branch_id is null or not (p_branch_id::text) ~ uuid_re then
    raise exception 'branch_id requis (uuid)' using errcode = '22023';
  end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array'
     or jsonb_array_length(p_items) = 0
     or jsonb_array_length(p_items) > 200 then
    raise exception 'items requis (tableau de 1 a 200 lignes)' using errcode = '22023';
  end if;

  /* La pharmacie est lue dans la branche, jamais dans la requete. */
  select b.pharmacy_id into v_pharmacy
    from public.branches b
   where b.id = p_branch_id;
  if not found then
    raise exception 'branche introuvable' using errcode = 'P0002';
  end if;

  /* Perimetre : identique a fn_tenant_scope. */
  begin
    v_claims := nullif(current_setting('request.jwt.claims', true), '')::jsonb;
  exception when others then
    v_claims := null;
  end;
  if v_claims is null or jsonb_typeof(v_claims) <> 'object' then
    v_claims := null;
  end if;
  if v_claims is not null then
    v_role := left(coalesce(v_claims ->> 'role', ''), 64);
    if v_role = '' then
      begin
        v_role := left(coalesce(auth.role(), ''), 64);
      exception when others then
        v_role := '';
      end;
    end if;
    if coalesce(v_claims ->> 'sub', '') ~ uuid_re then
      v_sub := (v_claims ->> 'sub')::uuid;
    end if;
    v_email := left(lower(coalesce(v_claims ->> 'email', '')), 320);
  end if;

  if v_role <> 'service_role' then
    begin
      if v_sub is not null then
        select u.pharmacy_id into v_self from public.users u where u.id = v_sub;
        v_resolved := found;
      end if;
      if not v_resolved and v_email <> '' then
        select count(*), (array_agg(u.pharmacy_id))[1] into v_cnt, v_self
          from public.users u
         where lower(u.email) = v_email;
        if v_cnt = 1 then
          v_resolved := true;
        else
          v_self := null;
          v_resolved := false;
        end if;
      end if;
    exception when others then
      v_self := null;
      v_resolved := false;
    end;
    if not v_resolved or v_self is null or v_self <> v_pharmacy then
      raise exception 'pharmacy scope violation: caller may not write this branch'
        using errcode = '42501';
    end if;
  end if;

  /* Idempotence : une meme cle ne s'applique qu'une fois. */
  if p_idempotency_key is not null then
    select coalesce(
             jsonb_agg(jsonb_build_object(
               'id', m.id,
               'medication_id', m.medication_id,
               'quantity', m.quantity,
               'movement_type', m.movement_type)),
             '[]'::jsonb)
      into v_movements
      from public.stock_movements m
     where m.reference_type = 'stock_adjust'
       and m.reference_id = p_idempotency_key;
    if jsonb_array_length(v_movements) > 0 then
      return jsonb_build_object(
        'applied', 0, 'skipped', 0, 'duplicate', true,
        'branch_id', p_branch_id, 'movements', v_movements);
    end if;
  end if;

  for v_item in select value from jsonb_array_elements(p_items) loop
    if not coalesce(v_item ->> 'medication_id', '') ~ uuid_re then
      raise exception 'medication_id invalide dans items' using errcode = '22023';
    end if;
    v_med := (v_item ->> 'medication_id')::uuid;
    if not exists (
      select 1 from public.medications m
       where m.id = v_med and m.pharmacy_id = v_pharmacy
    ) then
      raise exception 'medicament % introuvable dans cette pharmacie', v_med
        using errcode = 'P0002';
    end if;
    v_lot := null;
    if coalesce(v_item ->> 'lot_id', '') ~ uuid_re then
      v_lot := (v_item ->> 'lot_id')::uuid;
    end if;

    if coalesce(v_item ->> 'new_quantity', '') ~ num_re then
      /* Cible : delta = cible - solde actuel de la branche. */
      v_target := (v_item ->> 'new_quantity')::numeric;
      if v_target < 0 then
        raise exception 'new_quantity ne peut pas etre negatif' using errcode = '22023';
      end if;
      select coalesce(sum(b.quantity), 0) into v_current
        from public.stock_balances b
       where b.pharmacy_id = v_pharmacy
         and b.branch_id = p_branch_id
         and b.medication_id = v_med
         and b.lot_id is not distinct from v_lot;
      v_delta := v_target - v_current;
      if v_delta = 0 then
        v_skipped := v_skipped + 1;
        continue;
      end if;
      v_type := case when v_delta > 0 then 'inventory_in' else 'inventory_out' end;
    elsif coalesce(v_item ->> 'quantity', '') ~ num_re then
      /* Sortie simple : write-off, ou perte si expiré. */
      v_wipe := abs((v_item ->> 'quantity')::numeric);
      if v_wipe = 0 then
        v_skipped := v_skipped + 1;
        continue;
      end if;
      v_delta := -v_wipe;
      v_type := case
                  when coalesce(nullif(v_item ->> 'expired', '')::boolean, false)
                    then 'expiry_loss'
                  else 'write_off'
                end;
    else
      raise exception 'item: new_quantity ou quantity requis' using errcode = '22023';
    end if;

    insert into public.stock_movements (
      pharmacy_id, branch_id, medication_id, lot_id, movement_type,
      quantity, unit_cost, reference_type, reference_id, notes, user_id
    ) values (
      v_pharmacy, p_branch_id, v_med, v_lot, v_type,
      v_delta, 0, 'stock_adjust', p_idempotency_key,
      left(coalesce(p_reason, ''), 500), p_user_id
    )
    returning id into v_mov_id;

    v_applied := v_applied + 1;
    v_movements := v_movements || jsonb_build_array(jsonb_build_object(
      'id', v_mov_id,
      'medication_id', v_med,
      'quantity', v_delta,
      'movement_type', v_type));
  end loop;

  return jsonb_build_object(
    'applied', v_applied,
    'skipped', v_skipped,
    'duplicate', false,
    'branch_id', p_branch_id,
    'movements', v_movements);
end;
$fn$;
