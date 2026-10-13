-- ============================================================
-- 20261010120000_purchase_receptions_number_unique.sql
-- Meme classe de defaut que sales.client_sale_id : les numeros de
-- reception (purchase_receptions.number, NOT NULL) n'ont AUCUNE
-- contrainte d'unicite. La numerotation atomique fn_next_number les
-- rend uniques en pratique, mais rien ne l'impose a la base — toute
-- derive (repli, rejeu manuel, edit SQL) produirait des doublons
-- silencieux sur le registre fournisseurs.
--
-- Correctif : unique (pharmacy_id, number).
--
-- GARANTIES : aucune suppression/fusion/modification de reception ;
-- echec EXPLICITE si doublons preexistants (transaction annulee sans
-- effet) ; idempotent ; retour arriere = DROP INDEX (non destructif).
--
-- NON APPLIQUEE en production (application subordonnee a autorisation).
-- Preflight (lecture seule, 2026-10-10) : 0 reception, 0 doublon.
-- ============================================================

do $$
declare
  v_dups integer := 0;
begin
  if to_regclass('public.purchase_receptions') is null then
    raise exception 'PRECONDITION ECHOUEE: table public.purchase_receptions absente';
  end if;
  if not exists (
    select 1 from information_schema.columns
     where table_schema = 'public' and table_name = 'purchase_receptions'
       and column_name = 'number' and is_nullable = 'NO'
  ) then
    raise exception 'PRECONDITION ECHOUEE: purchase_receptions.number absente ou nullable';
  end if;
  select count(*) into v_dups
    from (
      select 1 from public.purchase_receptions
       group by pharmacy_id, number
      having count(*) > 1
    ) d;
  if v_dups > 0 then
    raise exception
      'PRECONDITION ECHOUEE: % groupe(s) de numeros de reception dupliques — nettoyage manuel requis',
      v_dups;
  end if;
end $$;

create unique index if not exists uq_purchase_receptions_pharmacy_number
  on public.purchase_receptions (pharmacy_id, number);

comment on index public.uq_purchase_receptions_pharmacy_number is
  'Numerotation des receptions : un numero par pharmacie (compteur
   atomique fn_next_number, garanti aussi par la base).';

-- Retour arriere (non destructif) :
--   drop index if exists public.uq_purchase_receptions_pharmacy_number;
