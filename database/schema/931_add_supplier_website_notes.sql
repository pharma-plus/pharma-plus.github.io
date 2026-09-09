-- 931 : Fournisseurs — colonnes `website` et `notes`.
-- Requises par le script d'import de la base initiale Maroc
-- (backend/scripts/import-morocco-suppliers.js).
-- Migration ADDITIVE uniquement : aucune donnée existante n'est modifiée.
ALTER TABLE suppliers ADD COLUMN IF NOT EXISTS website TEXT;
ALTER TABLE suppliers ADD COLUMN IF NOT EXISTS notes TEXT;
