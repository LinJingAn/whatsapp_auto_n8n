-- =============================================================================
-- Supabase full migration (public schema only)
-- Run AFTER: DROP SCHEMA public CASCADE; CREATE SCHEMA public;
-- Usage: Supabase SQL Editor → paste this entire file → Run
-- =============================================================================

SET client_min_messages = warning;

-- Extensions (public only)
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA public;

-- Enum used by pacientes
CREATE TYPE public.sexo_biologico AS ENUM (
  'masculino', 'feminino', 'Prefiro não informar', 'Masculino', 'Feminino'
);

-- Function for updated_at triggers
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- -----------------------------------------------------------------------------
-- Tables (dependency order: no FKs first)
-- -----------------------------------------------------------------------------

-- 1) profiles
CREATE TABLE public.profiles (
  user_id uuid DEFAULT gen_random_uuid() NOT NULL,
  full_name text,
  email text,
  phone text,
  role text,
  active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  cpf text,
  pagbank_customer_id text,
  is_admin boolean DEFAULT false NOT NULL
);
ALTER TABLE public.profiles ADD CONSTRAINT profiles_pkey PRIMARY KEY (user_id);

-- 2) clinicas
CREATE TABLE public.clinicas (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  nome text NOT NULL,
  cnpj text,
  cidade text,
  estado text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
ALTER TABLE public.clinicas ADD CONSTRAINT clinicas_pkey PRIMARY KEY (id);

-- 3) planos (required by assinaturas FK)
CREATE TABLE public.planos (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  nome text NOT NULL,
  operadora text,
  tipo text,
  registro_ans text,
  codigo_externo text,
  coparticipacao_pct numeric(5,2),
  cobertura jsonb,
  ativo boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
ALTER TABLE public.planos ADD CONSTRAINT planos_pkey PRIMARY KEY (id);

-- 4) empresas (required by assinaturas FK)
CREATE TABLE public.empresas (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  razao_social text NOT NULL,
  nome_fantasia text,
  cnpj text,
  email text,
  telefone text,
  site text,
  endereco jsonb,
  ativa boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT empresas_cnpj_check CHECK (cnpj IS NULL OR cnpj ~ '^\d{14}$')
);
ALTER TABLE public.empresas ADD CONSTRAINT empresas_pkey PRIMARY KEY (id);

-- 5) contatos_agente
CREATE TABLE public.contatos_agente (
  id bigint NOT NULL,
  user_number text NOT NULL,
  user_name text,
  user_profile text,
  agente text DEFAULT 'recepcionista',
  role text,
  status text,
  email text,
  interesse_duvida text,
  created_at timestamptz DEFAULT now()
);
CREATE SEQUENCE public.contatos_agente_id_seq
  START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER SEQUENCE public.contatos_agente_id_seq OWNED BY public.contatos_agente.id;
ALTER TABLE ONLY public.contatos_agente ALTER COLUMN id SET DEFAULT nextval('public.contatos_agente_id_seq'::regclass);
ALTER TABLE public.contatos_agente ADD CONSTRAINT contatos_agente_pkey PRIMARY KEY (id);
ALTER TABLE public.contatos_agente ADD CONSTRAINT contatos_agente_user_number_key UNIQUE (user_number);

-- 6) pagamentos
CREATE TABLE public.pagamentos (
  id bigint NOT NULL,
  payment_id text NOT NULL,
  reference_id text,
  user_number text NOT NULL,
  profile_id uuid,
  amount integer NOT NULL,
  status text DEFAULT 'WAITING',
  tipo text,
  pix_qr_code text,
  pix_qr_code_base64 text,
  expiration_date timestamptz,
  paid_at timestamptz,
  payer_name text,
  payer_tax_id text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
CREATE SEQUENCE public.pagamentos_id_seq
  START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER SEQUENCE public.pagamentos_id_seq OWNED BY public.pagamentos.id;
ALTER TABLE ONLY public.pagamentos ALTER COLUMN id SET DEFAULT nextval('public.pagamentos_id_seq'::regclass);
ALTER TABLE public.pagamentos ADD CONSTRAINT pagamentos_pkey PRIMARY KEY (id);
ALTER TABLE public.pagamentos ADD CONSTRAINT pagamentos_payment_id_key UNIQUE (payment_id);

-- 7) pacientes
CREATE TABLE public.pacientes (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  profile_id uuid NOT NULL,
  data_nascimento date,
  sexo public.sexo_biologico,
  plano_saude text,
  cidade_estado text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  nome text
);
ALTER TABLE public.pacientes ADD CONSTRAINT pacientes_pkey PRIMARY KEY (id);

-- 8) assinaturas
CREATE TABLE public.assinaturas (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  usuario_titular_id uuid NOT NULL,
  plano_id uuid NOT NULL,
  empresa_id uuid,
  tipo_plano text NOT NULL,
  status text DEFAULT 'ativa' NOT NULL,
  valor_mensal numeric(12,2) DEFAULT 0.00,
  valor_coparticipacao numeric(5,2) DEFAULT 0.00,
  limite_membros_sem_taxa integer DEFAULT 1,
  pagbank_customer_id text,
  pagbank_subscription_id text,
  data_inicio timestamptz,
  data_fim timestamptz,
  proxima_cobranca timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  observacoes text,
  quantidade_membros integer DEFAULT 0,
  saldo_credito numeric(10,2) DEFAULT 0.00,
  tipo_plano_pendente varchar(50),
  plano_id_pendente varchar(255),
  data_agendamento_mudanca timestamp without time zone,
  motivo_mudanca_plano text
);
ALTER TABLE public.assinaturas ADD CONSTRAINT assinaturas_pkey PRIMARY KEY (id);

