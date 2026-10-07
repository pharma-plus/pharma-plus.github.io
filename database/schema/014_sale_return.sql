-- Retours / avoirs : logique métier de salesService.returnSale portée en
-- fonction atomique (une seule transaction) pour être réutilisable par la
-- Edge Function POST /sales/returns (l'HTTP Express reste inchangé).
CREATE OR REPLACE FUNCTION fn_sale_return(
  p_pharmacy    uuid,
  p_sale_id     uuid,
  p_branch_id   uuid,
  p_reason      text,
  p_return_type text,
  p_items       jsonb,
  p_user_id     uuid
) RETURNS jsonb AS $$
DECLARE
  s         sales%ROWTYPE;
  v_return_id uuid;
  v_number    text;
  v_refund    numeric(14,2) := 0;
  v_item      jsonb;
  v_med       uuid;
  v_qty       numeric(12,3);
  v_line      record;
  v_seen      uuid[] := '{}';
BEGIN
  IF p_return_type IS NULL OR p_return_type NOT IN ('refund', 'exchange', 'credit') THEN
    RAISE EXCEPTION 'Type de retour invalide' USING ERRCODE = 'P0001', HINT = 'VALIDATION';
  END IF;
  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0
     OR jsonb_array_length(p_items) > 200 THEN
    RAISE EXCEPTION 'Aucun article à retourner' USING ERRCODE = 'P0001', HINT = 'VALIDATION';
  END IF;

  SELECT * INTO s FROM sales WHERE id = p_sale_id AND pharmacy_id = p_pharmacy;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Vente introuvable' USING ERRCODE = 'P0001', HINT = 'SALE_NOT_FOUND';
  END IF;
  IF s.status <> 'completed' THEN
    RAISE EXCEPTION 'Vente déjà retournée' USING ERRCODE = 'P0001', HINT = 'ALREADY_RETURNED';
  END IF;
  IF s.branch_id <> p_branch_id THEN
    RAISE EXCEPTION 'Point de vente incompatible avec la vente' USING ERRCODE = 'P0001', HINT = 'VALIDATION';
  END IF;

  -- Validation : quantités retournées <= quantités vendues + calcul de l'avoir
  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) LOOP
    IF v_item->>'medication_id' IS NULL
       OR (v_item->>'medication_id') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
      RAISE EXCEPTION 'Article de la vente introuvable' USING ERRCODE = 'P0001', HINT = 'ITEM_NOT_FOUND';
    END IF;
    v_med := lower(v_item->>'medication_id');
    IF v_med = ANY (v_seen) THEN
      RAISE EXCEPTION 'Article en double dans la demande de retour'
        USING ERRCODE = 'P0001', HINT = 'DUPLICATE_ITEM';
    END IF;
    v_seen := array_append(v_seen, v_med);

    BEGIN
      v_qty := (v_item->>'quantity')::numeric;
    EXCEPTION WHEN others THEN
      RAISE EXCEPTION 'Quantité invalide' USING ERRCODE = 'P0001', HINT = 'VALIDATION';
    END;
    IF v_qty IS NULL OR v_qty <= 0 THEN
      RAISE EXCEPTION 'Quantité invalide' USING ERRCODE = 'P0001', HINT = 'VALIDATION';
    END IF;

    SELECT id, medication_id, lot_id, quantity, unit_price, line_total
      INTO v_line
      FROM sale_items
     WHERE sale_id = p_sale_id AND medication_id = v_med
     ORDER BY id
     LIMIT 1;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Article de la vente introuvable'
        USING ERRCODE = 'P0001', HINT = 'ITEM_NOT_FOUND';
    END IF;
    IF v_qty > v_line.quantity THEN
      RAISE EXCEPTION 'Quantité retournée supérieure à la quantité vendue'
        USING ERRCODE = 'P0001', HINT = 'INVALID_RETURN_QTY';
    END IF;
    v_refund := v_refund + v_line.line_total * (v_qty / v_line.quantity);
  END LOOP;
  v_refund := round(v_refund, 2);

  v_return_id := gen_random_uuid();
  v_number := fn_next_number(p_pharmacy, 'RTR');

  INSERT INTO sale_returns (id, pharmacy_id, branch_id, sale_id, number,
                            return_type, reason, total_refund, user_id)
  VALUES (v_return_id, p_pharmacy, p_branch_id, p_sale_id, v_number,
          p_return_type, nullif(p_reason, ''), v_refund, p_user_id);

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) LOOP
    v_med := lower(v_item->>'medication_id');
    v_qty := (v_item->>'quantity')::numeric;
    SELECT id, medication_id, lot_id, quantity, unit_price, line_total
      INTO v_line
      FROM sale_items
     WHERE sale_id = p_sale_id AND medication_id = v_med
     ORDER BY id
     LIMIT 1;

    INSERT INTO sale_return_items (return_id, pharmacy_id, sale_item_id,
                                   medication_id, lot_id, quantity, unit_price)
    VALUES (v_return_id, p_pharmacy, v_line.id, v_line.medication_id,
            v_line.lot_id, v_qty, v_line.unit_price);

    -- Le trigger trg_stock_movement_apply réintègre le stock de la branche.
    INSERT INTO stock_movements (pharmacy_id, branch_id, medication_id, lot_id,
                                 movement_type, quantity, unit_cost,
                                 reference_type, reference_id, user_id)
    VALUES (p_pharmacy, p_branch_id, v_line.medication_id, v_line.lot_id,
            'sale_return', v_qty, 0, 'sale_return', v_return_id, p_user_id);
  END LOOP;

  UPDATE sales SET status = 'returned' WHERE id = p_sale_id;

  -- Avoir
  INSERT INTO invoices (pharmacy_id, branch_id, sale_id, customer_id, number,
                        type, issue_date, subtotal, tax_total, total,
                        paid_amount, status, created_by)
  VALUES (p_pharmacy, p_branch_id, p_sale_id, s.customer_id,
          fn_next_number(p_pharmacy, 'AVR'),
          'avoir', CURRENT_DATE, 0, 0, -v_refund, -v_refund, 'paid', p_user_id);

  -- Remboursement du crédit client
  IF s.sale_type = 'credit' AND s.customer_id IS NOT NULL THEN
    UPDATE customers
       SET credit_balance = GREATEST(0, credit_balance - v_refund)
     WHERE id = s.customer_id;
  END IF;

  INSERT INTO audit_logs (pharmacy_id, user_id, action, module, entity, entity_id, new_values)
  VALUES (p_pharmacy, p_user_id, 'return', 'sales', 'sale', p_sale_id,
          jsonb_build_object('refundTotal', v_refund, 'number', v_number));

  RETURN jsonb_build_object('id', v_return_id, 'number', v_number, 'refund_total', v_refund);
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_sale_return(uuid, uuid, uuid, text, text, jsonb, uuid) IS
  'Retour/avoir atomique : sale_returns + sale_return_items + stock_movements + avoir + crédit client.';
