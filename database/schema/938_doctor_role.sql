-- ============================================================
-- 938_doctor_role.sql — PHASE 21 : role MEDECIN (additif).
-- Creation du role + permissions limitees (aucune donnee
-- inventee : codes existants dans public.permissions uniquement).
--
-- Autorisé        : patients (customers:view), prescriptions
--                    (prescriptions:view), historique (sales:view),
--                    catalogue (catalog:view), dashboard.
-- Non autorise     : caisse (cashier:*), marges (reports),
--                    fournisseurs (suppliers:*), administration
--                    (users:*, settings:*), gestion stock
--                    (inventory:*, stock:create/edit/delete).
-- Idempotent (IF NOT EXISTS / NOT EXISTS).
-- ============================================================

-- 1) Role MEDECIN ------------------------------------------------
INSERT INTO roles (id, name, code)
VALUES (
  '00000000-0000-0000-0000-000000000010',
  'Médecin',
  'doctor'
)
ON CONFLICT (id) DO NOTHING;

-- 2) Permissions limitees ----------------------------------------
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
