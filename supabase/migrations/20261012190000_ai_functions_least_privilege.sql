-- ============================================================
-- 20261012190000_ai_functions_least_privilege.sql
-- CORRECTION SÉCURITÉ (faille inter-tenant critique).
-- Les 3 fonctions SECURITY DEFINER (ai_insights, ai_reorder_plan,
-- ai_sales_analysis) héritaient de l'exécution PUBLIC (défaut),
-- donc aussi pour `anon` et `authenticated`. Comme SECURITY DEFINER
-- contourne la RLS, n'importe quel détenteur de la clé publique
-- pouvait appeler /rest/v1/rpc/ai_* avec un p_pharmacy ARBITRAIRE
-- et lire les données d'une AUTRE pharmacie (fuite inter-tenant).
-- Le frontend n'appelle ces fonctions QUE via l'Edge function
-- (pharma-api), qui utilise la clé service_role et injecte
-- p_pharmacy depuis le JWT (pharmacy_id de public.users), jamais
-- depuis une saisie utilisateur.
-- Correctif (principe du moindre privilège) : révoquer EXECUTE sur
-- PUBLIC, anon et authenticated ; conserver service_role (et le
-- propriétaire postgres). Aucune donnée, aucun schéma supprimé.
-- Requis pour s'assurer que seul l'Edge (service_role) peut lire.
-- ============================================================

-- 1. Révocation de l'exécution publique / anon / authenticated.
REVOKE EXECUTE ON FUNCTION public.ai_insights(uuid)                FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.ai_reorder_plan(uuid, uuid, int) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.ai_sales_analysis(uuid, uuid, int) FROM PUBLIC, anon, authenticated;

-- 2. service_role conserve l'exécution (appels Edge). postgres l'a déjà.
GRANT EXECUTE ON FUNCTION public.ai_insights(uuid)                TO service_role;
GRANT EXECUTE ON FUNCTION public.ai_reorder_plan(uuid, uuid, int) TO service_role;
GRANT EXECUTE ON FUNCTION public.ai_sales_analysis(uuid, uuid, int) TO service_role;
