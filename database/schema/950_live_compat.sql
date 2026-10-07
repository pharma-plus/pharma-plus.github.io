-- ============================================================
-- 950_live_compat.sql — Alignement additif de la base existante
-- sur le schéma du dépôt (colonnes absentes, NOT NULL hérités et
-- CHECK refusant les valeurs du code).
-- Idempotent : chaque bloc ne s'applique que si l'écart existe.
-- Aucune donnée n'est modifiée ni supprimée.
-- ============================================================

-- 1) Colonnes attendues par le code mais absentes de la base existante
ALTER TABLE sales ADD COLUMN IF NOT EXISTS payments jsonb NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE backups ADD COLUMN IF NOT EXISTS checksum text NOT NULL DEFAULT '';

-- 2) Colonnes héritées en NOT NULL alors que le code ne les fournit plus
--    (le code s'appuie sur les colonnes du dépôt : name, entry_id, ...)
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT * FROM (VALUES
      ('customers', 'first_name'),
      ('customers', 'last_name'),
      ('employees', 'employee_number'),
      ('prescriptions', 'branch_id'),
      ('cameras', 'ip_address'),
      ('journal_lines', 'journal_entry_id'),
      ('purchase_order_items', 'order_id'),
      ('employees', 'hire_date'),
      ('prescriptions', 'customer_id'),
      ('prescription_items', 'medication_id'),
      ('invoices', 'sale_id')
    ) AS t(tbl, col)
  LOOP
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
       WHERE table_schema = 'public' AND table_name = r.tbl
         AND column_name = r.col AND is_nullable = 'NO'
    ) THEN
      EXECUTE format('ALTER TABLE %I ALTER COLUMN %I DROP NOT NULL', r.tbl, r.col);
    END IF;
  END LOOP;
END $$;

-- 3) CHECK refusant les valeurs du dépôt : élargis à l'union
--    (valeurs historiques conservées, valeurs du code deviennent acceptées)
DO $$
DECLARE
  r        record;
  con_name text;
  con_def  text;
  cur_vals text[];
  all_vals text[];
BEGIN
  FOR r IN
    SELECT * FROM (VALUES
      ('sales',            'sale_type', ARRAY['pos','credit','online','reservation','cash','insurance']),
      ('sales',            'status',    ARRAY['pending','completed','returned','voided','cancelled','refunded']),
      ('purchase_orders',  'status',    ARRAY['draft','sent','partial','received','cancelled','confirmed','returned']),
      ('prescriptions',    'status',    ARRAY['received','processing','filled','rejected','archived','pending','partial','dispensed','cancelled','expired']),
      ('employees',        'status',    ARRAY['active','inactive','on_leave','terminated']),
      ('backups',          'type',      ARRAY['manual','auto','full','incremental','schema']),
      ('backups',          'status',    ARRAY['running','completed','failed','restoring','verified','pending']),
      ('support_tickets',  'priority',  ARRAY['low','normal','high','urgent','critical'])
    ) AS t(tbl, col, allowed)
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.tables
       WHERE table_schema = 'public' AND table_name = r.tbl
    ) THEN
      CONTINUE;
    END IF;

    con_name := r.tbl || '_' || r.col || '_check';
    SELECT pg_get_constraintdef(oid) INTO con_def
      FROM pg_constraint
     WHERE conrelid = format('%I.%I', 'public', r.tbl)::regclass
       AND conname = con_name;
    IF con_def IS NULL THEN
      CONTINUE; -- pas de contrainte côté base => déjà non restrictif
    END IF;

    SELECT array_agg(DISTINCT m[1]) INTO cur_vals
      FROM regexp_matches(con_def, '''([^'']+)''', 'g') AS x(m);
    IF cur_vals IS NULL THEN
      CONTINUE;
    END IF;
    IF NOT (r.allowed <@ cur_vals) THEN
      SELECT array_agg(DISTINCT v) INTO all_vals
        FROM unnest(cur_vals || r.allowed) AS v;
      EXECUTE format('ALTER TABLE %I DROP CONSTRAINT %I', r.tbl, con_name);
      EXECUTE format(
        'ALTER TABLE %I ADD CONSTRAINT %I CHECK (%I IN (%s))',
        r.tbl, con_name, r.col,
        (SELECT string_agg(quote_literal(v), ', ' ORDER BY v) FROM unnest(all_vals) v)
      );
    END IF;
  END LOOP;
END $$;
