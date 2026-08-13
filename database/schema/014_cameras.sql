-- ============================================================
-- PHARMA MAROC GOLD ENTERPRISE V2.0
-- 014_cameras.sql — Vidéosurveillance / caméras (par pharmacie)
-- ============================================================

-- ------------------------------------------------------------
-- Caméras
-- ------------------------------------------------------------
CREATE TABLE cameras (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id  uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  branch_id    uuid REFERENCES branches(id) ON DELETE SET NULL,
  name         text NOT NULL,
  location     text,                       -- emplacement (Comptoir, Réserve, ...)
  stream_url   text,                       -- flux RTSP/HLS
  snapshot_url text,
  position_x   numeric(10,2) NOT NULL DEFAULT 0,   -- position sur le plan
  position_y   numeric(10,2) NOT NULL DEFAULT 0,
  status       text NOT NULL DEFAULT 'offline'
               CHECK (status IN ('online','offline','recording','error')),
  is_enabled   boolean NOT NULL DEFAULT true,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_cameras_pharmacy ON cameras(pharmacy_id, branch_id);

-- ------------------------------------------------------------
-- Enregistrements
-- ------------------------------------------------------------
CREATE TABLE camera_recordings (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id  uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  camera_id    uuid NOT NULL REFERENCES cameras(id) ON DELETE CASCADE,
  started_at   timestamptz NOT NULL DEFAULT now(),
  ended_at     timestamptz,
  file_url     text,
  size_bytes   bigint NOT NULL DEFAULT 0,
  status       text NOT NULL DEFAULT 'recording'
               CHECK (status IN ('recording','completed','failed'))
);
CREATE INDEX idx_camera_recordings_camera ON camera_recordings(camera_id, started_at DESC);

SELECT fn_apply_tenant_rls('cameras');
SELECT fn_apply_tenant_rls('camera_recordings');

-- ============================================================
-- Parapharmacie : extension du catalogue
-- ============================================================
ALTER TABLE medications ADD COLUMN IF NOT EXISTS is_parapharmacie boolean NOT NULL DEFAULT false;
CREATE INDEX IF NOT EXISTS idx_medications_para ON medications(pharmacy_id, is_parapharmacie)
  WHERE is_parapharmacie = true;
