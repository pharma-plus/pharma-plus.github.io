-- ============================================================
-- 20261010110000_sales_client_sale_id_unique.sql
-- Defaut recette (C3) : sales.client_sale_id n'a AUCUNE contrainte
-- unique. La route Edge POST /sales verifie l'existence avant insert
-- (pre-check) mais deux requetes concurrentes avec la meme cle de
-- rejeu hors-ligne passent toutes les deux le pre-check et creent
-- deux ventes — double debit possible malgre l'idempotence UI.
--
-- Correctif : index unique partiel par pharmacie. Toute tentative
-- concurrente de double insertion est refusee par la base.
--
-- GARANTIES :
--   * AUCUNE suppression, fusion ni modification de vente existante ;
--   * echec EXPLICITE et SUR (exception avant creation de l'index)
--     si des doublons preexistent — la transaction est annulee sans
--     effet, l'operateur doit trancher manuellement ;
--   * idempotent (IF NOT EXISTS) : reapplication sans effet ;
--   * retour arriere non destructif : DROP INDEX uniquement.
--
-- NON APPLIQUEE en production (application subordonnee a autorisation).
-- Preflight de donnees (lecture seule, execution manuelle avant apply) :
--   select pharmacy_id, client_sale_id, count(*)
--     from public.sales where client_sale_id is not null
--    group by 1,2 having count(*) > 1;
--   -- resultat attendu : 0 ligne (constate le 2026-10-10 : 0 doublon,
--   -- 6 ventes, toutes sans client_sale_id).
-- ============================================================

do $$
declare
  v_dups integer := 0;
begin
  if to_regclass('public.sales') is null then
    raise exception 'PRECONDITION ECHOUEE: table public.sales absente';
  end if;
  if not exists (
    select 1 from information_schema.columns
     where table_schema = 'public' and table_name = 'sales'
       and column_name = 'client_sale_id'
  ) then
    raise exception 'PRECONDITION ECHOUEE: colonne sales.client_sale_id absente';
  end if;
  select count(*) into v_dups
    from (
      select 1 from public.sales
       where client_sale_id is not null
       group by pharmacy_id, client_sale_id
      having count(*) > 1
    ) d;
  if v_dups > 0 then
    raise exception
      'PRECONDITION ECHOUEE: % groupe(s) de doublons (pharmacy_id, client_sale_id) existants — nettoyage manuel requis avant creation de l''index',
      v_dups;
  end if;
end $$;

create unique index if not exists uq_sales_pharmacy_client_sale_id
  on public.sales (pharmacy_id, client_sale_id)
  where client_sale_id is not null;

comment on index public.uq_sales_pharmacy_client_sale_id is
  'Idempotence rejeu hors-ligne : une meme cle client_sale_id ne peut
   produire qu''une vente par pharmacie (course concurrente).';

-- Retour arriere (non destructif, ne touche a aucune donnee) :
--   drop index if exists public.uq_sales_pharmacy_client_sale_id;
