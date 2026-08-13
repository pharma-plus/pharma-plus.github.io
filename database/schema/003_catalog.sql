-- ============================================================
-- PHARMA MAROC GOLD ENTERPRISE V2.0
-- 003_catalog.sql — Médicaments, catégories, laboratoires
-- ============================================================

-- ------------------------------------------------------------
-- Catégories (hiérarchiques)
-- ------------------------------------------------------------
CREATE TABLE categories (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id  uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  parent_id    uuid REFERENCES categories(id) ON DELETE SET NULL,
  name         text NOT NULL,
  description  text,
  icon         text,
  color        text,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);

-- ------------------------------------------------------------
-- Familles thérapeutiques
-- ------------------------------------------------------------
CREATE TABLE therapeutic_families (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id  uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  code         text NOT NULL,
  name         text NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (pharmacy_id, code)
);

-- ------------------------------------------------------------
-- Laboratoires
-- ------------------------------------------------------------
CREATE TABLE laboratories (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id  uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  name         text NOT NULL,
  country      text,
  phone        text,
  email        text,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);

-- ------------------------------------------------------------
-- Médicaments (fiche complète)
-- ------------------------------------------------------------
CREATE TABLE medications (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id          uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  category_id          uuid REFERENCES categories(id) ON DELETE SET NULL,
  family_id            uuid REFERENCES therapeutic_families(id) ON DELETE SET NULL,
  laboratory_id        uuid REFERENCES laboratories(id) ON DELETE SET NULL,
  name                 text NOT NULL,
  dci                  text,
  generic_name         text,
  dosage               text,
  form                 text,
  presentation         text,
  photo_url            text,
  leaflet_url          text,               -- notice PDF
  barcode_ean13        text,
  qr_code              text,
  price_purchase       numeric(14,2) NOT NULL DEFAULT 0,
  price_sale           numeric(14,2) NOT NULL DEFAULT 0,
  tva_rate             numeric(5,2) NOT NULL DEFAULT 20.00,
  margin               numeric(5,2) NOT NULL DEFAULT 0,   -- marge %
  prescription_required boolean NOT NULL DEFAULT false,
  storage_conditions   text,
  storage_temp_min     numeric(5,2),
  storage_temp_max     numeric(5,2),
  reorder_level        numeric(12,3) NOT NULL DEFAULT 0,
  min_stock            numeric(12,3) NOT NULL DEFAULT 0,
  shelf_location       text,
  status               text NOT NULL DEFAULT 'available'
                       CHECK (status IN ('available','out_of_stock','retired')),
  is_public            boolean NOT NULL DEFAULT false,   -- affichable sur le site Web
  search               tsvector,
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now(),
  revision             bigint NOT NULL DEFAULT 1
);
CREATE INDEX idx_medications_pharmacy ON medications(pharmacy_id);
CREATE INDEX idx_medications_barcode ON medications(pharmacy_id, barcode_ean13);
CREATE INDEX idx_medications_name_trgm ON medications USING gin (name gin_trgm_ops);
CREATE INDEX idx_medications_dci ON medications(dci);
CREATE INDEX idx_medications_status ON medications(pharmacy_id, status);
CREATE INDEX idx_medications_search ON medications USING gin (search);

CREATE TRIGGER trg_medications_search
  BEFORE INSERT OR UPDATE OF name, dci, generic_name, dosage, presentation, barcode_ean13
  ON medications
  FOR EACH ROW EXECUTE FUNCTION fn_medication_search();

CREATE TRIGGER trg_medications_revision
  BEFORE UPDATE ON medications
  FOR EACH ROW EXECUTE FUNCTION fn_set_revision();

-- ------------------------------------------------------------
-- Équivalents génériques
-- ------------------------------------------------------------
CREATE TABLE medication_equivalents (
  medication_id    uuid NOT NULL REFERENCES medications(id) ON DELETE CASCADE,
  equivalent_id    uuid NOT NULL REFERENCES medications(id) ON DELETE CASCADE,
  PRIMARY KEY (medication_id, equivalent_id),
  CHECK (medication_id <> equivalent_id)
);

-- ------------------------------------------------------------
-- Fournisseurs par médicament (prix & référence)
-- ------------------------------------------------------------
CREATE TABLE medication_suppliers (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id   uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  medication_id uuid NOT NULL REFERENCES medications(id) ON DELETE CASCADE,
  supplier_id   uuid NOT NULL,      -- FK ajoutée en 005_partners.sql
  reference     text,
  price         numeric(14,2) NOT NULL DEFAULT 0,
  is_primary    boolean NOT NULL DEFAULT false,
  created_at    timestamptz NOT NULL DEFAULT now()
);

SELECT fn_apply_tenant_rls('categories');
SELECT fn_apply_tenant_rls('therapeutic_families');
SELECT fn_apply_tenant_rls('laboratories');
SELECT fn_apply_tenant_rls('medications');
SELECT fn_apply_tenant_rls('medication_suppliers');
