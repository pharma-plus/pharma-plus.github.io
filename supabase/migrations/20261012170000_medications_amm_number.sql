-- ============================================================
-- 20261012170000_medications_amm_number.sql
-- Les 7 « barcode_ean13 » actuels sont des NUMÉROS AMM dé-spacés
-- (échouent tous le checksum GS1-13) : faux codes-barres dans le
-- champ de scan. On ajoute une colonne dédiée pour préserver l'AMM.
-- Le déplacement des valeurs (AMM -> amm_number, EAN -> NULL) est
-- fait par script avec la logique checksum JS vérifiée (ean_check).
-- ADDITIF et non destructif.
-- ============================================================

ALTER TABLE public.medications ADD COLUMN IF NOT EXISTS amm_number text;
