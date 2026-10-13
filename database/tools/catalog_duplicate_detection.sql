-- ============================================================
-- catalog_duplicate_detection.sql — DESTRUCTION INTERDITE.
-- Detection et classement des doublons du catalogue medications.
-- Lecture SEULE : aucune ecriture, aucune suppression.
-- Usage : execution sur l'environnement cible, resultat archive
-- dans le rapport de recette.
--
-- Classification (criteres, dans l'ordre) :
--   A. DOUBLON TECHNIQUE CANDIDAT : meme (pharmacy, nom, dosage,
--      forme, prix) — variante improbable, rapprochement a etudier.
--   B. VARIANTE LEGITIME : meme nom mais dosage/forme/prix differents
--      (ex. GINGIVAX x10 avec 10 formes distinctes) — NE PAS FUSIONNER.
--   C. EAN PARTAGE : meme code-barres sur plusieurs lignes —
--      anomalie de reference externe.
-- ============================================================

-- A. Groupes techniquement identiques (candidats au rapprochement).
select m.pharmacy_id, lower(trim(m.name)) as nom_normalise,
       coalesce(m.dosage, '') as dosage, coalesce(m.form, '') as forme,
       m.price_sale, count(*) as lignes,
       array_agg(m.id order by m.created_at) as ids
  from public.medications m
 group by 1, 2, 3, 4, 5
having count(*) > 1
 order by lignes desc, nom_normalise;

-- B. Volume par classe (rapport chiffre).
select
  (select count(*) from (
     select pharmacy_id, lower(trim(name)) from public.medications
      group by 1, 2 having count(*) > 1) g) as groupes_nom_total,
  (select count(*) from (
     select pharmacy_id, lower(trim(name)), coalesce(dosage,''),
            coalesce(form,''), coalesce(price_sale,-1)
       from public.medications
      group by 1,2,3,4,5 having count(*) > 1) g) as groupes_techniques,
  (select count(*) from (
     select barcode_ean13 from public.medications
      where barcode_ean13 is not null and barcode_ean13 <> ''
      group by 1 having count(*) > 1) g) as ean_partages;

-- C. Echantillon anonymise (tronque) pour revue humaine.
select substring(lower(trim(name)), 1, 18) as nom_tronque,
       count(*) as n,
       count(distinct coalesce(dosage, ''))  as dosages_distincts,
       count(distinct coalesce(form, ''))    as formes_distinctes,
       count(distinct price_sale)            as prix_distincts
  from public.medications
 group by 1, lower(trim(name))
having count(*) > 1
 order by n desc
 limit 25;
