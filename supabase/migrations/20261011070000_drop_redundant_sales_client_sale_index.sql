-- ============================================================
-- 20261011070000_drop_redundant_sales_client_sale_index.sql
-- Correction post-deploiement (2026-10-11) : la migration
-- 20261010110000 a cree uq_sales_pharmacy_client_sale_id alors que
-- l'index identique uq_sales_client_sale existait deja depuis
-- 20260921190000_cash_sessions_phase1.sql (defaut de l'audit D-2 :
-- les donnees avaient ete controlees, pas les index de la colonne).
--
-- On supprime l'index redondant AJOUTE, on conserve l'index
-- d'origine uq_sales_client_sale : la contrainte d'unicite
-- (pharmacy_id, client_sale_id) WHERE client_sale_id IS NOT NULL
-- reste garantie en permanence (aucun instant sans protection).
--
-- GARANTIES :
--   * drop index n'affecte AUCUNE donnee (seule la structure) ;
--   * idempotent (IF EXISTS) ;
--   * necessaire aussi pour les environnements neufs, qui
--     recreeraient sinon la paire redondante.
--
-- Retour arriere (recreation identique, non destructif) :
--   create unique index if not exists uq_sales_pharmacy_client_sale_id
--     on public.sales (pharmacy_id, client_sale_id)
--     where client_sale_id is not null;
-- ============================================================

drop index if exists public.uq_sales_pharmacy_client_sale_id;

comment on index public.uq_sales_client_sale is
 'Idempotence rejeu hors-ligne : une meme cle client_sale_id ne peut
  produire qu''une vente par pharmacie. Index d''origine (20260921190000),
  conserve apres retrait de l''index redondant de 20261010110000.';
