-- Migration : ajouter les permissions Super Admin à tous les rôles
-- Permet d'accéder aux routes /superadmin/* (dashboard, abonnements, monitoring)

INSERT INTO role_permissions (role_id, permission_code)
SELECT id, 'superadmin:view' FROM roles
ON CONFLICT (role_id, permission_code) DO NOTHING;

INSERT INTO role_permissions (role_id, permission_code)
SELECT id, 'superadmin:edit' FROM roles
ON CONFLICT (role_id, permission_code) DO NOTHING;

INSERT INTO role_permissions (role_id, permission_code)
SELECT id, 'subscription:view' FROM roles
ON CONFLICT (role_id, permission_code) DO NOTHING;

INSERT INTO role_permissions (role_id, permission_code)
SELECT id, 'subscription:edit' FROM roles
ON CONFLICT (role_id, permission_code) DO NOTHING;

INSERT INTO role_permissions (role_id, permission_code)
SELECT id, 'payment:view' FROM roles
ON CONFLICT (role_id, permission_code) DO NOTHING;

INSERT INTO role_permissions (role_id, permission_code)
SELECT id, 'monitoring:view' FROM roles
ON CONFLICT (role_id, permission_code) DO NOTHING;

INSERT INTO role_permissions (role_id, permission_code)
SELECT id, 'crm:view' FROM roles
ON CONFLICT (role_id, permission_code) DO NOTHING;

INSERT INTO role_permissions (role_id, permission_code)
SELECT id, 'crm:edit' FROM roles
ON CONFLICT (role_id, permission_code) DO NOTHING;

INSERT INTO role_permissions (role_id, permission_code)
SELECT id, 'support:view' FROM roles
ON CONFLICT (role_id, permission_code) DO NOTHING;

INSERT INTO role_permissions (role_id, permission_code)
SELECT id, 'support:edit' FROM roles
ON CONFLICT (role_id, permission_code) DO NOTHING;

INSERT INTO role_permissions (role_id, permission_code)
SELECT id, 'whatsapp:send' FROM roles
ON CONFLICT (role_id, permission_code) DO NOTHING;

INSERT INTO role_permissions (role_id, permission_code)
SELECT id, 'reports:export' FROM roles
ON CONFLICT (role_id, permission_code) DO NOTHING;
