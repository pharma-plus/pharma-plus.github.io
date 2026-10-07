-- ============================================================
-- PHARMA MAROC GOLD ENTERPRISE V2.0
-- 013_sales_sale_date_payments.sql — Backfill sale_date & payments JSONB
-- ============================================================

-- Backfill sale_date from created_at for existing rows
UPDATE sales
SET sale_date = created_at::date
WHERE sale_date IS NULL OR sale_date = CURRENT_DATE;

-- Backfill payments JSONB from existing payment_method/paid_amount
UPDATE sales
SET payments = jsonb_build_array(
  jsonb_build_object(
    'method', payment_method,
    'amount', paid_amount,
    'received_at', created_at
  )
)
WHERE (payments IS NULL OR payments = '[]'::jsonb)
  AND paid_amount > 0;

-- Ensure NOT NULL defaults are enforced for future inserts
ALTER TABLE sales ALTER COLUMN sale_date SET DEFAULT CURRENT_DATE;
ALTER TABLE sales ALTER COLUMN payments SET DEFAULT '[]'::jsonb;

-- Add comment for documentation
COMMENT ON COLUMN sales.sale_date IS 'Date de vente (peut différer de created_at pour corrections/saisies rétroactives)';
COMMENT ON COLUMN sales.payments IS 'Détail des paiements JSONB : [{"method","amount","received_at",...}]';