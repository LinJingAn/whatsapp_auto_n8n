-- HealthWizard / n8n – Supabase schema + seed for “current user = not new” (skip payment)
-- Run this in Supabase: SQL Editor → New query → paste → Run

-- 1) contatos_agente (GET_USER, CREATE_USER, IF_USER, Switch8, OFF_AGENT, ON_AGENT)
CREATE TABLE IF NOT EXISTS contatos_agente (
  id BIGSERIAL PRIMARY KEY,
  user_number TEXT NOT NULL UNIQUE,
  user_name TEXT,
  user_profile TEXT,
  agente TEXT DEFAULT 'recepcionista',
  role TEXT,
  status TEXT,
  email TEXT,
  interesse_duvida TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2) pagamentos (Create Payment Charge → Store Payment in Database, Update Payment Status1, Check Payment Confirmed1)
CREATE TABLE IF NOT EXISTS pagamentos (
  id BIGSERIAL PRIMARY KEY,
  payment_id TEXT,
  payment_status TEXT DEFAULT 'WAITING',
  payment_link TEXT,
  pix_qr_code TEXT,
  user_number TEXT,
  amount INTEGER,
  amount_formatted TEXT,
  profile_id TEXT,
  reference_id TEXT,
  expiration_date TIMESTAMPTZ,
  status TEXT DEFAULT 'WAITING',
  paid_at TIMESTAMPTZ,
  payer_name TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3) profiles (Check Patient Status1: lookup by phone → user_id; used for patient_type)
CREATE TABLE IF NOT EXISTS profiles (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  phone TEXT,
  email TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- If profiles already exists (e.g. from Supabase Auth), add columns the workflow needs:
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS user_id UUID UNIQUE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS phone TEXT;

-- 4) pacientes (Check Paciente by Profile1: lookup by profile_id; if row exists → patient_type = 'patient' → skip payment)
CREATE TABLE IF NOT EXISTS pacientes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  nome TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- If pacientes already exists with different columns, add the ones the workflow needs:
ALTER TABLE pacientes ADD COLUMN IF NOT EXISTS profile_id UUID;
ALTER TABLE pacientes ADD COLUMN IF NOT EXISTS nome TEXT;

-- 5) clinicas (Identify Partner Clinic: lookup by nome)
CREATE TABLE IF NOT EXISTS clinicas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nome TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ----- SEED: current user = existing patient (skip payment registration) -----
-- Replace '85295401200' with your test WhatsApp number (no + or spaces).
-- This makes Check Patient Status1 and Check Paciente by Profile1 find a row so patient_type = 'patient' and payment is skipped.

INSERT INTO profiles (user_id, phone)
VALUES (
  'a0000000-0000-0000-0000-000000000001'::uuid,
  '85295401200'
)
ON CONFLICT (user_id) DO UPDATE SET phone = EXCLUDED.phone;

-- Only insert columns that exist (profile_id is required for the workflow lookup)
INSERT INTO pacientes (id, profile_id)
VALUES (
  'b0000000-0000-0000-0000-000000000001'::uuid,
  'a0000000-0000-0000-0000-000000000001'::uuid
)
ON CONFLICT (id) DO NOTHING;

-- Optional: RLS (enable if you use Row Level Security)
-- ALTER TABLE contatos_agente ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE pagamentos ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Service role full access contatos_agente" ON contatos_agente FOR ALL USING (true);
-- CREATE POLICY "Service role full access pagamentos" ON pagamentos FOR ALL USING (true);
