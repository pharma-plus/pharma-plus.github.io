-- ============================================================
-- 931 — COLONNE PPC pour reference_products (import medicament.ma)
-- ============================================================
-- Migration ADDITIVE uniquement (règle §29 — non-négociable) :
--  · aucun tableau existant modifié/supprimé ;
--  · aucune donnée existante modifiée : ppc NULL pour les 45
--    références déjà présentes (pas de valeur par défaut) ;
--  · idempotente (IF NOT EXISTS) : migrate.js ré-exécutable ;
--  · pfht (prix factory HT) reste strictement indépendant —
--    PPC ne sera JAMAIS stocké dans pfht.
-- Compatibilité vérifiée en Phase 1 : PostgreSQL (ADD COLUMN
-- nullable sans réécriture), backend (colonnes explicites),
-- API Edge (select *), frontend (clés explicites), RLS (inchangée).
-- ============================================================

ALTER TABLE reference_products ADD COLUMN IF NOT EXISTS ppc numeric(12,2);

COMMENT ON COLUMN reference_products.ppc IS
  'Prix Public Conseillé (MAD) issu de sources externes (ex: medicament.ma). NULL = absent de la source. pfht reste indépendant.';
