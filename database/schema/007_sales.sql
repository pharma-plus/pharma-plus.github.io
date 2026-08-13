-- ============================================================
-- PHARMA MAROC GOLD ENTERPRISE V2.0
-- 007_sales.sql — Ventes (POS), paiements, factures, avoirs, retours
-- ============================================================

-- ------------------------------------------------------------
-- Ventes
-- ------------------------------------------------------------
CREATE TABLE sales (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id     uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  branch_id       uuid NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  user_id         uuid REFERENCES users(id) ON DELETE SET NULL,
  customer_id     uuid REFERENCES customers(id) ON DELETE SET NULL,
  number          text NOT NULL,
  sale_type       text NOT NULL DEFAULT 'pos'
                  CHECK (sale_type IN ('pos','credit','online','reservation')),
  status          text NOT NULL DEFAULT 'completed'
                  CHECK (status IN ('completed','returned','voided')),
  subtotal        numeric(14,2) NOT NULL DEFAULT 0,
  discount_total  numeric(14,2) NOT NULL DEFAULT 0,
  tax_total       numeric(14,2) NOT NULL DEFAULT 0,
  total           numeric(14,2) NOT NULL DEFAULT 0,
  cost_total      numeric(14,2) NOT NULL DEFAULT 0,   -- coût des marchandises vendues
  paid_amount     numeric(14,2) NOT NULL DEFAULT 0,
  change_amount   numeric(14,2) NOT NULL DEFAULT 0,
  payment_method  text NOT NULL DEFAULT 'cash'
                  CHECK (payment_method IN ('cash','card','mobile','mixed','credit','none')),
  prescription_id uuid,               -- FK ajoutée en 008_prescriptions.sql
  notes           text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (pharmacy_id, number)
);
CREATE INDEX idx_sales_branch ON sales(branch_id, created_at DESC);
CREATE INDEX idx_sales_customer ON sales(customer_id, created_at DESC);
CREATE INDEX idx_sales_user ON sales(user_id, created_at DESC);
CREATE INDEX idx_sales_created ON sales(pharmacy_id, created_at DESC);

-- ------------------------------------------------------------
-- Lignes de vente
-- ------------------------------------------------------------
CREATE TABLE sale_items (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id   uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  sale_id       uuid NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
  medication_id uuid NOT NULL REFERENCES medications(id) ON DELETE RESTRICT,
  lot_id        uuid REFERENCES lots(id) ON DELETE SET NULL,
  quantity      numeric(12,3) NOT NULL CHECK (quantity > 0),
  unit_price    numeric(14,2) NOT NULL DEFAULT 0,
  cost_price    numeric(14,2) NOT NULL DEFAULT 0,
  tva_rate      numeric(5,2) NOT NULL DEFAULT 20.00,
  discount      numeric(5,2) NOT NULL DEFAULT 0,
  line_total    numeric(14,2) NOT NULL DEFAULT 0
);
CREATE INDEX idx_sale_items_sale ON sale_items(sale_id);
CREATE INDEX idx_sale_items_med ON sale_items(medication_id);

-- ------------------------------------------------------------
-- Paiements
-- ------------------------------------------------------------
CREATE TABLE payments (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id  uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  sale_id      uuid REFERENCES sales(id) ON DELETE SET NULL,
  customer_id  uuid REFERENCES customers(id) ON DELETE SET NULL,
  method       text NOT NULL CHECK (method IN ('cash','card','mobile','mixed','credit')),
  amount       numeric(14,2) NOT NULL CHECK (amount > 0),
  reference    text,
  status       text NOT NULL DEFAULT 'completed' CHECK (status IN ('pending','completed','failed','refunded')),
  received_at  timestamptz NOT NULL DEFAULT now(),
  received_by  uuid REFERENCES users(id) ON DELETE SET NULL
);
CREATE INDEX idx_payments_sale ON payments(sale_id);
CREATE INDEX idx_payments_customer ON payments(customer_id, received_at DESC);

