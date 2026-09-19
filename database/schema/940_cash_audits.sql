-- ============================================================
-- 940_cash_audits.sql — Audit caisse (attendu vs compté).
-- Migration additive et idempotente. À exécuter dans le SQL
-- Editor Supabase si la table n'existe pas encore.
-- ============================================================

CREATE TABLE IF NOT EXISTS cash_audits (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id    uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  branch_id      uuid NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  audit_date     date NOT NULL DEFAULT CURRENT_DATE,
  expected_cash  numeric(14,2) NOT NULL DEFAULT 0,
  counted_cash   numeric(14,2) NOT NULL DEFAULT 0,
  difference     numeric(14,2) NOT NULL DEFAULT 0,
  sales_total    numeric(14,2) NOT NULL DEFAULT 0,
  payments_cash  numeric(14,2) NOT NULL DEFAULT 0,
  payments_card  numeric(14,2) NOT NULL DEFAULT 0,
  payments_other numeric(14,2) NOT NULL DEFAULT 0,
  notes          text,
  user_id        uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cash_audits_pharmacy
  ON cash_audits(pharmacy_id, created_at DESC);

SELECT fn_apply_tenant_rls('cash_audits');