-- 9) assinatura_membros
CREATE TABLE public.assinatura_membros (
  id bigint NOT NULL,
  assinatura_id uuid NOT NULL,
  paciente_id uuid NOT NULL,
  is_titular boolean DEFAULT false,
  status text DEFAULT 'ativo',
  data_entrada date DEFAULT CURRENT_DATE,
  data_saida date
);
CREATE SEQUENCE public.assinatura_membros_id_seq
  START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER SEQUENCE public.assinatura_membros_id_seq OWNED BY public.assinatura_membros.id;
ALTER TABLE ONLY public.assinatura_membros ALTER COLUMN id SET DEFAULT nextval('public.assinatura_membros_id_seq'::regclass);
ALTER TABLE public.assinatura_membros ADD CONSTRAINT assinatura_membros_pkey PRIMARY KEY (id);
CREATE UNIQUE INDEX assinatura_membro_unq ON public.assinatura_membros (assinatura_id, paciente_id);
CREATE UNIQUE INDEX assinatura_um_titular_por_assinatura ON public.assinatura_membros (assinatura_id) WHERE (is_titular IS TRUE);

-- 10) dependentes
CREATE TABLE public.dependentes (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  assinatura_id uuid NOT NULL,
  nome varchar(255) NOT NULL,
  cpf varchar(14) NOT NULL,
  email varchar(255),
  telefone varchar(20),
  data_nascimento date,
  parentesco varchar(50),
  status varchar(10) DEFAULT 'ATIVO' NOT NULL,
  data_inicio timestamp without time zone DEFAULT now() NOT NULL,
  data_atualizacao timestamp without time zone
);
ALTER TABLE public.dependentes ADD CONSTRAINT dependentes_pkey PRIMARY KEY (id);
ALTER TABLE public.dependentes ADD CONSTRAINT dependentes_cpf_key UNIQUE (cpf);

-- -----------------------------------------------------------------------------
-- Indexes (pagamentos)
-- -----------------------------------------------------------------------------
CREATE INDEX idx_pagamentos_payment_id ON public.pagamentos (payment_id);
CREATE INDEX idx_pagamentos_reference_id ON public.pagamentos (reference_id);
CREATE INDEX idx_pagamentos_status ON public.pagamentos (status);
CREATE INDEX idx_pagamentos_user_number ON public.pagamentos (user_number);

-- -----------------------------------------------------------------------------
-- Foreign keys
-- -----------------------------------------------------------------------------
ALTER TABLE ONLY public.pacientes
  ADD CONSTRAINT pacientes_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(user_id) ON DELETE CASCADE;

ALTER TABLE ONLY public.pagamentos
  ADD CONSTRAINT pagamentos_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(user_id);

ALTER TABLE ONLY public.assinaturas
  ADD CONSTRAINT assinaturas_titular_user_id_fkey FOREIGN KEY (usuario_titular_id) REFERENCES public.profiles(user_id) ON DELETE RESTRICT;
ALTER TABLE ONLY public.assinaturas
  ADD CONSTRAINT assinaturas_plano_id_fkey FOREIGN KEY (plano_id) REFERENCES public.planos(id) ON DELETE RESTRICT;
ALTER TABLE ONLY public.assinaturas
  ADD CONSTRAINT assinaturas_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.assinatura_membros
  ADD CONSTRAINT assinatura_membros_assinatura_id_fkey FOREIGN KEY (assinatura_id) REFERENCES public.assinaturas(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.assinatura_membros
  ADD CONSTRAINT assinatura_membros_paciente_id_fkey FOREIGN KEY (paciente_id) REFERENCES public.pacientes(id) ON DELETE RESTRICT;

ALTER TABLE ONLY public.dependentes
  ADD CONSTRAINT dependentes_assinatura_id_fkey FOREIGN KEY (assinatura_id) REFERENCES public.assinaturas(id) ON DELETE CASCADE;

-- -----------------------------------------------------------------------------
-- Triggers (updated_at)
-- -----------------------------------------------------------------------------
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_clinicas_updated_at
  BEFORE UPDATE ON public.clinicas FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_planos_updated_at
  BEFORE UPDATE ON public.planos FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_empresas_updated_at
  BEFORE UPDATE ON public.empresas FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_pagamentos_updated_at
  BEFORE UPDATE ON public.pagamentos FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_pacientes_updated_at
  BEFORE UPDATE ON public.pacientes FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_assinaturas_updated_at
  BEFORE UPDATE ON public.assinaturas FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- -----------------------------------------------------------------------------
-- Permissions (required for Supabase API / n8n)
-- -----------------------------------------------------------------------------
GRANT USAGE ON SCHEMA public TO postgres, anon, authenticated, service_role;

GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO postgres, anon, authenticated, service_role;

-- -----------------------------------------------------------------------------
-- RLS (optional: enable if you use Row Level Security; policies allow all for anon/service_role)
-- -----------------------------------------------------------------------------
ALTER TABLE public.pagamentos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all operations on pagamentos" ON public.pagamentos USING (true) WITH CHECK (true);
CREATE POLICY "Allow all operations on profiles" ON public.profiles USING (true) WITH CHECK (true);

-- -----------------------------------------------------------------------------
-- Seed: test profile + patient (replace phone with your WhatsApp number for testing)
-- -----------------------------------------------------------------------------
INSERT INTO public.profiles (user_id, phone)
VALUES ('a0000000-0000-0000-0000-000000000001'::uuid, '85295401200')
ON CONFLICT (user_id) DO UPDATE SET phone = EXCLUDED.phone;

INSERT INTO public.pacientes (id, profile_id)
VALUES ('b0000000-0000-0000-0000-000000000001'::uuid, 'a0000000-0000-0000-0000-000000000001'::uuid)
ON CONFLICT (id) DO NOTHING;
