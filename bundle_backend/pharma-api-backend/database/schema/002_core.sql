-- ============================================================
-- PHARMA MAROC GOLD ENTERPRISE V2.0
-- 002_core.sql — Tenants, licences, utilisateurs, RBAC, audit
-- ============================================================

-- ------------------------------------------------------------
-- Pharmacies (tenants)
-- ------------------------------------------------------------
CREATE TABLE pharmacies (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug           text NOT NULL UNIQUE,
  name           text NOT NULL,
  legal_name     text,
  logo_url       text,
  icon_url       text,
  banner_url     text,
  colors         jsonb NOT NULL DEFAULT '{"primary":"#1B5E20","secondary":"#0D47A1","menu":"#0A2A0F","charts":["#2E7D32","#1565C0","#FFB300","#6A1B9A","#00897B"]}',
  address        text,
  city           text,
  phone          text,
  whatsapp       text,
  email          text,
  website        text,
  currency       text NOT NULL DEFAULT 'MAD',
  languages      text[] NOT NULL DEFAULT ARRAY['fr','ar','en'],
  default_lang   text NOT NULL DEFAULT 'fr',
  timezone       text NOT NULL DEFAULT 'Africa/Casablanca',
  status         text NOT NULL DEFAULT 'active'
                 CHECK (status IN ('active','suspended','deleted','trial')),
  settings       jsonb NOT NULL DEFAULT '{}',
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now()
);

-- ------------------------------------------------------------
-- Succursales
-- ------------------------------------------------------------
CREATE TABLE branches (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  name        text NOT NULL,
  code        text NOT NULL,
  address     text,
  city        text,
  phone       text,
  is_main     boolean NOT NULL DEFAULT false,
  status      text NOT NULL DEFAULT 'active' CHECK (status IN ('active','inactive')),
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (pharmacy_id, code)
);

-- ------------------------------------------------------------
-- Licences
-- ------------------------------------------------------------
CREATE TABLE licenses (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id       uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  type              text NOT NULL CHECK (type IN ('trial','standard','professional','enterprise')),
  status            text NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active','suspended','expired','cancelled')),
  billing_cycle     text NOT NULL DEFAULT 'monthly' CHECK (billing_cycle IN ('monthly','annual')),
  activation_date   timestamptz NOT NULL DEFAULT now(),
  expiry_date       timestamptz NOT NULL,
  max_users         int NOT NULL DEFAULT 1,
  max_branches      int NOT NULL DEFAULT 1,
  modules           jsonb NOT NULL DEFAULT '{}',
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

-- ------------------------------------------------------------
-- Paramètres applicatifs globaux (éditeur)
-- ------------------------------------------------------------
CREATE TABLE app_settings (
  key         text PRIMARY KEY,
  value       jsonb NOT NULL,
  description text,
  updated_at  timestamptz NOT NULL DEFAULT now()
);

-- ------------------------------------------------------------
-- Rôles (système + personnalisés)
-- ------------------------------------------------------------
CREATE TABLE roles (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id  uuid REFERENCES pharmacies(id) ON DELETE CASCADE,
  name         text NOT NULL,
  code         text NOT NULL,
  is_system    boolean NOT NULL DEFAULT false,
  created_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (pharmacy_id, code)
);

-- ------------------------------------------------------------
-- Permissions (catalogue global, code = 'module:action')
-- ------------------------------------------------------------
CREATE TABLE permissions (
  code       text PRIMARY KEY,
  name       text NOT NULL,
  module     text NOT NULL
);

CREATE TABLE role_permissions (
  role_id          uuid NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  permission_code  text NOT NULL REFERENCES permissions(code) ON DELETE CASCADE,
  PRIMARY KEY (role_id, permission_code)
);

-- ------------------------------------------------------------
-- Utilisateurs
-- ------------------------------------------------------------
CREATE TABLE users (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id           uuid REFERENCES pharmacies(id) ON DELETE CASCADE,
  branch_id             uuid REFERENCES branches(id) ON DELETE SET NULL,
  role_id               uuid REFERENCES roles(id) ON DELETE SET NULL,
  first_name            text NOT NULL,
  last_name             text NOT NULL,
  email                 citext UNIQUE,
  phone                 text,
  photo_url             text,
  password_hash         text NOT NULL,
  pin_hash              text,               -- code PIN pour le pointage / caisse
  status                text NOT NULL DEFAULT 'active'
                        CHECK (status IN ('active','inactive','locked')),
  must_change_password  boolean NOT NULL DEFAULT false,
  two_factor_enabled    boolean NOT NULL DEFAULT false,
  two_factor_secret     text,
  failed_attempts       int NOT NULL DEFAULT 0,
  locked_until          timestamptz,
  last_login_at         timestamptz,
  is_super_admin        boolean NOT NULL DEFAULT false,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  revision              bigint NOT NULL DEFAULT 1
);
CREATE INDEX idx_users_pharmacy ON users(pharmacy_id);
CREATE INDEX idx_users_email ON users(email);

-- ------------------------------------------------------------
-- Sessions / jetons de connexion
-- ------------------------------------------------------------
CREATE TABLE user_sessions (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  pharmacy_id         uuid REFERENCES pharmacies(id) ON DELETE CASCADE,
  access_token_hash   text NOT NULL,
  refresh_token_hash  text NOT NULL,
  device_name         text,
  device_type         text,
  ip_address          text,
  user_agent          text,
  created_at          timestamptz NOT NULL DEFAULT now(),
  expires_at          timestamptz NOT NULL,
  revoked_at          timestamptz,
  last_used_at        timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_sessions_user ON user_sessions(user_id);
CREATE INDEX idx_sessions_refresh ON user_sessions(refresh_token_hash);

-- ------------------------------------------------------------
-- Journal d'audit (append-only)
-- ------------------------------------------------------------
CREATE TABLE audit_logs (
  id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  pharmacy_id  uuid REFERENCES pharmacies(id) ON DELETE SET NULL,
  user_id      uuid REFERENCES users(id) ON DELETE SET NULL,
  action       text NOT NULL,
  module       text NOT NULL,
  entity       text,
  entity_id    text,
  old_values   jsonb,
  new_values   jsonb,
  ip_address   text,
  device       text,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_audit_pharmacy ON audit_logs(pharmacy_id, created_at DESC);
CREATE INDEX idx_audit_user ON audit_logs(user_id, created_at DESC);
CREATE INDEX idx_audit_entity ON audit_logs(entity, entity_id);

-- ------------------------------------------------------------
-- Notifications
-- ------------------------------------------------------------
CREATE TABLE notifications (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id  uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  user_id      uuid REFERENCES users(id) ON DELETE CASCADE,
  type         text NOT NULL,   -- license_expiry | low_stock | expired | order | backup | update | security | system
  title        text NOT NULL,
  message      text,
  data         jsonb,
  read_at      timestamptz,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_notifications_user ON notifications(user_id, read_at, created_at DESC);

-- ------------------------------------------------------------
-- RLS tenant
-- ------------------------------------------------------------
SELECT fn_apply_tenant_rls('branches');
SELECT fn_apply_tenant_rls('licenses');
SELECT fn_apply_tenant_rls('users');
SELECT fn_apply_tenant_rls('user_sessions');
SELECT fn_apply_tenant_rls('notifications');
