-- ============================================================
-- 20261010100000_stock_adjust_acl_hardening.sql
-- Durcissement ACL de public.fn_stock_adjust (meme regle que les
-- 8 fonctions durcies par 20261009120000).
--
-- Defaut constate en production apres 20261009130000 :
--   proacl = {=X/postgres, ..., anon=X/postgres, ...}
--   -> PUBLIC (donc anon) a EXECUTE sur la SECURITY DEFINER, alors
--      que les 8 autres fonctions ont ete REVOKEes de PUBLIC/anon.
--   La fonction reste securisee par son controle de perimetre
--   (anon -> 42501), mais l'execution anonyme d'une SECURITY
--   DEFINER est un surface d'attaque inutile et une incoherence
--   avec le durcissement apply.
--
-- Correctif : REVOKE PUBLIC/anon, GRANT aux roles applicatifs.
-- Idempotent. Aucune donnee, aucun corps de fonction modifie.
-- NON APPLIQUEE en production (application subordonnee a autorisation).
-- ============================================================

revoke execute on function public.fn_stock_adjust(uuid, jsonb, text, uuid, uuid)
  from public, anon;

grant execute on function public.fn_stock_adjust(uuid, jsonb, text, uuid, uuid)
  to postgres, supabase_admin, authenticated, service_role;
