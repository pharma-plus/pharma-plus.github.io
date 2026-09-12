-- ============================================================
-- PHARMA MAROC GOLD ENTERPRISE V2.0
-- seeds/001_security.sql — Catalogue de permissions + rôles système
-- ============================================================

-- ------------------------------------------------------------
-- Catalogue des permissions (module:action)
-- ------------------------------------------------------------
DO $$
DECLARE
  m text;
  a text;
BEGIN
  FOREACH m IN ARRAY ARRAY[
    'dashboard','catalog','stock','inventory','purchases','suppliers',
    'customers','sales','cashier','prescriptions','employees','attendance',
    'accounting','reports','settings','users','notifications','backups',
    'audit','licenses','ai','website','support','sync'
  ] LOOP
    FOREACH a IN ARRAY ARRAY['view','create','edit','delete','export','approve','print']
    LOOP
      INSERT INTO permissions (code, name, module) VALUES
        (m || ':' || a, initcap(m) || ' - ' || a, m)
      ON CONFLICT (code) DO NOTHING;
    END LOOP;
  END LOOP;
END $$;

-- ------------------------------------------------------------
-- Rôles système (globaux, clone par pharmacie à la création)
-- ------------------------------------------------------------
INSERT INTO roles (id, pharmacy_id, name, code, is_system) VALUES
  ('00000000-0000-0000-0000-000000000001', NULL, 'Super Administrateur', 'super_admin', true),
  ('00000000-0000-0000-0000-000000000002', NULL, 'Pharmacien Administrateur', 'pharmacy_admin', true),
  ('00000000-0000-0000-0000-000000000003', NULL, 'Pharmacien', 'pharmacist', true),
  ('00000000-0000-0000-0000-000000000004', NULL, 'Assistant', 'assistant', true),
  ('00000000-0000-0000-0000-000000000005', NULL, 'Caissier', 'cashier', true),
  ('00000000-0000-0000-0000-000000000006', NULL, 'Gestionnaire de stock', 'stock_manager', true),
  ('00000000-0000-0000-0000-000000000007', NULL, 'Comptable', 'accountant', true),
  ('00000000-0000-0000-0000-000000000008', NULL, 'Employé', 'employee', true),
  ('00000000-0000-0000-0000-000000000009', NULL, 'Stagiaire', 'trainee', true)
ON CONFLICT (id) DO NOTHING;

-- pharmacy_admin : toutes les permissions
INSERT INTO role_permissions (role_id, permission_code)
SELECT '00000000-0000-0000-0000-000000000002', code FROM permissions
ON CONFLICT DO NOTHING;

-- pharmacien : gestion courante (sauf admin/système)
INSERT INTO role_permissions (role_id, permission_code)
SELECT '00000000-0000-0000-0000-000000000003', code FROM permissions
WHERE module NOT IN ('licenses','backups','audit','users','settings')
ON CONFLICT DO NOTHING;

-- caissier : vente, caisse, clients
INSERT INTO role_permissions (role_id, permission_code)
SELECT '00000000-0000-0000-0000-000000000005', code FROM permissions
WHERE module IN ('sales','cashier','customers','dashboard')
ON CONFLICT DO NOTHING;

-- gestionnaire de stock
INSERT INTO role_permissions (role_id, permission_code)
SELECT '00000000-0000-0000-0000-000000000006', code FROM permissions
WHERE module IN ('catalog','stock','inventory','purchases','suppliers','dashboard')
ON CONFLICT DO NOTHING;

-- comptable
INSERT INTO role_permissions (role_id, permission_code)
SELECT '00000000-0000-0000-0000-000000000007', code FROM permissions
WHERE module IN ('accounting','reports','sales','purchases','dashboard','customers','suppliers')
ON CONFLICT DO NOTHING;

-- assistant : vente, clients, prescriptions, catalogue (lecture)
INSERT INTO role_permissions (role_id, permission_code)
SELECT '00000000-0000-0000-0000-000000000004', code FROM permissions
WHERE (module IN ('sales','cashier','customers','prescriptions','dashboard')
       OR (module = 'catalog' AND code IN ('catalog:view','catalog:create','catalog:edit')))
ON CONFLICT DO NOTHING;

-- employé : tableau de bord + pointage
INSERT INTO role_permissions (role_id, permission_code)
SELECT '00000000-0000-0000-0000-000000000008', code FROM permissions
WHERE module IN ('attendance','dashboard') OR code IN ('catalog:view','reports:view')
ON CONFLICT DO NOTHING;

-- stagiaire : lecture seule de base
INSERT INTO role_permissions (role_id, permission_code)
SELECT '00000000-0000-0000-0000-000000000009', code FROM permissions
WHERE code IN ('dashboard:view','catalog:view','stock:view','reports:view','customers:view')
ON CONFLICT DO NOTHING;
