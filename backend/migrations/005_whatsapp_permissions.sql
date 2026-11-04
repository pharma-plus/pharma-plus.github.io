-- Migration : ajouter les permissions WhatsApp à tous les rôles existants
-- Permet d'accéder aux routes /whatsapp/* (config, conversations, messages)
-- ON CONFLICT DO NOTHING évite les doublons si la permission existe déjà.

INSERT INTO role_permissions (role_id, permission_code)
SELECT id, 'whatsapp:view' FROM roles
ON CONFLICT (role_id, permission_code) DO NOTHING;

INSERT INTO role_permissions (role_id, permission_code)
SELECT id, 'whatsapp:edit' FROM roles
ON CONFLICT (role_id, permission_code) DO NOTHING;