-- ------------------------------------------------------------
-- Factures & avoirs
-- ------------------------------------------------------------
CREATE TABLE invoices (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id  uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  branch_id    uuid NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  sale_id      uuid REFERENCES sales(id) ON DELETE SET NULL,
  customer_id  uuid REFERENCES customers(id) ON DELETE SET NULL,
  number       text NOT NULL,
  type         text NOT NULL DEFAULT 'invoice' CHECK (type IN ('invoice','avoir','credit_note')),
  issue_date   date NOT NULL DEFAULT CURRENT_DATE,
  due_date     date,
  subtotal     numeric(14,2) NOT NULL DEFAULT 0,
  tax_total    numeric(14,2) NOT NULL DEFAULT 0,
  total        numeric(14,2) NOT NULL DEFAULT 0,
  paid_amount  numeric(14,2) NOT NULL DEFAULT 0,
  status       text NOT NULL DEFAULT 'unpaid' CHECK (status IN ('unpaid','partial','paid','cancelled')),
  pdf_url      text,
  created_by   uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (pharmacy_id, number)
);
CREATE INDEX idx_invoices_customer ON invoices(customer_id, issue_date DESC);
CREATE INDEX idx_invoices_status ON invoices(pharmacy_id, status);

CREATE TABLE invoice_items (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id   uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  invoice_id    uuid NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
  medication_id uuid REFERENCES medications(id) ON DELETE SET NULL,
  description   text,
  quantity      numeric(12,3) NOT NULL DEFAULT 1,
  unit_price    numeric(14,2) NOT NULL DEFAULT 0,
  tva_rate      numeric(5,2) NOT NULL DEFAULT 20.00,
  line_total    numeric(14,2) NOT NULL DEFAULT 0
);

-- ------------------------------------------------------------
-- Retours / remboursements / échanges
-- ------------------------------------------------------------
CREATE TABLE sale_returns (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id  uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  branch_id    uuid NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  sale_id      uuid NOT NULL REFERENCES sales(id) ON DELETE RESTRICT,
  number       text NOT NULL,
  return_type  text NOT NULL DEFAULT 'refund' CHECK (return_type IN ('refund','exchange','credit')),
  reason       text,
  total_refund numeric(14,2) NOT NULL DEFAULT 0,
  returned_at  timestamptz NOT NULL DEFAULT now(),
  user_id      uuid REFERENCES users(id) ON DELETE SET NULL,
  UNIQUE (pharmacy_id, number)
);

CREATE TABLE sale_return_items (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id   uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  return_id     uuid NOT NULL REFERENCES sale_returns(id) ON DELETE CASCADE,
  sale_item_id  uuid REFERENCES sale_items(id) ON DELETE SET NULL,
  medication_id uuid NOT NULL REFERENCES medications(id) ON DELETE RESTRICT,
  lot_id        uuid REFERENCES lots(id) ON DELETE SET NULL,
  quantity      numeric(12,3) NOT NULL CHECK (quantity > 0),
  unit_price    numeric(14,2) NOT NULL DEFAULT 0
);

-- ------------------------------------------------------------
-- Tickets thermiques
-- ------------------------------------------------------------
CREATE TABLE receipts (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id  uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  sale_id      uuid NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
  branch_id    uuid NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  number       text NOT NULL,
  width_mm     int NOT NULL DEFAULT 80 CHECK (width_mm IN (58,80)),
  content      jsonb NOT NULL,      -- données structurées pour l'impression
  printed_at   timestamptz NOT NULL DEFAULT now(),
  printed_by   uuid REFERENCES users(id) ON DELETE SET NULL
);

-- ------------------------------------------------------------
-- Réservations clients
-- ------------------------------------------------------------
CREATE TABLE reservations (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id   uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  branch_id     uuid NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  customer_id   uuid REFERENCES customers(id) ON DELETE SET NULL,
  medication_id uuid NOT NULL REFERENCES medications(id) ON DELETE CASCADE,
  quantity      numeric(12,3) NOT NULL CHECK (quantity > 0),
  status        text NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending','ready','fulfilled','cancelled','expired')),
  expires_at    timestamptz,
  created_at    timestamptz NOT NULL DEFAULT now(),
  fulfilled_at  timestamptz
);
CREATE INDEX idx_reservations_status ON reservations(pharmacy_id, status);

SELECT fn_apply_tenant_rls('sales');
SELECT fn_apply_tenant_rls('sale_items');
SELECT fn_apply_tenant_rls('payments');
SELECT fn_apply_tenant_rls('invoices');
SELECT fn_apply_tenant_rls('invoice_items');
SELECT fn_apply_tenant_rls('sale_returns');
SELECT fn_apply_tenant_rls('sale_return_items');
SELECT fn_apply_tenant_rls('receipts');
SELECT fn_apply_tenant_rls('reservations');
