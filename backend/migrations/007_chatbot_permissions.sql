-- Migration : ajouter les permissions chatbot à tous les rôles existants
-- Permet d'accéder aux routes /chatbot/* (message, transfert)

INSERT INTO role_permissions (role_id, permission_code)
SELECT id, 'chatbot:view' FROM roles
ON CONFLICT (role_id, permission_code) DO NOTHING;

INSERT INTO role_permissions (role_id, permission_code)
SELECT id, 'chatbot:edit' FROM roles
ON CONFLICT (role_id, permission_code) DO NOTHING;
