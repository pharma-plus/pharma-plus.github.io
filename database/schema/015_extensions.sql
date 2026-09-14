-- ============================================================
-- PHARMA MAROC GOLD ENTERPRISE V2.0
-- 015_extensions.sql — Permissions des nouveaux modules
-- ============================================================

-- Permissions des modules "reference" et "cameras"
DO $$
DECLARE
  m text;
  a text;
BEGIN
  FOREACH m IN ARRAY ARRAY['reference','cameras'] LOOP
    FOREACH a IN ARRAY ARRAY['view','create','edit','delete','export','approve','print'] LOOP
      INSERT INTO permissions (code, name, module) VALUES
        (m || ':' || a, initcap(m) || ' - ' || a, m)
      ON CONFLICT (code) DO NOTHING;
    END LOOP;
  END LOOP;
END $$;

-- pharmacy_admin (système + chaque pharmacie existante) : toutes les nouvelles permissions
INSERT INTO role_permissions (role_id, permission_code)
SELECT r.id, p.code
  FROM roles r CROSS JOIN permissions p
 WHERE p.module IN ('reference','cameras')
   AND r.code = 'pharmacy_admin'
ON CONFLICT DO NOTHING;

-- pharmacien (système + chaque pharmacie) : lecture / import de la base de référence
INSERT INTO role_permissions (role_id, permission_code)
SELECT r.id, p.code
  FROM roles r CROSS JOIN permissions p
 WHERE r.code = 'pharmacist'
   AND p.code IN ('reference:view','reference:create','reference:edit','cameras:view')
ON CONFLICT DO NOTHING;

-- gestionnaire de stock : lecture de la base de référence
INSERT INTO role_permissions (role_id, permission_code)
SELECT r.id, p.code
  FROM roles r CROSS JOIN permissions p
 WHERE r.code = 'stock_manager'
   AND p.code IN ('reference:view','cameras:view')
ON CONFLICT DO NOTHING;
