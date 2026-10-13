-- ============================================================
-- 20261012160000_medication_merge_tables.sql
-- Tables de journalisation/alias pour les fusions de doublons du
-- catalogue (procédure documentée : catalog_merge_procedure.sql).
-- ADDITIF et RÉVERSIBLE : aucune ligne existante n'est modifiée ni
-- supprimée. Requise pour tracer et annuler une fusion sans DELETE.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.medication_merges (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  surviving_id uuid NOT NULL REFERENCES public.medications(id),
  merged_id    uuid NOT NULL REFERENCES public.medications(id),
  reason       text,
  operated_by  text,
  operated_at  timestamptz NOT NULL DEFAULT now(),
  reversed_at  timestamptz,
  UNIQUE (merged_id)
);

CREATE TABLE IF NOT EXISTS public.medications_merged_alias (
  old_id       uuid PRIMARY KEY REFERENCES public.medications(id),
  surviving_id uuid NOT NULL REFERENCES public.medications(id),
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_medication_merges_surviving
  ON public.medication_merges (surviving_id);
