-- 920 : Fournisseurs — colonnes `type` et `ice` (identifiant fiscal marocain).
-- Migration ADDITIVE uniquement : aucune donnée existante n'est modifiée.
ALTER TABLE suppliers ADD COLUMN IF NOT EXISTS type TEXT;
ALTER TABLE suppliers ADD COLUMN IF NOT EXISTS ice TEXT;
