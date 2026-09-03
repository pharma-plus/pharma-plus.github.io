-- =====================================================================
-- 910 : Tables de réception des commandes d'achat (réceptions partielles
-- ou complètes). Créées après coup : elles manquaient dans le schéma
-- initial alors que le module `purchases` les référencait déjà.
-- Migration additive et idempotente : sans effet si déjà appliquée.
-- =====================================================================

CREATE TABLE IF NOT EXISTS purchase_receptions (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id  UUID NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  order_id     UUID NOT NULL REFERENCES purchase_orders(id) ON DELETE CASCADE,
  branch_id    UUID NOT NULL REFERENCES branches(id),
  number       TEXT NOT NULL,
  notes        TEXT,
  received_by  UUID,
  received_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS purchase_reception_items (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id   UUID NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  reception_id  UUID NOT NULL REFERENCES purchase_receptions(id) ON DELETE CASCADE,
  order_item_id UUID NOT NULL REFERENCES purchase_order_items(id),
  medication_id UUID NOT NULL REFERENCES medications(id),
  lot_id        UUID REFERENCES lots(id) ON DELETE SET NULL,
  quantity      NUMERIC(12,3) NOT NULL CHECK (quantity > 0),
  expiry_date   DATE,
  cost_price    NUMERIC(14,2) NOT NULL DEFAULT 0,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS purchase_receptions_pharmacy_received_idx
  ON purchase_receptions (pharmacy_id, received_at DESC);

CREATE INDEX IF NOT EXISTS purchase_receptions_order_idx
  ON purchase_receptions (order_id);

CREATE INDEX IF NOT EXISTS purchase_reception_items_reception_idx
  ON purchase_reception_items (reception_id);
