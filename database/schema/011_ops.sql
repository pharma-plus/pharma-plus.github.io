-- ============================================================
-- PHARMA MAROC GOLD ENTERPRISE V2.0
-- 011_ops.sql — Sauvegardes, synchronisation, support, site Web
-- ============================================================

-- ------------------------------------------------------------
-- Sauvegardes (chiffrées)
-- ------------------------------------------------------------
CREATE TABLE backups (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id  uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  type         text NOT NULL CHECK (type IN ('manual','auto')),
  scope        text NOT NULL DEFAULT 'full' CHECK (scope IN ('full','schema','data')),
  file_url     text NOT NULL,
  checksum     text NOT NULL,               -- SHA-256 avant chiffrement
  encrypted    boolean NOT NULL DEFAULT true,
  size_bytes   bigint NOT NULL DEFAULT 0,
  status       text NOT NULL DEFAULT 'running'
               CHECK (status IN ('running','completed','failed','restoring','verified')),
  error        text,
  created_at   timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  restored_at  timestamptz
);
CREATE INDEX idx_backups_pharmacy ON backups(pharmacy_id, created_at DESC);

-- ------------------------------------------------------------
-- Synchronisation offline (journal des opérations serveur)
-- ------------------------------------------------------------
CREATE TABLE sync_operations (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id  uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  device_id    text NOT NULL,
  entity       text NOT NULL,
  last_revision bigint NOT NULL DEFAULT 0,
  status       text NOT NULL DEFAULT 'success' CHECK (status IN ('success','error')),
  error        text,
  started_at   timestamptz NOT NULL DEFAULT now(),
  finished_at  timestamptz,
  UNIQUE (device_id, entity)
);
CREATE INDEX idx_sync_pharmacy ON sync_operations(pharmacy_id, started_at DESC);

-- ------------------------------------------------------------
-- Mises à jour applicatives
-- ------------------------------------------------------------
CREATE TABLE update_releases (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  platform          text NOT NULL CHECK (platform IN ('android','ios','windows','macos','linux','web','all')),
  version           text NOT NULL,
  channel           text NOT NULL DEFAULT 'stable' CHECK (channel IN ('stable','beta','alpha')),
  notes             text,
  file_url          text,
  checksum          text,
  min_version       text,
  target_pharmacies jsonb,       -- null = toutes ; sinon liste d'UUID
  published_at      timestamptz NOT NULL DEFAULT now(),
  is_active         boolean NOT NULL DEFAULT true,
  UNIQUE (platform, version)
);

-- ------------------------------------------------------------
-- Support (tickets & chat)
-- ------------------------------------------------------------
CREATE TABLE support_tickets (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id  uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  user_id      uuid REFERENCES users(id) ON DELETE SET NULL,
  subject      text NOT NULL,
  status       text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','resolved','closed')),
  priority     text NOT NULL DEFAULT 'normal' CHECK (priority IN ('low','normal','high','critical')),
  created_at   timestamptz NOT NULL DEFAULT now(),
  resolved_at  timestamptz
);

CREATE TABLE support_messages (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id  uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  ticket_id    uuid NOT NULL REFERENCES support_tickets(id) ON DELETE CASCADE,
  author_type  text NOT NULL CHECK (author_type IN ('pharmacy','support','system')),
  author_id    uuid,
  message      text NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now()
);

-- ------------------------------------------------------------
-- Annonces éditeur (portail super admin)
-- ------------------------------------------------------------
CREATE TABLE announcements (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id  uuid REFERENCES pharmacies(id) ON DELETE CASCADE,  -- null = global
  title        text NOT NULL,
  message      text,
  is_active    boolean NOT NULL DEFAULT true,
  created_at   timestamptz NOT NULL DEFAULT now()
);

-- ------------------------------------------------------------
-- Site Web pharmacie (contenu personnalisable)
-- ------------------------------------------------------------
CREATE TABLE website_settings (
  pharmacy_id  uuid PRIMARY KEY REFERENCES pharmacies(id) ON DELETE CASCADE,
  hero_title   text,
  hero_subtitle text,
  about        text,
  services     jsonb DEFAULT '[]',
  photos       jsonb DEFAULT '[]',
  video_url    text,
  social       jsonb DEFAULT '{}',
  opening_hours jsonb DEFAULT '[]',
  custom_css   text,
  updated_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE blog_categories (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id  uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  name         text NOT NULL,
  slug         text NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (pharmacy_id, slug)
);

CREATE TABLE blog_posts (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id  uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  category_id  uuid REFERENCES blog_categories(id) ON DELETE SET NULL,
  title        text NOT NULL,
  slug         text NOT NULL,
  excerpt      text,
  content      text NOT NULL,
  image_url    text,
  is_published boolean NOT NULL DEFAULT false,
  seo          jsonb DEFAULT '{}',
  published_at timestamptz,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (pharmacy_id, slug)
);

SELECT fn_apply_tenant_rls('backups');
SELECT fn_apply_tenant_rls('sync_operations');
SELECT fn_apply_tenant_rls('support_tickets');
SELECT fn_apply_tenant_rls('support_messages');
SELECT fn_apply_tenant_rls('announcements');
SELECT fn_apply_tenant_rls('website_settings');
SELECT fn_apply_tenant_rls('blog_categories');
SELECT fn_apply_tenant_rls('blog_posts');
