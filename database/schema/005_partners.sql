-- ============================================================
-- PHARMA MAROC GOLD ENTERPRISE V2.0
-- 005_partners.sql — Fournisseurs & Clients
-- ============================================================

-- ------------------------------------------------------------
-- Fournisseurs
-- ------------------------------------------------------------
CREATE TABLE suppliers (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id     uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  name            text NOT NULL,
  contact_name    text,
  phone           text,
  whatsapp        text,
  email           text,
  address         text,
  city            text,
  website         text,
  payment_terms   text,
  delivery_delay  int,               -- jours
  rating          numeric(3,2),      -- performance 0..5
  notes           text,
  status          text NOT NULL DEFAULT 'active' CHECK (status IN ('active','inactive')),
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_suppliers_name ON suppliers(pharmacy_id, lower(name) text_pattern_ops);

-- ------------------------------------------------------------
-- Paiements fournisseurs
-- ------------------------------------------------------------
CREATE TABLE supplier_payments (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id    uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  supplier_id    uuid NOT NULL REFERENCES suppliers(id) ON DELETE CASCADE,
  amount         numeric(14,2) NOT NULL CHECK (amount > 0),
  payment_date   date NOT NULL DEFAULT CURRENT_DATE,
  method         text NOT NULL DEFAULT 'cash' CHECK (method IN ('cash','bank','check','mobile')),
  reference      text,
  notes          text,
  created_by     uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at     timestamptz NOT NULL DEFAULT now()
);

-- ------------------------------------------------------------
-- Clients
-- ------------------------------------------------------------
CREATE TABLE customers (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id     uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  name            text NOT NULL,
  phone           text,
  whatsapp        text,
  email           text,
  address         text,
  city            text,
  birth_date      date,
  loyalty_points  numeric(12,2) NOT NULL DEFAULT 0,
  credit_limit    numeric(14,2) NOT NULL DEFAULT 0,
  credit_balance  numeric(14,2) NOT NULL DEFAULT 0,
  notes           text,
  status          text NOT NULL DEFAULT 'active' CHECK (status IN ('active','inactive')),
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  revision        bigint NOT NULL DEFAULT 1
);
CREATE INDEX idx_customers_name ON customers(pharmacy_id, lower(name) text_pattern_ops);
CREATE INDEX idx_customers_phone ON customers(pharmacy_id, phone);

-- ------------------------------------------------------------
-- FK différées (tables du module catalogue)
-- ------------------------------------------------------------
ALTER TABLE medication_suppliers
  ADD CONSTRAINT fk_medsupplier_supplier FOREIGN KEY (supplier_id)
  REFERENCES suppliers(id) ON DELETE CASCADE;

ALTER TABLE lots
  ADD CONSTRAINT fk_lot_supplier FOREIGN KEY (supplier_id)
  REFERENCES suppliers(id) ON DELETE SET NULL;

SELECT fn_apply_tenant_rls('suppliers');
SELECT fn_apply_tenant_rls('supplier_payments');
SELECT fn_apply_tenant_rls('customers');
