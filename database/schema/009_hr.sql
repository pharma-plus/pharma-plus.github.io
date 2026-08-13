-- ============================================================
-- PHARMA MAROC GOLD ENTERPRISE V2.0
-- 009_hr.sql — Employés (RH), pointage, congés, plannings
-- ============================================================

CREATE TABLE employees (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id   uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  branch_id     uuid REFERENCES branches(id) ON DELETE SET NULL,
  user_id       uuid REFERENCES users(id) ON DELETE SET NULL,
  photo_url     text,
  first_name    text NOT NULL,
  last_name     text NOT NULL,
  phone         text,
  email         text,
  cin           text,
  position      text NOT NULL,
  salary        numeric(14,2) NOT NULL DEFAULT 0,
  hire_date     date,
  contract_type text CHECK (contract_type IN ('cdi','cdd','stage','interim')),
  status        text NOT NULL DEFAULT 'active' CHECK (status IN ('active','inactive','on_leave')),
  notes         text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_employees_pharmacy ON employees(pharmacy_id);
CREATE INDEX idx_employees_status ON employees(pharmacy_id, status);

-- Documents RH (contrats, CV, PDF, images)
CREATE TABLE employee_documents (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id  uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  employee_id  uuid NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  title        text NOT NULL,
  doc_type     text NOT NULL,      -- contract | cv | id | certificate | other
  file_url     text NOT NULL,
  uploaded_at  timestamptz NOT NULL DEFAULT now()
);

-- Pointage
CREATE TABLE attendance (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id      uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  branch_id        uuid REFERENCES branches(id) ON DELETE SET NULL,
  employee_id      uuid NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  date             date NOT NULL DEFAULT CURRENT_DATE,
  clock_in         timestamptz,
  clock_out        timestamptz,
  break_start      timestamptz,
  break_end        timestamptz,
  method           text NOT NULL DEFAULT 'pin' CHECK (method IN ('pin','qr','biometric','face','manual')),
  status           text NOT NULL DEFAULT 'present'
                   CHECK (status IN ('present','late','absent','half_day','leave')),
  late_minutes     int NOT NULL DEFAULT 0,
  overtime_minutes int NOT NULL DEFAULT 0,
  hours_worked     numeric(5,2) NOT NULL DEFAULT 0,
  notes            text,
  UNIQUE (employee_id, date)
);
CREATE INDEX idx_attendance_employee ON attendance(employee_id, date DESC);
CREATE INDEX idx_attendance_date ON attendance(pharmacy_id, date);

-- Congés / absences
CREATE TABLE leaves (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id  uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  employee_id  uuid NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  leave_type   text NOT NULL CHECK (leave_type IN ('annual','sick','maternity','unpaid','other')),
  start_date   date NOT NULL,
  end_date     date NOT NULL,
  days         int NOT NULL DEFAULT 1,
  status       text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected','cancelled')),
  reason       text,
  approved_by  uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at   timestamptz NOT NULL DEFAULT now(),
  CHECK (end_date >= start_date)
);
CREATE INDEX idx_leaves_employee ON leaves(employee_id, start_date);

-- Planning hebdomadaire
CREATE TABLE schedules (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id  uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  employee_id  uuid NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  day_of_week  int NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
  start_time   time NOT NULL,
  end_time     time NOT NULL,
  UNIQUE (employee_id, day_of_week)
);

-- Primes & bonus
CREATE TABLE bonuses (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id  uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  employee_id  uuid NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  amount       numeric(14,2) NOT NULL CHECK (amount > 0),
  bonus_date   date NOT NULL DEFAULT CURRENT_DATE,
  reason       text,
  created_by   uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at   timestamptz NOT NULL DEFAULT now()
);

-- Évaluations de performance
CREATE TABLE evaluations (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id  uuid NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  employee_id  uuid NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  eval_date    date NOT NULL DEFAULT CURRENT_DATE,
  score        numeric(3,2) CHECK (score BETWEEN 0 AND 5),
  comments     text,
  by_user      uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at   timestamptz NOT NULL DEFAULT now()
);

SELECT fn_apply_tenant_rls('employees');
SELECT fn_apply_tenant_rls('employee_documents');
SELECT fn_apply_tenant_rls('attendance');
SELECT fn_apply_tenant_rls('leaves');
SELECT fn_apply_tenant_rls('schedules');
SELECT fn_apply_tenant_rls('bonuses');
SELECT fn_apply_tenant_rls('evaluations');
