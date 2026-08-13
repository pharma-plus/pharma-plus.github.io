-- ============================================================
-- PHARMA MAROC GOLD ENTERPRISE V2.0
-- 008_prescriptions.sql — Ordonnances
-- ============================================================

CREATE TABLE prescriptions (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id   uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  customer_id   uuid REFERENCES customers(id) ON DELETE SET NULL,
  patient_name  text,
  doctor_name   text,
  source        text NOT NULL DEFAULT 'manual' CHECK (source IN ('camera','pdf','manual','client_web')),
  file_url      text,
  status        text NOT NULL DEFAULT 'received'
                CHECK (status IN ('received','processing','filled','rejected','archived')),
  notes         text,
  filled_at     timestamptz,
  created_by    uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_prescriptions_customer ON prescriptions(customer_id, created_at DESC);
CREATE INDEX idx_prescriptions_status ON prescriptions(pharmacy_id, status);

CREATE TABLE prescription_items (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id    uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  prescription_id uuid NOT NULL REFERENCES prescriptions(id) ON DELETE CASCADE,
  medication_id  uuid REFERENCES medications(id) ON DELETE SET NULL,
  dosage         text,
  frequency      text,
  duration       text,
  quantity       numeric(12,3) NOT NULL DEFAULT 0,
  is_dispensed   boolean NOT NULL DEFAULT false,
  notes          text
);
CREATE INDEX idx_prescription_items_pres ON prescription_items(prescription_id);

-- FK différée : vente liée à une ordonnance
ALTER TABLE sales
  ADD CONSTRAINT fk_sale_prescription FOREIGN KEY (prescription_id)
  REFERENCES prescriptions(id) ON DELETE SET NULL;

SELECT fn_apply_tenant_rls('prescriptions');
SELECT fn_apply_tenant_rls('prescription_items');
