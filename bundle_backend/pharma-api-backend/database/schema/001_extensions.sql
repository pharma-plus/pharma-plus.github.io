-- ============================================================
-- PHARMA MAROC GOLD ENTERPRISE V2.0
-- 001_extensions.sql — Extensions, helpers & triggers
-- PostgreSQL 15+
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;      -- gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS pg_trgm;       -- recherche trigramme
CREATE EXTENSION IF NOT EXISTS unaccent;      -- recherche sans accents (FR/AR)
CREATE EXTENSION IF NOT EXISTS citext;        -- email insensible à la casse

-- ------------------------------------------------------------
-- Trigger: mise à jour automatique de updated_at
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_set_updated_at() RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ------------------------------------------------------------
-- Trigger: colonne de recherche tsvector pour les médicaments
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_medication_search() RETURNS trigger AS $$
BEGIN
  NEW.search = to_tsvector('simple', COALESCE(NEW.name, '') || ' ' ||
    COALESCE(NEW.dci, '') || ' ' || COALESCE(NEW.generic_name, '') || ' ' ||
    COALESCE(NEW.dosage, '') || ' ' || COALESCE(NEW.presentation, '') || ' ' ||
    COALESCE(NEW.barcode_ean13, ''));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ------------------------------------------------------------
-- Trigger: révision monotone pour la synchronisation offline
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_set_revision() RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'UPDATE' THEN
    NEW.revision = OLD.revision + 1;
  ELSE
    NEW.revision = 1;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ------------------------------------------------------------
-- RLS : isolation multi-pharmacies (helper)
-- Applique RLS + policy tenant_isolation sur toute table métier
-- disposant de la colonne pharmacy_id.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_apply_tenant_rls(tbl text) RETURNS void AS $$
BEGIN
  EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY;', tbl);
  EXECUTE format(
    'CREATE POLICY tenant_isolation ON %I
       USING (pharmacy_id = current_setting(''app.pharmacy_id'', true)::uuid)
       WITH CHECK (pharmacy_id = current_setting(''app.pharmacy_id'', true)::uuid);',
    tbl);
END;
$$ LANGUAGE plpgsql;

-- ------------------------------------------------------------
-- Numérotation séquentielle par pharmacie (factures, bons, ...)
-- Génère un numéro type "FAC-2024-000123" atomique par tenant.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sequence_counters (
  pharmacy_id  uuid NOT NULL,
  prefix       text NOT NULL,
  last_value   bigint NOT NULL DEFAULT 0,
  year         int  NOT NULL DEFAULT EXTRACT(YEAR FROM now())::int,
  PRIMARY KEY (pharmacy_id, prefix, year)
);

CREATE OR REPLACE FUNCTION fn_next_number(p_pharmacy uuid, p_prefix text)
RETURNS text AS $$
DECLARE
  v_year  int := EXTRACT(YEAR FROM now())::int;
  v_value bigint;
BEGIN
  INSERT INTO sequence_counters (pharmacy_id, prefix, year, last_value)
  VALUES (p_pharmacy, p_prefix, v_year, 1)
  ON CONFLICT (pharmacy_id, prefix, year)
  DO UPDATE SET last_value = sequence_counters.last_value + 1
  RETURNING last_value INTO v_value;

  RETURN format('%s-%s-%s', p_prefix, v_year, lpad(v_value::text, 6, '0'));
END;
$$ LANGUAGE plpgsql;
