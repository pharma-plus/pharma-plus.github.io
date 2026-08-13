-- ============================================================
-- PHARMA MAROC GOLD ENTERPRISE V2.0
-- 010_accounting.sql — Comptabilité, caisse, dépenses, TVA
-- ============================================================

-- Plan comptable simplifié
CREATE TABLE accounts (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id  uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  code         text NOT NULL,
  name         text NOT NULL,
  type         text NOT NULL CHECK (type IN ('asset','liability','equity','revenue','expense')),
  parent_id    uuid REFERENCES accounts(id) ON DELETE SET NULL,
  is_system    boolean NOT NULL DEFAULT false,
  created_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (pharmacy_id, code)
);

-- Journaux (écritures comptables)
CREATE TABLE journal_entries (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id   uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  branch_id     uuid REFERENCES branches(id) ON DELETE SET NULL,
  entry_number  text NOT NULL,
  entry_date    date NOT NULL DEFAULT CURRENT_DATE,
  journal_type  text NOT NULL DEFAULT 'cash'
                CHECK (journal_type IN ('cash','bank','sales','purchases','general','closing')),
  description   text,
  source_module text,
  source_id     text,
  created_by    uuid REFERENCES users(id) ON DELETE SET NULL,
  posted_at     timestamptz NOT NULL DEFAULT now(),
  is_posted     boolean NOT NULL DEFAULT true,
  UNIQUE (pharmacy_id, entry_number)
);
CREATE INDEX idx_journal_pharmacy ON journal_entries(pharmacy_id, entry_date DESC);

CREATE TABLE journal_lines (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id  uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  entry_id     uuid NOT NULL REFERENCES journal_entries(id) ON DELETE CASCADE,
  account_id   uuid NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
  label        text,
  debit        numeric(14,2) NOT NULL DEFAULT 0 CHECK (debit >= 0),
  credit       numeric(14,2) NOT NULL DEFAULT 0 CHECK (credit >= 0),
  CHECK (debit = 0 OR credit = 0),
  CHECK (debit <> 0 OR credit <> 0)
);
CREATE INDEX idx_journal_lines_entry ON journal_lines(entry_id);
CREATE INDEX idx_journal_lines_account ON journal_lines(account_id, entry_id);

-- ------------------------------------------------------------
-- Caisse
-- ------------------------------------------------------------
CREATE TABLE cash_registers (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id     uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  branch_id       uuid NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  user_id         uuid REFERENCES users(id) ON DELETE SET NULL,
  opened_at       timestamptz NOT NULL DEFAULT now(),
  closed_at       timestamptz,
  opening_balance numeric(14,2) NOT NULL DEFAULT 0,
  expected_balance numeric(14,2),
  counted_balance numeric(14,2),
  difference      numeric(14,2),
  status          text NOT NULL DEFAULT 'open' CHECK (status IN ('open','closed')),
  validated_by    uuid REFERENCES users(id) ON DELETE SET NULL,
  notes           text
);
CREATE INDEX idx_cash_registers_branch ON cash_registers(branch_id, opened_at DESC);

CREATE TABLE cash_register_movements (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id  uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  register_id  uuid NOT NULL REFERENCES cash_registers(id) ON DELETE CASCADE,
  movement_type text NOT NULL CHECK (movement_type IN ('in','out','sale','expense','refund')),
  amount       numeric(14,2) NOT NULL CHECK (amount > 0),
  reason       text,
  reference_id text,
  created_by   uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at   timestamptz NOT NULL DEFAULT now()
);

-- ------------------------------------------------------------
-- Dépenses
-- ------------------------------------------------------------
CREATE TABLE expense_categories (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id  uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  name         text NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (pharmacy_id, name)
);

CREATE TABLE expenses (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id  uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  branch_id    uuid REFERENCES branches(id) ON DELETE SET NULL,
  category_id  uuid REFERENCES expense_categories(id) ON DELETE SET NULL,
  amount       numeric(14,2) NOT NULL CHECK (amount > 0),
  expense_date date NOT NULL DEFAULT CURRENT_DATE,
  description  text,
  supplier_id  uuid REFERENCES suppliers(id) ON DELETE SET NULL,
  receipt_url  text,
  created_by   uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_expenses_pharmacy ON expenses(pharmacy_id, expense_date DESC);

-- ------------------------------------------------------------
-- Clôtures
-- ------------------------------------------------------------
CREATE TABLE closing_periods (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id  uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  period_type  text NOT NULL CHECK (period_type IN ('month','year')),
  period_key   text NOT NULL,      -- ex: 2024-07 ou 2024
  closed_at    timestamptz NOT NULL DEFAULT now(),
  closed_by    uuid REFERENCES users(id) ON DELETE SET NULL,
  UNIQUE (pharmacy_id, period_type, period_key)
);

SELECT fn_apply_tenant_rls('accounts');
SELECT fn_apply_tenant_rls('journal_entries');
SELECT fn_apply_tenant_rls('journal_lines');
SELECT fn_apply_tenant_rls('cash_registers');
SELECT fn_apply_tenant_rls('cash_register_movements');
SELECT fn_apply_tenant_rls('expense_categories');
SELECT fn_apply_tenant_rls('expenses');
SELECT fn_apply_tenant_rls('closing_periods');
