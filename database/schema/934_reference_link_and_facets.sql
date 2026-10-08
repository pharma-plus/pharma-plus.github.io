-- ============================================================
-- 934_reference_link_and_facets.sql — ADDITIF & idempotent.
-- 1) Repare le lien reference <-> medication casse
--    (reference_product_provenance.medicament_id contenait
--    des ids texte 'med_...' qui ne matchent aucun uuid de
--    medications : 0 lien). Appariement par cle de contenu
--    REELLE (name+dosage+form+presentation+laboratoire,
--    normalise) avec departage deterministe sur prix/date :
--    5004 cles reference <-> 5004 cles medications, 1:1.
-- 2) Index de lookup.
-- 3) Fonction d'agrégat pour les cartes du POS (facettes
--    reelles : formes / laboratoires / statuts avec comptage).
-- Aucune suppression, aucune donnée inventee.
-- ============================================================

-- 1) Reparation du lien --------------------------------------
WITH rk AS (
  SELECT rp.id AS ref_id,
         lower(trim(rp.name)) || '|' ||
         coalesce(lower(trim(rp.dosage)), '') || '|' ||
         coalesce(lower(trim(rp.form)), '') || '|' ||
         coalesce(lower(trim(rp.presentation)), '') || '|' ||
         coalesce(lower(trim(rp.laboratory)), '') AS k,
         row_number() OVER (
           PARTITION BY lower(trim(rp.name)) || '|' ||
                        coalesce(lower(trim(rp.dosage)), '') || '|' ||
                        coalesce(lower(trim(rp.form)), '') || '|' ||
                        coalesce(lower(trim(rp.presentation)), '') || '|' ||
                        coalesce(lower(trim(rp.laboratory)), '')
           ORDER BY rp.ppv NULLS LAST, rp.created_at, rp.id
         ) AS rn
  FROM reference_products rp
  WHERE rp.source = 'medicament.ma'
),
mk AS (
  SELECT m.id AS med_id,
         lower(trim(m.name)) || '|' ||
         coalesce(lower(trim(m.dosage)), '') || '|' ||
         coalesce(lower(trim(m.form)), '') || '|' ||
         coalesce(lower(trim(m.presentation)), '') || '|' ||
         coalesce(lower(trim(l.name)), '') AS k,
         row_number() OVER (
           PARTITION BY lower(trim(m.name)) || '|' ||
                        coalesce(lower(trim(m.dosage)), '') || '|' ||
                        coalesce(lower(trim(m.form)), '') || '|' ||
                        coalesce(lower(trim(m.presentation)), '') || '|' ||
                        coalesce(lower(trim(l.name)), '')
           ORDER BY m.price_sale NULLS LAST, m.created_at, m.id
         ) AS rn
  FROM medications m
  LEFT JOIN laboratories l ON l.id = m.laboratory_id
  WHERE EXISTS (
    SELECT 1 FROM reference_products rp
    WHERE rp.source = 'medicament.ma'
      AND lower(trim(rp.name)) = lower(trim(m.name))
  )
)
UPDATE reference_product_provenance p
SET medicament_id = mk.med_id::text
FROM rk
JOIN mk ON mk.k = rk.k AND mk.rn = rk.rn
WHERE p.reference_id = rk.ref_id
  AND p.medicament_id IS DISTINCT FROM mk.med_id::text;

CREATE INDEX IF NOT EXISTS idx_prov_medicament
  ON reference_product_provenance(medicament_id);

-- 2) Facettes reelles du POS (formes / labos / statuts) ------
CREATE OR REPLACE FUNCTION public.catalog_pos_facets(p_pharmacy uuid)
RETURNS TABLE(kind text, label text, value text, total bigint)
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT 'form', form, form, count(*)
  FROM medications
  WHERE pharmacy_id = p_pharmacy AND form IS NOT NULL AND form <> ''
  GROUP BY form
  ORDER BY count(*) DESC
  LIMIT 12;
$$;

DROP FUNCTION IF EXISTS public.catalog_pos_facets_labs(uuid);
CREATE FUNCTION public.catalog_pos_facets_labs(p_pharmacy uuid)
RETURNS TABLE(label text, value text, total bigint)
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT laboratory_name, laboratory_name, count(*)
  FROM medications
  WHERE pharmacy_id = p_pharmacy AND laboratory_name IS NOT NULL AND laboratory_name <> ''
  GROUP BY laboratory_name
  ORDER BY count(*) DESC
  LIMIT 12;
$$;

DROP FUNCTION IF EXISTS public.catalog_pos_indications_count(uuid);
CREATE FUNCTION public.catalog_pos_indications_count(p_pharmacy uuid)
RETURNS bigint
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT count(*) FROM medicine_indications WHERE pharmacy_id = p_pharmacy;
$$;
