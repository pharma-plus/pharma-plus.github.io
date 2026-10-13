-- ============================================================
-- 20261009140000_trigger_stock_direction_fix.sql
-- Correction de public.fn_apply_stock_movement (trigger
-- trg_stock_movement_apply).
--
-- Defauts constates (DDL local 012_triggers_views.sql ET corps
-- deploye en production, relu via l'API Supabase) :
--   1. 'release' figure dans la liste des types ENTRANTS, donc la
--      branche ELSIF qui libere les reservations est morte : un
--      release AJOUTE la quantite au stock au lieu de liberer la
--      reservation (vol de stock + reservation jamais liberee) ;
--   2. la direction dependait du SIGNE pour l'entree
--      (+ NEW.quantity) mais de abs() pour la sortie : un entrant
--      avec quantite negative decrementait le stock ;
--   3. le type 'adjustment' n'avait pas de branche dediee et
--      passait en sortie pure quel que soit le signe ;
--   4. un movement_type inconnu decrementait silencieusement le
--      stock (ELSE fourre-tout) ;
--   5. avec lot_id NULL, ON CONFLICT ne se declenche jamais :
--      chaque entree creait une NOUVELLE ligne de balance, et une
--      sortie soustrayait abs() de CHAQUE ligne (solde fausse) ;
--   6. le controle anti-negatif se faisait APRÈS l'ecriture
--      (RETURNING d'une seule ligne) : messages opaques et solde
--      total non verifie.
--
-- Correctif : direction par le TYPE (signe seulement pour
-- 'adjustment'), abs() partout, NULL-lot agrege sur une seule
-- ligne, sorties reparties ligne a ligne avec solde exact,
-- reservation/liberation separees, type inconnu REFUSE (rollback).
-- Aucune table, colonne, donnee ni policy n'est modifiee.
-- NON APPLIQUEE en production (application subordonnee a autorisation).
-- ============================================================

create or replace function public.fn_apply_stock_movement()
returns trigger
language plpgsql
as $fn$
declare
  v_remain numeric;
  r record;
begin
  /* --- Reservations : seule la quantite RESERVEE bouge --- */
  if NEW.movement_type = 'reservation' then
    update public.stock_balances
       set reserved_quantity = reserved_quantity + abs(NEW.quantity),
           updated_at = now()
     where branch_id = NEW.branch_id
       and medication_id = NEW.medication_id
       and lot_id is not distinct from NEW.lot_id;
    if not found then
      raise exception 'Stock introuvable pour la reservation';
    end if;

  /* --- Liberation de reservation (CORRIGE : 'release' n'est plus
         dans la branche entrante, qui ajoutait le stock) --- */
  elsif NEW.movement_type = 'release' then
    update public.stock_balances
       set reserved_quantity = greatest(0, reserved_quantity - abs(NEW.quantity)),
           updated_at = now()
     where branch_id = NEW.branch_id
       and medication_id = NEW.medication_id
       and lot_id is not distinct from NEW.lot_id;
    if not found then
      raise exception 'Stock introuvable pour la liberation de reservation';
    end if;

  /* --- Mouvements entrants : direction par le TYPE ; le lot NULL
         est agrege sur UNE ligne (ON CONFLICT ne couvre pas NULL) --- */
  elsif NEW.movement_type in
        ('purchase_receipt', 'sale_return', 'inventory_in', 'transfer_in') then
    if NEW.lot_id is null then
      update public.stock_balances
         set quantity = quantity + abs(NEW.quantity),
             updated_at = now()
       where branch_id = NEW.branch_id
         and medication_id = NEW.medication_id
         and lot_id is null;
      if not found then
        insert into public.stock_balances
               (pharmacy_id, branch_id, medication_id, lot_id,
                quantity, reserved_quantity, updated_at)
        values (NEW.pharmacy_id, NEW.branch_id, NEW.medication_id, null,
                abs(NEW.quantity), 0, now());
      end if;
    else
      insert into public.stock_balances
             (pharmacy_id, branch_id, medication_id, lot_id,
              quantity, reserved_quantity, updated_at)
      values (NEW.pharmacy_id, NEW.branch_id, NEW.medication_id, NEW.lot_id,
              abs(NEW.quantity), 0, now())
      on conflict (branch_id, medication_id, lot_id) do update
        set quantity = public.stock_balances.quantity + abs(NEW.quantity),
            updated_at = now();
    end if;

  /* --- Mouvements sortants : direction par le TYPE ; solde controle
         AVANT ecriture, sortie repartie sur les lignes existantes --- */
  elsif NEW.movement_type in
        ('sale', 'inventory_out', 'transfer_out', 'write_off', 'expiry_loss') then
    if not exists (
      select 1 from public.stock_balances b
       where b.branch_id = NEW.branch_id
         and b.medication_id = NEW.medication_id
         and b.lot_id is not distinct from NEW.lot_id
    ) then
      raise exception 'Stock insuffisant (aucune balance trouvee)';
    end if;
    v_remain := abs(NEW.quantity);
    for r in
      select b.id, b.quantity
        from public.stock_balances b
       where b.branch_id = NEW.branch_id
         and b.medication_id = NEW.medication_id
         and b.lot_id is not distinct from NEW.lot_id
       order by b.id
         for update
    loop
      exit when v_remain <= 0;
      if r.quantity >= v_remain then
        update public.stock_balances
           set quantity = quantity - v_remain, updated_at = now()
         where id = r.id;
        v_remain := 0;
      else
        update public.stock_balances
           set quantity = 0, updated_at = now()
         where id = r.id;
        v_remain := v_remain - r.quantity;
      end if;
    end loop;
    if v_remain > 0 then
      raise exception 'Stock insuffisant pour % (manque %)',
        NEW.medication_id, v_remain;
    end if;

  /* --- Ajustement d'inventaire : direction par le SIGNE --- */
  elsif NEW.movement_type = 'adjustment' then
    if NEW.quantity > 0 then
      if NEW.lot_id is null then
        update public.stock_balances
           set quantity = quantity + abs(NEW.quantity),
               updated_at = now()
         where branch_id = NEW.branch_id
           and medication_id = NEW.medication_id
           and lot_id is null;
        if not found then
          insert into public.stock_balances
                 (pharmacy_id, branch_id, medication_id, lot_id,
                  quantity, reserved_quantity, updated_at)
          values (NEW.pharmacy_id, NEW.branch_id, NEW.medICATION_id, null,
                  abs(NEW.quantity), 0, now());
        end if;
      else
        insert into public.stock_balances
               (pharmacy_id, branch_id, medication_id, lot_id,
                quantity, reserved_quantity, updated_at)
        values (NEW.pharmacy_id, NEW.branch_id, NEW.medication_id, NEW.lot_id,
                abs(NEW.quantity), 0, now())
        on conflict (branch_id, medication_id, lot_id) do update
          set quantity = public.stock_balances.quantity + abs(NEW.quantity),
              updated_at = now();
      end if;
    else
      if not exists (
        select 1 from public.stock_balances b
         where b.branch_id = NEW.branch_id
           and b.medication_id = NEW.medication_id
           and b.lot_id is not distinct from NEW.lot_id
      ) then
        raise exception 'Stock insuffisant (aucune balance trouvee)';
      end if;
      v_remain := abs(NEW.quantity);
      for r in
        select b.id, b.quantity
          from public.stock_balances b
         where b.branch_id = NEW.branch_id
           and b.medication_id = NEW.medication_id
           and b.lot_id is not distinct from NEW.lot_id
         order by b.id
           for update
      loop
        exit when v_remain <= 0;
        if r.quantity >= v_remain then
          update public.stock_balances
             set quantity = quantity - v_remain, updated_at = now()
           where id = r.id;
          v_remain := 0;
        else
          update public.stock_balances
             set quantity = 0, updated_at = now()
           where id = r.id;
          v_remain := v_remain - r.quantity;
        end if;
      end loop;
      if v_remain > 0 then
        raise exception 'Stock insuffisant pour % (manque %)',
          NEW.medication_id, v_remain;
      end if;
    end if;

  else
    /* Type non gere : le mouvement est REFUSE (rollback), jamais un
       mouvement silencieux de stock. */
    raise exception 'movement_type % non gere par fn_apply_stock_movement',
      NEW.movement_type;
  end if;

  return new;
end;
$fn$;
