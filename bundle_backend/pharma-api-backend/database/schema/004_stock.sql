-- ============================================================
-- PHARMA MAROC GOLD ENTERPRISE V2.0
-- 004_stock.sql — Lots, balances, mouvements, inventaire
-- ============================================================

-- ------------------------------------------------------------
-- Lots (numéro, fabrication, péremption)
-- ------------------------------------------------------------
CREATE TABLE lots (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id     uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  medication_id   uuid NOT NULL REFERENCES medications(id) ON DELETE CASCADE,
  supplier_id     uuid,                    -- FK ajoutée en 005
  lot_number      text NOT NULL,
  manufacture_date date,
  expiry_date     date NOT NULL,
  cost_price      numeric(14,2) NOT NULL DEFAULT 0,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (pharmacy_id, medication_id, lot_number)
);
CREATE INDEX idx_lots_medication ON lots(pharmacy_id, medication_id, expiry_date);
CREATE INDEX idx_lots_expiry ON lots(expiry_date);

-- ------------------------------------------------------------
-- Balances de stock (par succursale + lot) — source de vérité
-- ------------------------------------------------------------
CREATE TABLE stock_balances (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id        uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  branch_id          uuid NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  medication_id      uuid NOT NULL REFERENCES medications(id) ON DELETE CASCADE,
  lot_id             uuid REFERENCES lots(id) ON DELETE SET NULL,
  quantity           numeric(12,3) NOT NULL DEFAULT 0 CHECK (quantity >= 0),
  reserved_quantity  numeric(12,3) NOT NULL DEFAULT 0 CHECK (reserved_quantity >= 0),
  location           text,
  updated_at         timestamptz NOT NULL DEFAULT now(),
  UNIQUE (branch_id, medication_id, lot_id)
);
CREATE INDEX idx_stock_balance_branch ON stock_balances(branch_id, medication_id);
CREATE INDEX idx_stock_balance_lot ON stock_balances(lot_id);

-- ------------------------------------------------------------
-- Mouvements de stock (audit de chaque entrée/sortie)
-- ------------------------------------------------------------
CREATE TABLE stock_movements (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id     uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  branch_id       uuid NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  medication_id   uuid NOT NULL REFERENCES medications(id) ON DELETE CASCADE,
  lot_id          uuid REFERENCES lots(id) ON DELETE SET NULL,
  movement_type   text NOT NULL CHECK (movement_type IN
                   ('purchase_receipt','sale','sale_return','inventory_in',
                    'inventory_out','adjustment','transfer_in','transfer_out',
                    'reservation','release','expiry_loss','write_off')),
  quantity        numeric(12,3) NOT NULL CHECK (quantity <> 0),
  unit_cost       numeric(14,2) NOT NULL DEFAULT 0,
  reference_type  text,
  reference_id    uuid,
  notes           text,
  user_id         uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_stock_movements_branch ON stock_movements(branch_id, created_at DESC);
CREATE INDEX idx_stock_movements_med ON stock_movements(pharmacy_id, medication_id, created_at DESC);
CREATE INDEX idx_stock_movements_ref ON stock_movements(reference_type, reference_id);

-- ------------------------------------------------------------
-- Sessions d'inventaire (assisté lecteur de code-barres)
-- ------------------------------------------------------------
CREATE TABLE inventory_sessions (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id  uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  branch_id    uuid NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  status       text NOT NULL DEFAULT 'open' CHECK (status IN ('open','closed','cancelled')),
  started_by   uuid REFERENCES users(id) ON DELETE SET NULL,
  started_at   timestamptz NOT NULL DEFAULT now(),
  closed_by    uuid REFERENCES users(id) ON DELETE SET NULL,
  closed_at    timestamptz,
  notes        text
);

CREATE TABLE inventory_items (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id    uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  session_id     uuid NOT NULL REFERENCES inventory_sessions(id) ON DELETE CASCADE,
  medication_id  uuid NOT NULL REFERENCES medications(id) ON DELETE CASCADE,
  lot_id         uuid REFERENCES lots(id) ON DELETE SET NULL,
  system_qty     numeric(12,3) NOT NULL DEFAULT 0,
  counted_qty    numeric(12,3) NOT NULL DEFAULT 0,
  difference     numeric(12,3) GENERATED ALWAYS AS (counted_qty - system_qty) STORED,
  is_adjusted    boolean NOT NULL DEFAULT false
);
CREATE INDEX idx_inventory_items_session ON inventory_items(session_id);

-- ------------------------------------------------------------
-- Transferts entre succursales
-- ------------------------------------------------------------
CREATE TABLE stock_transfers (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id  uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  from_branch  uuid NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  to_branch    uuid NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  number       text NOT NULL,
  status       text NOT NULL DEFAULT 'pending'
               CHECK (status IN ('pending','in_transit','completed','cancelled')),
  notes        text,
  created_by   uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at   timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz
);

CREATE TABLE stock_transfer_items (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id    uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  transfer_id    uuid NOT NULL REFERENCES stock_transfers(id) ON DELETE CASCADE,
  medication_id  uuid NOT NULL REFERENCES medications(id) ON DELETE CASCADE,
  lot_id         uuid REFERENCES lots(id) ON DELETE SET NULL,
  quantity       numeric(12,3) NOT NULL CHECK (quantity > 0)
);
CREATE INDEX idx_transfer_items_transfer ON stock_transfer_items(transfer_id);

SELECT fn_apply_tenant_rls('lots');
SELECT fn_apply_tenant_rls('stock_balances');
SELECT fn_apply_tenant_rls('stock_movements');
SELECT fn_apply_tenant_rls('inventory_sessions');
SELECT fn_apply_tenant_rls('inventory_items');
SELECT fn_apply_tenant_rls('stock_transfers');
SELECT fn_apply_tenant_rls('stock_transfer_items');
