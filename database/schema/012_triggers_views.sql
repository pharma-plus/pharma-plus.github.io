-- ============================================================
-- PHARMA MAROC GOLD ENTERPRISE V2.0
-- 012_triggers_views.sql — Triggers stock, vues matérialisées, index
-- ============================================================

-- ------------------------------------------------------------
-- Applique fn_set_updated_at sur les tables avec updated_at
-- ------------------------------------------------------------
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'pharmacies','branches','licenses','categories','laboratories',
    'medications','lots','suppliers','customers','purchase_orders',
    'sales','invoices','employees','prescriptions','website_settings',
    'blog_posts'
  ] LOOP
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_name = t AND column_name = 'updated_at') THEN
      EXECUTE format('DROP TRIGGER IF EXISTS trg_%s_updated ON %I;', t, t);
      EXECUTE format(
        'CREATE TRIGGER trg_%s_updated BEFORE UPDATE ON %I
           FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();', t, t);
    END IF;
  END LOOP;
END $$;

-- ------------------------------------------------------------
-- Moteur de stock : les stock_movements sont la source,
-- stock_balances est dérivé par trigger (intégrité garantie).
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_apply_stock_movement() RETURNS trigger AS $$
DECLARE
  v_new_qty numeric;
  v_res     numeric;
BEGIN
  -- Mouvements entrants (augmentent la balance)
  IF NEW.movement_type IN ('purchase_receipt','sale_return','inventory_in',
                           'transfer_in','release') THEN
    INSERT INTO stock_balances (pharmacy_id, branch_id, medication_id, lot_id,
                                quantity, reserved_quantity, updated_at)
    VALUES (NEW.pharmacy_id, NEW.branch_id, NEW.medication_id, NEW.lot_id,
            NEW.quantity, 0, now())
    ON CONFLICT (branch_id, medication_id, lot_id) DO UPDATE
      SET quantity = stock_balances.quantity + NEW.quantity, updated_at = now();

  -- Réservations : bloquent de la quantité disponible
  ELSIF NEW.movement_type = 'reservation' THEN
    UPDATE stock_balances
       SET reserved_quantity = reserved_quantity + abs(NEW.quantity), updated_at = now()
     WHERE branch_id = NEW.branch_id AND medication_id = NEW.medication_id
       AND lot_id IS NOT DISTINCT FROM NEW.lot_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Stock introuvable pour la réservation';
    END IF;

  -- Libérations de réservation
  ELSIF NEW.movement_type = 'release' THEN
    UPDATE stock_balances
       SET reserved_quantity = GREATEST(0, reserved_quantity - abs(NEW.quantity)),
           updated_at = now()
     WHERE branch_id = NEW.branch_id AND medication_id = NEW.medication_id
       AND lot_id IS NOT DISTINCT FROM NEW.lot_id;

  -- Mouvements sortants (décrémentent)
  ELSE
    UPDATE stock_balances
       SET quantity = stock_balances.quantity - abs(NEW.quantity), updated_at = now()
     WHERE branch_id = NEW.branch_id AND medication_id = NEW.medication_id
       AND lot_id IS NOT DISTINCT FROM NEW.lot_id
    RETURNING quantity INTO v_new_qty;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Stock insuffisant (aucune balance trouvée)';
    END IF;
    IF v_new_qty < 0 THEN
      RAISE EXCEPTION 'Stock insuffisant pour % (solde serait %)', NEW.medication_id, v_new_qty;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_stock_movement_apply ON stock_movements;
CREATE TRIGGER trg_stock_movement_apply
  AFTER INSERT ON stock_movements
  FOR EACH ROW EXECUTE FUNCTION fn_apply_stock_movement();

-- ------------------------------------------------------------
-- Vues matérialisées pour dashboards performants
-- ------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS mv_daily_sales CASCADE;
CREATE MATERIALIZED VIEW mv_daily_sales AS
  SELECT pharmacy_id, branch_id,
         date_trunc('day', created_at)::date  AS sale_date,
         count(*)                             AS nb_sales,
         sum(subtotal)                        AS subtotal,
         sum(discount_total)                  AS discounts,
         sum(tax_total)                       AS taxes,
         sum(total)                           AS total,
         sum(total - cost_total)              AS profit,
         sum(cost_total)                      AS cost_total
    FROM sales
   WHERE status = 'completed'
   GROUP BY pharmacy_id, branch_id, date_trunc('day', created_at)::date;

CREATE UNIQUE INDEX mv_daily_sales_pk ON mv_daily_sales(pharmacy_id, branch_id, sale_date);
CREATE INDEX mv_daily_sales_branch ON mv_daily_sales(branch_id, sale_date);

DROP MATERIALIZED VIEW IF EXISTS mv_stock_levels CASCADE;
CREATE MATERIALIZED VIEW mv_stock_levels AS
  SELECT b.pharmacy_id, b.branch_id, b.medication_id, b.lot_id,
         b.quantity, b.reserved_quantity,
         (b.quantity - b.reserved_quantity) AS available,
         l.expiry_date, l.lot_number
    FROM stock_balances b
    LEFT JOIN lots l ON l.id = b.lot_id;

CREATE UNIQUE INDEX mv_stock_levels_pk ON mv_stock_levels(branch_id, medication_id, lot_id);
CREATE INDEX mv_stock_levels_expiry ON mv_stock_levels(pharmacy_id, expiry_date);

-- Rafraîchissement de mv_daily_sales à chaque vente
CREATE OR REPLACE FUNCTION fn_refresh_daily_sales() RETURNS trigger AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_daily_sales;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_refresh_daily_sales ON sales;
CREATE TRIGGER trg_refresh_daily_sales
  AFTER INSERT OR UPDATE OR DELETE ON sales
  FOR EACH STATEMENT EXECUTE FUNCTION fn_refresh_daily_sales();

-- ------------------------------------------------------------
-- Index supplémentaires
-- ------------------------------------------------------------
CREATE INDEX idx_meds_revision ON medications(pharmacy_id, revision);
CREATE INDEX idx_customers_revision ON customers(pharmacy_id, revision);
CREATE INDEX idx_sales_customer_credit ON sales(customer_id) WHERE sale_type = 'credit';
CREATE INDEX idx_movements_created ON stock_movements(created_at);
