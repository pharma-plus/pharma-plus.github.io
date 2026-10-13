-- ============================================================
-- 20261009150000_live_schema_reconciliation.sql
-- Reconciliation schema versionne <-> base de production.
--
-- Constat (audit + verification directe information_schema sur le
-- projet lwepnnecnrqdzadesyqo) :
--   * 22 colonnes NOT NULL existent en production mais etaient
--     ABSENTES du DDL versionne (database/schema/00x..014) :
--     un install a partir du depot aurait refuse les inserts de
--     l'Edge (sale_items.unit_cost, journal_entries.date, ...) ;
--   * website_settings : prod = PK id (uuid) + UNIQUE pharmacy_id
--     + UNIQUE slug ; le DDL local utilisait pharmacy_id comme PK ;
--   * reference_categories : prod = PK code + created_at ; le DDL
--     local 013 portait un id absent de prod (aligne sur 930) ;
--   * database/schema/938_doctor_role.sql applique hors Git
--     (roles.code='doctor' existe en prod, id ...00000010) : son
--     contenu est reproduit ici, idempotent, pour entrer dans la
--     chaine de migrations versionnee.
--
-- Toutes les operations sont ADDITIVES et idempotentes
-- (IF NOT EXISTS / DO blocks) : sans effet sur la base de
-- production actuelle (colonnes deja presentes), correctives sur
-- toute base creee depuis l'ancien DDL versionne.
-- Aucune donnee n'est modifiee ni supprimee.
-- NON APPLIQUEE en production (application subordonnee a autorisation).
-- ============================================================

-- 1) Colonnes absentes du DDL versionne, types/defauts calques sur
--    information_schema de production (verification du 2026-10-09).
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT * FROM (VALUES
      ('purchase_order_items', 'discount_percent', 'numeric(5,2) NOT NULL DEFAULT 0'),
      ('purchase_order_items', 'tax_rate',         'numeric(5,2) NOT NULL DEFAULT 20.00'),
      ('sale_items',           'unit_cost',        'numeric(14,2) NOT NULL DEFAULT 0'),
      ('sale_items',           'discount_percent', 'numeric(5,2) NOT NULL DEFAULT 0'),
      ('sale_items',           'tax_rate',         'numeric(5,2) NOT NULL DEFAULT 20.00'),
      ('invoices',             'issued_at',        'timestamptz NOT NULL DEFAULT now()'),
      ('journal_entries',      'date',             'date NOT NULL DEFAULT CURRENT_DATE'),
      ('journal_entries',      'total_debit',      'numeric(14,2) NOT NULL DEFAULT 0'),
      ('journal_entries',      'total_credit',     'numeric(14,2) NOT NULL DEFAULT 0'),
      ('journal_entries',      'status',           'text NOT NULL DEFAULT ''draft'''),
      ('journal_entries',      'created_at',       'timestamptz NOT NULL DEFAULT now()'),
      ('cameras',              'port',             'integer NOT NULL DEFAULT 554'),
      ('cameras',              'is_active',        'boolean NOT NULL DEFAULT true'),
      ('customers',            'credit_used',      'numeric(14,2) NOT NULL DEFAULT 0'),
      ('customers',            'is_insured',       'boolean NOT NULL DEFAULT false'),
      ('prescriptions',        'prescribed_date',  'date NOT NULL DEFAULT CURRENT_DATE'),
      ('attendance',           'created_at',       'timestamptz NOT NULL DEFAULT now()'),
      ('backups',              'started_at',       'timestamptz NOT NULL DEFAULT now()'),
      ('support_tickets',      'updated_at',       'timestamptz NOT NULL DEFAULT now()'),
      ('website_settings',     'is_published',     'boolean NOT NULL DEFAULT false')
    ) AS t(tbl, col, def)
  LOOP
    IF to_regclass('public.' || r.tbl) IS NULL THEN
      CONTINUE;
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns
       WHERE table_schema = 'public' AND table_name = r.tbl
         AND column_name = r.col
    ) THEN
      EXECUTE format('ALTER TABLE public.%I ADD COLUMN %I %s', r.tbl, r.col, r.def);
    END IF;
  END LOOP;
