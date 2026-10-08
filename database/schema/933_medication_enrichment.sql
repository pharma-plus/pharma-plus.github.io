-- ============================================================
-- 933_medication_enrichment.sql — Enrichissement additif
-- Catalogue médicaments : substance active, composition,
-- architecture des indications (table VIDE, aucune donnée
-- inventée), laboratoire denormalise, recherche elargie.
-- Migration 100% ADDITIVE et idempotente. Aucune suppression.
-- ============================================================

-- 1) Colonnes additives sur medications -----------------------
ALTER TABLE medications ADD COLUMN IF NOT EXISTS substance_active text;
ALTER TABLE medications ADD COLUMN IF NOT EXISTS composition     text;

-- 2) Architecture des indications (reste VIDE tant que la
--    source ne fournit pas de données vérifiables) ------------
CREATE TABLE IF NOT EXISTS medicine_indications (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id       uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  medication_id     uuid REFERENCES medications(id) ON DELETE CASCADE,
  reference_id      uuid REFERENCES reference_products(id) ON DELETE SET NULL,
  indication        text,
  pathologie        text,
  source            text,
  source_url        text,
  date_source       date,
  validation_status text NOT NULL DEFAULT 'pending'
                    CHECK (validation_status IN ('pending','validated','rejected')),
  created_by        uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_medicine_indications_med
  ON medicine_indications(medication_id);
CREATE INDEX IF NOT EXISTS idx_medicine_indications_pharmacy
  ON medicine_indications(pharmacy_id);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'medicine_indications' AND policyname = 'tenant_isolation'
  ) THEN
    PERFORM fn_apply_tenant_rls('medicine_indications');
  END IF;
END $$;

-- Trigger updated_at (idempotent)
DROP TRIGGER IF EXISTS trg_medicine_indications_updated_at ON medicine_indications;
CREATE TRIGGER trg_medicine_indications_updated_at
  BEFORE UPDATE ON medicine_indications
  FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

-- 3) Laboratoire denormalise : copie fidele du lien reel ------
--    (laboratories.name -> medications.laboratory_name).
--    Les medicaments sans laboratoire source restent NULL
--    => affichage "Non renseigne", jamais un nom invente.
UPDATE medications m
SET laboratory_name = l.name
FROM laboratories l
WHERE m.laboratory_id = l.id
  AND m.laboratory_id IS NOT NULL
  AND m.laboratory_name IS DISTINCT FROM l.name;

-- 4) Recherche elargie : form, laboratoire, classe, substance
CREATE OR REPLACE FUNCTION fn_medication_search() RETURNS trigger AS $$
BEGIN
  NEW.search = to_tsvector('simple', COALESCE(NEW.name, '') || ' ' ||
    COALESCE(NEW.dci, '') || ' ' || COALESCE(NEW.generic_name, '') || ' ' ||
    COALESCE(NEW.dosage, '') || ' ' || COALESCE(NEW.presentation, '') || ' ' ||
    COALESCE(NEW.form, '') || ' ' || COALESCE(NEW.laboratory_name, '') || ' ' ||
    COALESCE(NEW.therapeutic_class, '') || ' ' ||
    COALESCE(NEW.substance_active, '') || ' ' ||
    COALESCE(NEW.barcode_ean13, ''));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recalcul du vecteur sur toutes les lignes (declenche le trigger)
UPDATE medications SET name = name;
