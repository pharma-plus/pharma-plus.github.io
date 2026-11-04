-- Migration 003 : Ajout de la colonne client_sale_id à la table sales
-- pour l'idempotence des créations de vente (évite les doublons en cas de
-- perte de réponse HTTP ou de double clic sur "Payer").
--
-- Cette migration est idempotente : elle ne doit être appliquée qu'une
-- seule fois sur la base de production.
--
-- Elle ne doit PAS être appliquée sur Supabase de production sans
-- autorisation explicite.

-- 1. Ajouter la colonne client_sale_id à la table sales
ALTER TABLE sales
  ADD COLUMN IF NOT EXISTS client_sale_id UUID;

-- 2. Ajouter le hash de contenu de la demande pour détecter
--    les doublons avec contenu différent (HTTP 409).
ALTER TABLE sales
  ADD COLUMN IF NOT EXISTS content_hash CHAR(64);

-- 3. Index unique sur (pharmacy_id, client_sale_id) pour garantir
--    l'unicité de la clé d'idempotence par pharmacie.
--    Les ventes créées avant cette migration ont client_sale_id NULL,
--    donc l'index unique les autorise toutes (NULL != NULL en SQL).
CREATE UNIQUE INDEX IF NOT EXISTS idx_sales_client_sale_id
  ON sales (pharmacy_id, client_sale_id)
  WHERE client_sale_id IS NOT NULL;

-- 4. Index sur content_hash pour les recherches d'idempotence
CREATE INDEX IF NOT EXISTS idx_sales_content_hash
  ON sales (content_hash)
  WHERE content_hash IS NOT NULL;

-- 5. Commentaire de documentation
COMMENT ON COLUMN sales.client_sale_id IS
  'Clé d idempotence côté client (clientSaleId) pour éviter les doublons de vente';
COMMENT ON COLUMN sales.content_hash IS
  'Hash SHA-256 du contenu de la demande (items + payments) pour détecter
  les doublons avec contenu différent (HTTP 409)';
COMMENT ON INDEX idx_sales_client_sale_id IS
  'Garantit qu une même clé d idempotence ne crée qu une seule vente par pharmacie';
COMMENT ON INDEX idx_sales_content_hash IS
  'Permet de trouver les ventes avec un hash de contenu identique pour
  la gestion des conflits idempotence';