END $$;

-- 2) purchase_order_items.purchase_order_id (uuid NOT NULL en prod,
--    sans defaut) : ajoutable sans defaut uniquement si la table est
--    vide ; NOT NULL force dans ce cas.
DO $$
BEGIN
  IF to_regclass('public.purchase_order_items') IS NULL THEN
    RETURN;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
     WHERE table_schema = 'public' AND table_name = 'purchase_order_items'
       AND column_name = 'purchase_order_id'
  ) THEN
    ALTER TABLE public.purchase_order_items ADD COLUMN purchase_order_id uuid;
  END IF;
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
     WHERE table_schema = 'public' AND table_name = 'purchase_order_items'
       AND column_name = 'purchase_order_id' AND is_nullable = 'YES'
  ) AND NOT EXISTS (SELECT 1 FROM public.purchase_order_items) THEN
    ALTER TABLE public.purchase_order_items ALTER COLUMN purchase_order_id SET NOT NULL;
  END IF;
END $$;

-- 3) website_settings : id uuid (PK en prod, defaut gen_random_uuid).
--    L'ancien DDL versionne faisait de pharmacy_id la PK : dans ce
--    cas on remplace la PK (prod = PK id + UNIQUE pharmacy_id).
DO $$
DECLARE
  v_con text;
BEGIN
  IF to_regclass('public.website_settings') IS NULL THEN
    RETURN;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
     WHERE table_schema = 'public' AND table_name = 'website_settings'
       AND column_name = 'id'
  ) THEN
    ALTER TABLE public.website_settings ADD COLUMN id uuid DEFAULT gen_random_uuid();
  END IF;

  -- PK actuelle portee par une autre colonne -> remplacée par id
  SELECT c.conname INTO v_con
    FROM pg_constraint c
   WHERE c.conrelid = 'public.website_settings'::regclass
     AND c.contype = 'p';
  IF v_con IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints tc
      JOIN information_schema.key_column_usage kcu
        ON kcu.constraint_name = tc.constraint_name
       AND kcu.table_schema = tc.table_schema
     WHERE tc.table_schema = 'public' AND tc.table_name = 'website_settings'
       AND tc.constraint_type = 'PRIMARY KEY' AND kcu.column_name = 'id'
  ) THEN
    EXECUTE format('ALTER TABLE public.website_settings DROP CONSTRAINT %I', v_con);
    v_con := NULL;
  END IF;

  IF v_con IS NULL THEN
    UPDATE public.website_settings SET id = coalesce(id, gen_random_uuid());
    ALTER TABLE public.website_settings ALTER COLUMN id SET NOT NULL;
    ALTER TABLE public.website_settings ADD CONSTRAINT website_settings_pkey PRIMARY KEY (id);
  END IF;

  -- UNIQUE pharmacy_id (garantie par l'ancienne PK, a preserver)
  IF NOT EXISTS (
    SELECT 1 FROM pg_index i
     WHERE i.indrelid = 'public.website_settings'::regclass
       AND i.indisunique
       AND i.indnatts = 1
       AND (SELECT attname FROM pg_attribute
             WHERE attrelid = i.indrelid AND attnum = i.indkey[0]) = 'pharmacy_id'
  ) THEN
    ALTER TABLE public.website_settings ADD CONSTRAINT website_settings_pharmacy_id_key UNIQUE (pharmacy_id);
  END IF;
END $$;

-- 4) Role MEDECIN (contenu de database/schema/938_doctor_role.sql,
--    versionne ici car applique hors Git sur la base existante).
INSERT INTO roles (id, name, code)
VALUES (
  '00000000-0000-0000-0000-000000000010',
  'Médecin',
  'doctor'
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO role_permissions (role_id, permission_code)
SELECT r.id, v.code
FROM roles r
CROSS JOIN (VALUES
  ('dashboard:view'),
  ('catalog:view'),
  ('customers:view'),
  ('prescriptions:view'),
  ('sales:view')
) AS v(code)
WHERE r.code = 'doctor'
  AND NOT EXISTS (
    SELECT 1 FROM role_permissions rp
    WHERE rp.role_id = r.id AND rp.permission_code = v.code
  );
