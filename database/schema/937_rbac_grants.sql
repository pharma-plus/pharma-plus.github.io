-- ============================================================
-- PHASE BLOC D — RBAC : grants minimaux pour ne pas casser
-- les rôles systeme existants une fois l'enforcement Edge actif.
-- Codes presents dans public.permissions (aucun code invente).
--   Caissier    : POS = lecture catalogue + branches (settings).
--   Comptable   : lecture catalogue + branches (rapprochements).
-- Idempotent (NOT EXISTS).
-- ============================================================
INSERT INTO role_permissions (role_id, permission_code)
SELECT r.id, v.code
FROM roles r
CROSS JOIN (VALUES ('catalog:view'), ('settings:view')) AS v(code)
WHERE r.name IN ('Caissier', 'Comptable')
  AND NOT EXISTS (
    SELECT 1 FROM role_permissions rp
    WHERE rp.role_id = r.id AND rp.permission_code = v.code
  );
