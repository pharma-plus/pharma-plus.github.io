-- ============================================================
-- PHARMA MAROC GOLD ENTERPRISE V2.0
-- 006_purchases.sql — Commandes fournisseurs, réceptions, retours
-- ============================================================

-- ------------------------------------------------------------
-- Commandes fournisseurs
-- ------------------------------------------------------------
CREATE TABLE purchase_orders (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id   uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  branch_id     uuid NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  supplier_id   uuid NOT NULL REFERENCES suppliers(id) ON DELETE RESTRICT,
  number        text NOT NULL,
  status        text NOT NULL DEFAULT 'draft'
                CHECK (status IN ('draft','sent','confirmed','partial','received','returned','cancelled')),
  order_date    date NOT NULL DEFAULT CURRENT_DATE,
  expected_date date,
  received_date date,
  subtotal      numeric(14,2) NOT NULL DEFAULT 0,
  tax_total     numeric(14,2) NOT NULL DEFAULT 0,
  discount_total numeric(14,2) NOT NULL DEFAULT 0,
  total         numeric(14,2) NOT NULL DEFAULT 0,
  notes         text,
  created_by    uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (pharmacy_id, number)
);
CREATE INDEX idx_po_supplier ON purchase_orders(pharmacy_id, supplier_id, created_at DESC);
CREATE INDEX idx_po_status ON purchase_orders(pharmacy_id, status);

CREATE TABLE purchase_order_items (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id        uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  order_id           uuid NOT NULL REFERENCES purchase_orders(id) ON DELETE CASCADE,
  medication_id      uuid NOT NULL REFERENCES medications(id) ON DELETE RESTRICT,
  quantity_ordered   numeric(12,3) NOT NULL CHECK (quantity_ordered > 0),
  quantity_received  numeric(12,3) NOT NULL DEFAULT 0,
  unit_cost          numeric(14,2) NOT NULL DEFAULT 0,
  tva_rate           numeric(5,2) NOT NULL DEFAULT 20.00,
  discount           numeric(5,2) NOT NULL DEFAULT 0,
  UNIQUE (order_id, medication_id)
);
CREATE INDEX idx_po_items_order ON purchase_order_items(order_id);

-- ------------------------------------------------------------
-- Réceptions
-- ------------------------------------------------------------
CREATE TABLE purchase_receptions (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id  uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  order_id     uuid NOT NULL REFERENCES purchase_orders(id) ON DELETE CASCADE,
  branch_id    uuid NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  number       text NOT NULL,
  received_at  timestamptz NOT NULL DEFAULT now(),
  notes        text,
  received_by  uuid REFERENCES users(id) ON DELETE SET NULL,
  UNIQUE (pharmacy_id, number)
);

CREATE TABLE purchase_reception_items (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id   uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  reception_id  uuid NOT NULL REFERENCES purchase_receptions(id) ON DELETE CASCADE,
  order_item_id uuid REFERENCES purchase_order_items(id) ON DELETE SET NULL,
  medication_id uuid NOT NULL REFERENCES medications(id) ON DELETE RESTRICT,
  lot_id        uuid REFERENCES lots(id) ON DELETE SET NULL,
  quantity      numeric(12,3) NOT NULL CHECK (quantity > 0),
  expiry_date   date,
  cost_price    numeric(14,2) NOT NULL DEFAULT 0
);

-- ------------------------------------------------------------
-- Retours fournisseur
-- ------------------------------------------------------------
CREATE TABLE purchase_returns (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id  uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  branch_id    uuid NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  supplier_id  uuid NOT NULL REFERENCES suppliers(id) ON DELETE RESTRICT,
  order_id     uuid REFERENCES purchase_orders(id) ON DELETE SET NULL,
  number       text NOT NULL,
  reason       text,
  total        numeric(14,2) NOT NULL DEFAULT 0,
  returned_at  timestamptz NOT NULL DEFAULT now(),
  created_by   uuid REFERENCES users(id) ON DELETE SET NULL,
  UNIQUE (pharmacy_id, number)
);

CREATE TABLE purchase_return_items (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id   uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  return_id     uuid NOT NULL REFERENCES purchase_returns(id) ON DELETE CASCADE,
  medication_id uuid NOT NULL REFERENCES medications(id) ON DELETE RESTRICT,
  lot_id        uuid REFERENCES lots(id) ON DELETE SET NULL,
  quantity      numeric(12,3) NOT NULL CHECK (quantity > 0),
  cost_price    numeric(14,2) NOT NULL DEFAULT 0
);

SELECT fn_apply_tenant_rls('purchase_orders');
SELECT fn_apply_tenant_rls('purchase_order_items');
SELECT fn_apply_tenant_rls('purchase_receptions');
SELECT fn_apply_tenant_rls('purchase_reception_items');
SELECT fn_apply_tenant_rls('purchase_returns');
SELECT fn_apply_tenant_rls('purchase_return_items');
