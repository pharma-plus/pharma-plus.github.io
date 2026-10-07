-- ============================================================
-- 932 — TABLE DE PROVENANCE DÉDIÉE (import medicament.ma)
-- ============================================================
-- Migration ADDITIVE uniquement (règle §29 — non-négociable) :
--  · nouveau tableau 1:1 avec reference_products (aucune table
--    existante modifiée ni supprimée) ;
--  · conserve les informations source qui ne tiennent pas dans
--    reference_products (règle §1.3 : ne rien perdre) ;
--  · idempotente (IF NOT EXISTS) : migrate.js ré-exécutable ;
--  · même modèle d'accès que reference_products : RLS activée
--    sans policy (accès service role / propriétaire seul).
-- Aucune suppression : ON DELETE CASCADE ne se déclenche jamais
-- dans le fonctionnement normal (aucun DELETE sur reference_products).
-- ============================================================

CREATE TABLE IF NOT EXISTS reference_product_provenance (
    reference_id         uuid PRIMARY KEY REFERENCES reference_products(id) ON DELETE CASCADE,
    source               text NOT NULL,
    medicament_id        text NOT NULL,
    source_id            text,
    source_url           text,
    source_file          text,
    hash_source          text,
    date_source          timestamptz,
    date_import          timestamptz,
    lettre_source        text,
    doublon_classe       text NOT NULL,
    source_occurrences   integer,
    nom_original         text,
    labo_source_original text,
    prix_original        text,
    secondary_original   text,
    statut_source        text,
    imported_at          timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_ref_provenance_medicament_id
    ON reference_product_provenance (medicament_id);
CREATE INDEX IF NOT EXISTS idx_ref_provenance_source
    ON reference_product_provenance (source);

ALTER TABLE reference_product_provenance ENABLE ROW LEVEL SECURITY;
