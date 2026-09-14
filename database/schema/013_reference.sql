-- ============================================================
-- PHARMA MAROC GOLD ENTERPRISE V2.0
-- 013_reference.sql — Base de référence Médicaments Maroc
-- (données GLOBALES, non liées à une pharmacie : partagées par toutes)
-- ============================================================

-- ------------------------------------------------------------
-- Catégories thérapeutiques de référence (nomenclature standard)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS reference_categories (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code         text NOT NULL UNIQUE,
  name_fr      text NOT NULL,
  name_ar      text,
  name_en      text,
  icon         text,
  color        text,
  sort_order   int NOT NULL DEFAULT 0
);

-- ------------------------------------------------------------
-- Produits de référence (médicaments commercialisés au Maroc)
-- Toutes les fiches proviennent d'une source officielle ou d'un
-- fichier de synchronisation validé. JAMAIS de données inventées.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS reference_products (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category_code      text REFERENCES reference_categories(code) ON DELETE SET NULL,
  name               text NOT NULL,
  dci                text,                -- Dénomination Commune Internationale
  substance_active   text,                -- substance active
  dosage             text,
  form               text,
  presentation       text,
  laboratory         text,
  therapeutic_class  text,
  commercial_status  text NOT NULL DEFAULT 'commercialise'
                     CHECK (commercial_status IN
                       ('commercialise','non_commercialise','retire','en_retrait')),
  amm_number         text,                -- numéro d'AMM
  code_produit       text,
  barcode_ean13      text,
  qr_code            text,
  ppv                numeric(14,2),       -- Prix Public de Vente (MAD)
  ph                 numeric(14,2),       -- Prix Hospitalier (MAD)
  pfht               numeric(14,2),       -- Prix Fabricant Hors Taxes (MAD)
  tva_rate           numeric(5,2) NOT NULL DEFAULT 20.00,
  rcp_url            text,                -- Résumé des Caractéristiques du Produit
  notice_url         text,                -- notice patient (leaflet)
  source             text NOT NULL DEFAULT 'officiel',
  source_updated_at  timestamptz,
  updated_at         timestamptz NOT NULL DEFAULT now(),
  UNIQUE (barcode_ean13)
);
CREATE INDEX IF NOT EXISTS idx_reference_products_category ON reference_products(category_code);
CREATE INDEX IF NOT EXISTS idx_reference_products_name ON reference_products USING gin (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_reference_products_dci ON reference_products(dci);
CREATE INDEX IF NOT EXISTS idx_reference_products_status ON reference_products(commercial_status);

-- ------------------------------------------------------------
-- Historique des synchronisations de la base de référence
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS reference_sync_runs (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source              text NOT NULL,
  started_at          timestamptz NOT NULL DEFAULT now(),
  finished_at         timestamptz,
  status              text NOT NULL DEFAULT 'running'
                      CHECK (status IN ('running','completed','failed')),
  new_count           int NOT NULL DEFAULT 0,
  modified_count      int NOT NULL DEFAULT 0,
  price_changed_count int NOT NULL DEFAULT 0,
  status_changed_count int NOT NULL DEFAULT 0,
  removed_count       int NOT NULL DEFAULT 0,
  notes               text
);
CREATE INDEX IF NOT EXISTS idx_reference_sync_runs_started ON reference_sync_runs(started_at DESC);

-- ------------------------------------------------------------
-- Journal des changements de la base de référence (append-only)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS reference_product_updates (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sync_run_id  uuid REFERENCES reference_sync_runs(id) ON DELETE CASCADE,
  product_id   uuid REFERENCES reference_products(id) ON DELETE CASCADE,
  barcode      text,
  name         text,
  change_type  text NOT NULL
               CHECK (change_type IN
                 ('new','modified','price_changed','status_changed','removed')),
  fields       jsonb DEFAULT '{}',   -- {"ppv": {"old": 9.5, "new": 10.0}}
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_reference_updates_run ON reference_product_updates(sync_run_id);
CREATE INDEX IF NOT EXISTS idx_reference_updates_created ON reference_product_updates(created_at DESC);
