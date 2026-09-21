-- ============================================================
-- 20260921190000_cash_sessions_phase1.sql — PHARMA+ Phase 1 / 9 / 11
-- MIGRATION STRICTEMENT ADDITIVE : aucune table ni donnée
-- existante n'est modifiée ou supprimée.
-- ============================================================

-- 1) Sessions de caisse (ouverture / fermeture / écart)
CREATE TABLE IF NOT EXISTS cash_sessions (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id    uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  branch_id      uuid NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  user_id        uuid REFERENCES users(id) ON DELETE SET NULL,
  number         text,
  opened_at      timestamptz NOT NULL DEFAULT now(),
  initial_cash   numeric(14,2) NOT NULL DEFAULT 0,
  status         text NOT NULL DEFAULT 'OUVERTE'
                 CHECK (status IN ('OUVERTE','FERMEE')),
  closed_at      timestamptz,
  closed_by      uuid REFERENCES users(id) ON DELETE SET NULL,
  expected_cash  numeric(14,2),
  counted_cash   numeric(14,2),
  difference     numeric(14,2),
  totals_cash    numeric(14,2),
  totals_card_visa       numeric(14,2),
  totals_card_mastercard numeric(14,2),
  totals_other   numeric(14,2),
  notes          text,
  created_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_cash_sessions_branch
  ON cash_sessions(pharmacy_id, branch_id, opened_at DESC);

-- 2) Événements de caisse (entrées / sorties / remboursements / corrections)
CREATE TABLE IF NOT EXISTS cash_session_events (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  session_id  uuid NOT NULL REFERENCES cash_sessions(id) ON DELETE CASCADE,
  event_type  text NOT NULL CHECK (event_type IN ('entry','exit','refund','correction')),
  amount      numeric(14,2) NOT NULL DEFAULT 0,
  method      text NOT NULL DEFAULT 'cash',
  note        text,
  user_id     uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_cash_session_events
  ON cash_session_events(session_id, created_at);

-- 3) Ventes : lien session + idempotence hors-ligne
ALTER TABLE sales ADD COLUMN IF NOT EXISTS cash_session_id uuid REFERENCES cash_sessions(id) ON DELETE SET NULL;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS client_sale_id text;
CREATE UNIQUE INDEX IF NOT EXISTS uq_sales_client_sale
  ON sales(pharmacy_id, client_sale_id) WHERE client_sale_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_sales_cash_session
  ON sales(cash_session_id, created_at DESC);

-- 4) Audit caisse ↔ session
ALTER TABLE cash_audits ADD COLUMN IF NOT EXISTS cash_session_id uuid REFERENCES cash_sessions(id) ON DELETE SET NULL;

-- 5) Type de carte sur les paiements (Visa / Mastercard)
ALTER TABLE payments ADD COLUMN IF NOT EXISTS card_type text;

-- 6) Fiche médicament complète — colonnes additives uniquement
ALTER TABLE medications ADD COLUMN IF NOT EXISTS is_parapharmacie boolean NOT NULL DEFAULT false;
ALTER TABLE medications ADD COLUMN IF NOT EXISTS laboratory_name text;
ALTER TABLE medications ADD COLUMN IF NOT EXISTS therapeutic_class text;

SELECT fn_apply_tenant_rls('cash_sessions');
SELECT fn_apply_tenant_rls('cash_session_events');
