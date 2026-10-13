-- ============================================================
-- ean_gap_report.sql — DESTRUCTION INTERDITE. Lecture seule.
-- Etat exact du defaut « 99,8 % du catalogue sans EAN » (D-4) et
-- potentiel d'enrichissement depuis les sources DEJA autorisees
-- (reference_products, alimentee par reference_sync_runs).
--
-- REGLES : ne generer AUCUN code ; ne pas ecraser un EAN existant ;
-- toute ecriture future sera un remplissage (null -> valeur) avec
-- colonnes de provenance (source, source_updated_at) et audit.
--
-- Constats du 2026-10-10 (prod lwepnnecnrqdzadesyqo) :
--   * medications : 5016 lignes, 5009 sans EAN, 7 avec EAN-13 valide
--     (format 13 chiffres), 0 qr_code renseigne.
--   * reference_products : 5054 lignes, SEULEMENT 33 avec EAN-13
--     valide — la source de reference est elle-meme quasi privee
--     de codes-barres.
--   * Candidats d'enrichissement automatique par nom exact +
--     EAN valide en reference : 3 au maximum — l'enrichissement
--     automatique depuis les sources actuelles est MARGINAL.
--   * Conclusion strategique : la fermeture du deficit EAN exige
--     un apport externe autorise (laboratoires, ANAM, GS1) ; aucun
--     outil logiciel ne peut fabriquer ces codes de facon honnete.
-- ============================================================

select
  (select count(*) from public.medications)                                    as med_total,
  (select count(*) from public.medications
    where barcode_ean13 is null or barcode_ean13 = '')                         as med_sans_ean,
  (select count(*) from public.medications
    where barcode_ean13 ~ '^[0-9]{13}$')                                       as med_ean13_valide,
  (select count(*) from public.medications
    where barcode_ean13 is not null and barcode_ean13 <> ''
      and barcode_ean13 !~ '^[0-9]{13}$')                                      as med_ean_invalide,
  (select count(*) from public.medications
    where qr_code is not null and qr_code <> '')                                as med_qr,
  (select count(*) from public.reference_products)                              as ref_total,
  (select count(*) from public.reference_products
    where barcode_ean13 ~ '^[0-9]{13}$')                                       as ref_ean13_valide,
  (select count(*) from public.medications m
    where (m.barcode_ean13 is null or m.barcode_ean13 = '')
      and exists (select 1 from public.reference_products r
                   where lower(trim(r.name)) = lower(trim(m.name))
                     and r.barcode_ean13 ~ '^[0-9]{13}$'))                     as candidats_enrichissement;

-- Repartition du deficit par categorie metier (priorisation).
select coalesce(nullif(trim(category_id::text), ''), '(sans categorie)') as categorie,
       count(*) as total,
       count(*) filter (where barcode_ean13 is null or barcode_ean13 = '') as sans_ean
  from public.medications
 group by 1
 order by sans_ean desc
 limit 15;
