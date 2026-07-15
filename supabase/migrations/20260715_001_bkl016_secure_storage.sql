-- BKL-016 — fundacao segura para dados operacionais e sensiveis.
-- Somente estrutura: nao contem credenciais, chaves ou dados reais.
-- Dados completos devem chegar cifrados por backend confiavel com KMS/cofre externo.

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

create schema if not exists app_private;
create schema if not exists audit;

revoke all on schema app_private from public;
revoke all on schema audit from public;
revoke all on schema app_private from anon, authenticated;
revoke all on schema audit from anon, authenticated;

do $$ begin
  create type public.credit_product as enum ('FGTS', 'CLT');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.app_role as enum ('admin', 'operations', 'support', 'auditor');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type audit.change_origin as enum ('n8n', 'appsmith', 'gateway', 'human', 'system');
exception when duplicate_object then null;
end $$;

-- Perfis sao vinculados ao Supabase Auth. O primeiro admin deve ser promovido
-- manualmente por operador autorizado no SQL Editor, nunca pelo navegador.
create table if not exists public.user_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role public.app_role not null,
  display_name text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.user_profiles is
  'Papeis internos vinculados ao Auth; nao armazena senha, token ou segredo.';

create table if not exists public.clients (
  id uuid primary key default extensions.gen_random_uuid(),
  display_name text not null,
  phone_masked text,
  cpf_masked text,
  lead_source text,
  journey_state text not null default 'NEW',
  consultation_consent_at timestamptz,
  consultation_consent_source text,
  retention_until timestamptz,
  anonymized_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint clients_phone_masked_ck check (
    phone_masked is null or (
      phone_masked ~ '^[+]?[0-9* ()-]{6,24}$'
      and position('*' in phone_masked) > 0
      and regexp_replace(phone_masked, '[^0-9]', '', 'g') !~ '^[0-9]{10,13}$'
    )
  ),
  constraint clients_cpf_masked_ck check (
    cpf_masked is null or (
      cpf_masked ~ '^[0-9*.-]{8,18}$'
      and position('*' in cpf_masked) > 0
      and cpf_masked !~ '[0-9]{11}'
      and regexp_replace(cpf_masked, '[^0-9]', '', 'g') !~ '^[0-9]{11}$'
    )
  )
);

comment on table public.clients is
  'Cadastro operacional. CPF e telefone completos nao pertencem a esta tabela.';

create table if not exists public.technical_operations (
  operation_id uuid primary key,
  correlation_id uuid not null default extensions.gen_random_uuid(),
  client_id uuid references public.clients(id) on delete restrict,
  product public.credit_product not null,
  action text not null check (action in (
    'CONSULTAR', 'CRIAR_PROPOSTA', 'CONSULTAR_STATUS', 'REENVIAR_LINK'
  )),
  session_alias text not null,
  random_id_ref text,
  state text not null default 'RECEIVED' check (state in (
    'RECEIVED', 'LOCK_ACQUIRED', 'COMMAND_PREPARED', 'COMMAND_SENT',
    'WAITING_RESPONSE', 'RESPONSE_RECEIVED', 'NORMALIZED', 'COMPLETED',
    'RETRY_PENDING', 'HUMAN_REVIEW', 'FAILED_FINAL'
  )),
  attempt_count integer not null default 0 check (attempt_count >= 0),
  lease_expires_at timestamptz,
  heartbeat_at timestamptz,
  current_step text,
  outcome_code text,
  error_code text,
  protected_log_ref uuid,
  gateway_version text,
  started_at timestamptz,
  finished_at timestamptz,
  retention_until timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint technical_operations_session_alias_ck check (
    length(btrim(session_alias)) between 1 and 80
  )
);

comment on column public.technical_operations.session_alias is
  'Alias operacional; nunca armazenar StringSession MTProto.';
comment on column public.technical_operations.random_id_ref is
  'Identificador tecnico nao secreto; nao e sessao nem token.';

create unique index if not exists technical_operations_correlation_id_idx
  on public.technical_operations(correlation_id);
create index if not exists technical_operations_queue_idx
  on public.technical_operations(session_alias, state, created_at);

create table if not exists public.consultations (
  id uuid primary key default extensions.gen_random_uuid(),
  client_id uuid not null references public.clients(id) on delete restrict,
  product public.credit_product not null,
  operation_id uuid not null unique
    references public.technical_operations(operation_id) on delete restrict,
  status_raw text,
  status_normalized text not null default 'RECEIVED',
  pending_action text,
  pending_reason_masked text,
  response_code text,
  session_alias text not null,
  protected_payload_ref uuid,
  requested_at timestamptz not null default now(),
  completed_at timestamptz,
  last_checked_at timestamptz,
  retention_until timestamptz,
  anonymized_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint consultations_pending_action_ck check (
    pending_action is null or pending_action ~ '^[A-Z0-9_:-]{1,80}$'
  )
);

create index if not exists consultations_client_product_idx
  on public.consultations(client_id, product, created_at desc);

create table if not exists public.offers (
  id uuid primary key default extensions.gen_random_uuid(),
  consultation_id uuid not null references public.consultations(id) on delete restrict,
  client_id uuid not null references public.clients(id) on delete restrict,
  product public.credit_product not null,
  operation_id uuid not null
    references public.technical_operations(operation_id) on delete restrict,
  lender_code text not null,
  lender_name text not null,
  plan_code text,
  term_count integer check (term_count is null or term_count > 0),
  installment_amount numeric(14,2) check (installment_amount is null or installment_amount >= 0),
  released_amount numeric(14,2) check (released_amount is null or released_amount >= 0),
  interest_rate numeric(10,6) check (interest_rate is null or interest_rate >= 0),
  cet_rate numeric(10,6) check (cet_rate is null or cet_rate >= 0),
  insurance_included boolean,
  valid_until timestamptz,
  snapshot_hash text not null,
  selected_at timestamptz,
  accepted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint offers_id_client_product_uk unique (id, client_id, product),
  constraint offers_snapshot_hash_ck check (snapshot_hash ~ '^[a-f0-9]{64}$')
);

create index if not exists offers_consultation_idx
  on public.offers(consultation_id, created_at desc);

-- Impede misturar produto/cliente entre a consulta e a oferta.
create or replace function public.enforce_offer_consultation_consistency()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_client_id uuid;
  v_product public.credit_product;
  v_operation_id uuid;
begin
  select c.client_id, c.product, c.operation_id
    into v_client_id, v_product, v_operation_id
  from public.consultations c
  where c.id = new.consultation_id;

  if v_client_id is distinct from new.client_id
     or v_product is distinct from new.product
     or v_operation_id is distinct from new.operation_id then
    raise exception 'Oferta deve manter cliente, produto e operacao da consulta';
  end if;
  return new;
end;
$$;

drop trigger if exists offers_consistency on public.offers;
create trigger offers_consistency
before insert or update on public.offers
for each row execute function public.enforce_offer_consultation_consistency();

revoke all on function public.enforce_offer_consultation_consistency() from public;

create or replace function public.protect_offer_snapshot()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (to_jsonb(new) - array['selected_at', 'accepted_at', 'updated_at'])
     is distinct from
     (to_jsonb(old) - array['selected_at', 'accepted_at', 'updated_at']) then
    raise exception 'Snapshot de oferta e imutavel; crie uma nova oferta';
  end if;
  return new;
end;
$$;

drop trigger if exists offers_protect_snapshot on public.offers;
create trigger offers_protect_snapshot
before update on public.offers
for each row execute function public.protect_offer_snapshot();

revoke all on function public.protect_offer_snapshot() from public;

create table if not exists public.proposals (
  id uuid primary key default extensions.gen_random_uuid(),
  client_id uuid not null references public.clients(id) on delete restrict,
  offer_id uuid not null,
  product public.credit_product not null,
  operation_id uuid not null unique
    references public.technical_operations(operation_id) on delete restrict,
  protocol_masked text,
  status_raw text,
  status_normalized text not null default 'CREATED',
  pending_action text,
  pending_reason_masked text,
  signing_link_ref uuid,
  final_authorization_evidence_payload_ref uuid not null,
  final_authorization_evidence_type text not null default 'FINAL_AUTHORIZATION_EVIDENCE',
  authorized_at timestamptz not null,
  created_externally_at timestamptz,
  last_checked_at timestamptz,
  signed_at timestamptz,
  approved_at timestamptz,
  paid_at timestamptz,
  retention_until timestamptz,
  anonymized_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint proposals_offer_client_product_fk
    foreign key (offer_id, client_id, product)
    references public.offers(id, client_id, product) on delete restrict,
  constraint proposals_pending_action_ck check (
    pending_action is null or pending_action ~ '^[A-Z0-9_:-]{1,80}$'
  ),
  constraint proposals_final_authorization_evidence_type_ck check (
    final_authorization_evidence_type = 'FINAL_AUTHORIZATION_EVIDENCE'
  )
);

create index if not exists proposals_client_product_idx
  on public.proposals(client_id, product, created_at desc);

create table if not exists public.interactions (
  id uuid primary key default extensions.gen_random_uuid(),
  client_id uuid not null references public.clients(id) on delete restrict,
  proposal_id uuid references public.proposals(id) on delete restrict,
  product public.credit_product,
  occurred_at timestamptz not null default now(),
  channel text not null,
  direction text not null check (direction in ('INBOUND', 'OUTBOUND', 'INTERNAL')),
  external_message_ref text,
  event_type text not null,
  event_summary_masked text,
  previous_state text,
  next_state text,
  actor_type text not null default 'system',
  automation_ref text,
  retention_until timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint interactions_event_type_ck check (
    event_type ~ '^[A-Z0-9_:-]{1,80}$'
  )
);

create index if not exists interactions_client_timeline_idx
  on public.interactions(client_id, occurred_at desc);

create table if not exists public.pending_items (
  id uuid primary key default extensions.gen_random_uuid(),
  client_id uuid not null references public.clients(id) on delete restrict,
  proposal_id uuid references public.proposals(id) on delete restrict,
  product public.credit_product,
  pending_type text not null,
  priority text not null default 'NORMAL' check (priority in ('LOW', 'NORMAL', 'HIGH', 'URGENT')),
  pending_action text not null,
  pending_reason_masked text,
  status text not null default 'OPEN' check (status in ('OPEN', 'IN_PROGRESS', 'RESOLVED', 'CANCELLED')),
  assigned_user_id uuid references auth.users(id) on delete set null,
  due_at timestamptz,
  resolution_masked text,
  resolved_at timestamptz,
  retention_until timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint pending_items_pending_action_ck check (
    pending_action ~ '^[A-Z0-9_:-]{1,80}$'
  )
);

create index if not exists pending_items_queue_idx
  on public.pending_items(status, priority, due_at);

-- Conteudo privado: apenas ciphertext, tokens opacos e referencias externas.
create table if not exists app_private.client_sensitive_data (
  client_id uuid primary key references public.clients(id) on delete restrict,
  cpf_ciphertext bytea,
  cpf_lookup_token text unique,
  cpf_last4 char(4) check (cpf_last4 is null or cpf_last4 ~ '^[0-9]{4}$'),
  rg_ciphertext bytea,
  document_metadata_ciphertext bytea,
  address_ciphertext bytea,
  bank_data_ciphertext bytea,
  encryption_key_ref text not null,
  encryption_version text not null,
  retention_until timestamptz,
  anonymized_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint client_sensitive_has_content_ck check (
    num_nonnulls(cpf_ciphertext, rg_ciphertext, document_metadata_ciphertext,
      address_ciphertext, bank_data_ciphertext) > 0
  )
);

comment on table app_private.client_sensitive_data is
  'Ciphertext criado por biblioteca/KMS aprovado; a chave nunca fica no banco.';

create table if not exists app_private.proposal_sensitive_data (
  proposal_id uuid primary key references public.proposals(id) on delete restrict,
  signing_url_ciphertext bytea,
  address_ciphertext bytea,
  bank_data_ciphertext bytea,
  document_payload_ciphertext bytea,
  encryption_key_ref text not null,
  encryption_version text not null,
  retention_until timestamptz,
  anonymized_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint proposal_sensitive_has_content_ck check (
    num_nonnulls(signing_url_ciphertext, address_ciphertext,
      bank_data_ciphertext, document_payload_ciphertext) > 0
  )
);

create table if not exists app_private.protected_payloads (
  id uuid primary key default extensions.gen_random_uuid(),
  client_id uuid references public.clients(id) on delete restrict,
  proposal_id uuid references public.proposals(id) on delete restrict,
  operation_id uuid references public.technical_operations(operation_id) on delete restrict,
  payload_type text not null,
  ciphertext bytea not null,
  encryption_key_ref text not null,
  encryption_version text not null,
  ciphertext_sha256 text check (
    ciphertext_sha256 is null or ciphertext_sha256 ~ '^[a-f0-9]{64}$'
  ),
  retention_until timestamptz not null,
  anonymized_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint protected_payloads_evidence_ownership_uk unique (
    id, client_id, operation_id, payload_type
  ),
  constraint protected_payloads_final_authorization_owner_ck check (
    payload_type <> 'FINAL_AUTHORIZATION_EVIDENCE'
    or (client_id is not null and operation_id is not null)
  ),
  constraint protected_payload_owner_ck check (
    num_nonnulls(client_id, proposal_id, operation_id) >= 1
  )
);

create table if not exists app_private.protected_file_refs (
  id uuid primary key default extensions.gen_random_uuid(),
  client_id uuid references public.clients(id) on delete restrict,
  proposal_id uuid references public.proposals(id) on delete restrict,
  operation_id uuid references public.technical_operations(operation_id) on delete restrict,
  bucket_name text not null check (bucket_name in (
    'cbn-documents-private', 'cbn-raw-payloads-private',
    'cbn-evidence-private', 'cbn-temporary-private'
  )),
  object_key text not null unique,
  media_type text,
  encryption_key_ref text,
  retention_until timestamptz not null,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint protected_file_owner_ck check (
    num_nonnulls(client_id, proposal_id, operation_id) >= 1
  ),
  constraint protected_file_key_no_pii_ck check (
    object_key ~ '^[a-f0-9/-]{16,200}$'
    and object_key !~ '[0-9]{11}'
  )
);

comment on column app_private.protected_file_refs.object_key is
  'Somente UUID/hash; nunca CPF, RG, telefone, nome ou URL assinada.';

alter table public.consultations
  drop constraint if exists consultations_protected_payload_ref_fk;
alter table public.consultations
  add constraint consultations_protected_payload_ref_fk
  foreign key (protected_payload_ref)
  references app_private.protected_payloads(id) on delete set null;

alter table public.technical_operations
  drop constraint if exists technical_operations_protected_log_ref_fk;
alter table public.technical_operations
  add constraint technical_operations_protected_log_ref_fk
  foreign key (protected_log_ref)
  references app_private.protected_payloads(id) on delete set null;

alter table public.proposals
  drop constraint if exists proposals_signing_link_ref_fk;
alter table public.proposals
  add constraint proposals_signing_link_ref_fk
  foreign key (signing_link_ref)
  references app_private.protected_payloads(id) on delete set null;

alter table public.proposals
  drop constraint if exists proposals_final_authorization_evidence_payload_ref_fk;
alter table public.proposals
  add constraint proposals_final_authorization_evidence_payload_ref_fk
  foreign key (
    final_authorization_evidence_payload_ref,
    client_id,
    operation_id,
    final_authorization_evidence_type
  )
  references app_private.protected_payloads(
    id, client_id, operation_id, payload_type
  ) on delete restrict;

comment on column public.proposals.final_authorization_evidence_payload_ref is
  'Evidencia protegida obrigatoria da autorizacao final, do mesmo cliente e operacao; nunca texto, link ou dado bruto.';

-- Trilha minima append-only. Metadata aceita somente codigos/estados nao sensiveis.
create table if not exists audit.events (
  id bigint generated always as identity primary key,
  occurred_at timestamptz not null default now(),
  actor_id uuid,
  actor_role public.app_role,
  origin audit.change_origin not null,
  event_type text not null,
  entity_type text not null,
  entity_id text,
  operation_id uuid,
  allowed boolean not null default true,
  purpose_code text,
  metadata jsonb not null default '{}'::jsonb,
  constraint audit_metadata_object_ck check (jsonb_typeof(metadata) = 'object')
);

comment on table audit.events is
  'Append-only; nunca incluir CPF, RG, endereco, conta, link completo, token ou payload bruto.';

create index if not exists audit_events_entity_idx
  on audit.events(entity_type, entity_id, occurred_at desc);
create index if not exists audit_events_operation_idx
  on audit.events(operation_id, occurred_at desc);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

revoke all on function public.set_updated_at() from public;

do $$
declare
  table_ref regclass;
begin
  foreach table_ref in array array[
    'public.user_profiles'::regclass,
    'public.clients'::regclass,
    'public.technical_operations'::regclass,
    'public.consultations'::regclass,
    'public.offers'::regclass,
    'public.proposals'::regclass,
    'public.interactions'::regclass,
    'public.pending_items'::regclass,
    'app_private.client_sensitive_data'::regclass,
    'app_private.proposal_sensitive_data'::regclass,
    'app_private.protected_payloads'::regclass,
    'app_private.protected_file_refs'::regclass
  ] loop
    execute format('drop trigger if exists set_updated_at on %s', table_ref);
    execute format(
      'create trigger set_updated_at before update on %s for each row execute function public.set_updated_at()',
      table_ref
    );
  end loop;
end $$;

create or replace function app_private.current_user_role()
returns public.app_role
language sql
stable
security definer
set search_path = ''
as $$
  select up.role
  from public.user_profiles up
  where up.user_id = auth.uid() and up.active
  limit 1
$$;

create or replace function app_private.has_app_role(allowed_roles public.app_role[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(app_private.current_user_role() = any(allowed_roles), false)
$$;

revoke all on function app_private.current_user_role() from public;
revoke all on function app_private.has_app_role(public.app_role[]) from public;
revoke all on function app_private.current_user_role() from anon;
revoke all on function app_private.has_app_role(public.app_role[]) from anon;
grant execute on function app_private.current_user_role() to authenticated;
grant execute on function app_private.has_app_role(public.app_role[]) to authenticated;
grant usage on schema app_private to authenticated;

-- RLS ativa inclusive nas tabelas privadas. Ausencia de policy privada = negacao.
alter table public.user_profiles enable row level security;
alter table public.clients enable row level security;
alter table public.technical_operations enable row level security;
alter table public.consultations enable row level security;
alter table public.offers enable row level security;
alter table public.proposals enable row level security;
alter table public.interactions enable row level security;
alter table public.pending_items enable row level security;
alter table app_private.client_sensitive_data enable row level security;
alter table app_private.proposal_sensitive_data enable row level security;
alter table app_private.protected_payloads enable row level security;
alter table app_private.protected_file_refs enable row level security;
alter table audit.events enable row level security;

-- Perfil: cada usuario ve o proprio; somente admin ativo administra perfis.
drop policy if exists user_profiles_self_read on public.user_profiles;
create policy user_profiles_self_read on public.user_profiles
for select to authenticated
using (user_id = auth.uid());

drop policy if exists user_profiles_admin_all on public.user_profiles;
create policy user_profiles_admin_all on public.user_profiles
for all to authenticated
using (app_private.has_app_role(array['admin'::public.app_role]))
with check (app_private.has_app_role(array['admin'::public.app_role]));

-- Leitura operacional explicita por necessidade.
drop policy if exists clients_read on public.clients;
create policy clients_read on public.clients for select to authenticated using (
  app_private.has_app_role(array[
    'admin'::public.app_role, 'operations'::public.app_role,
    'support'::public.app_role, 'auditor'::public.app_role
  ])
);

drop policy if exists consultations_read on public.consultations;
create policy consultations_read on public.consultations for select to authenticated using (
  app_private.has_app_role(array[
    'admin'::public.app_role, 'operations'::public.app_role,
    'support'::public.app_role, 'auditor'::public.app_role
  ])
);

drop policy if exists offers_read on public.offers;
create policy offers_read on public.offers for select to authenticated using (
  app_private.has_app_role(array[
    'admin'::public.app_role, 'operations'::public.app_role, 'auditor'::public.app_role
  ])
);

drop policy if exists proposals_read on public.proposals;
create policy proposals_read on public.proposals for select to authenticated using (
  app_private.has_app_role(array[
    'admin'::public.app_role, 'operations'::public.app_role,
    'support'::public.app_role, 'auditor'::public.app_role
  ])
);

drop policy if exists interactions_read on public.interactions;
create policy interactions_read on public.interactions for select to authenticated using (
  app_private.has_app_role(array[
    'admin'::public.app_role, 'operations'::public.app_role,
    'support'::public.app_role, 'auditor'::public.app_role
  ])
);

drop policy if exists pending_items_read on public.pending_items;
create policy pending_items_read on public.pending_items for select to authenticated using (
  app_private.has_app_role(array[
    'admin'::public.app_role, 'operations'::public.app_role,
    'support'::public.app_role, 'auditor'::public.app_role
  ])
);

drop policy if exists technical_operations_read on public.technical_operations;
create policy technical_operations_read on public.technical_operations for select to authenticated using (
  app_private.has_app_role(array[
    'admin'::public.app_role, 'operations'::public.app_role, 'auditor'::public.app_role
  ])
);

-- Admin pode administrar operacionais. Operations cria/atualiza, mas nao exclui.
do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'clients', 'technical_operations', 'consultations', 'offers',
    'proposals', 'interactions', 'pending_items'
  ] loop
    execute format('drop policy if exists %I on public.%I', table_name || '_admin_all', table_name);
    execute format(
      'create policy %I on public.%I for all to authenticated using (app_private.has_app_role(array[''admin''::public.app_role])) with check (app_private.has_app_role(array[''admin''::public.app_role]))',
      table_name || '_admin_all', table_name
    );
    execute format('drop policy if exists %I on public.%I', table_name || '_operations_insert', table_name);
    execute format(
      'create policy %I on public.%I for insert to authenticated with check (app_private.has_app_role(array[''operations''::public.app_role]))',
      table_name || '_operations_insert', table_name
    );
    execute format('drop policy if exists %I on public.%I', table_name || '_operations_update', table_name);
    execute format(
      'create policy %I on public.%I for update to authenticated using (app_private.has_app_role(array[''operations''::public.app_role])) with check (app_private.has_app_role(array[''operations''::public.app_role]))',
      table_name || '_operations_update', table_name
    );
  end loop;
end $$;

-- Suporte registra interacao e trata pendencia, sem alterar oferta/proposta/operacao.
drop policy if exists interactions_support_insert on public.interactions;
create policy interactions_support_insert on public.interactions
for insert to authenticated
with check (app_private.has_app_role(array['support'::public.app_role]));

drop policy if exists pending_items_support_update on public.pending_items;
create policy pending_items_support_update on public.pending_items
for update to authenticated
using (app_private.has_app_role(array['support'::public.app_role]))
with check (app_private.has_app_role(array['support'::public.app_role]));

create or replace function public.enforce_support_pending_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if app_private.current_user_role() = 'support'::public.app_role
     and (to_jsonb(new) - array[
       'status', 'assigned_user_id', 'due_at', 'resolution_masked',
       'resolved_at', 'updated_at'
     ]) is distinct from (to_jsonb(old) - array[
       'status', 'assigned_user_id', 'due_at', 'resolution_masked',
       'resolved_at', 'updated_at'
     ]) then
    raise exception 'Support pode alterar somente tratamento e resolucao da pendencia';
  end if;
  return new;
end;
$$;

drop trigger if exists pending_items_support_guard on public.pending_items;
create trigger pending_items_support_guard
before update on public.pending_items
for each row execute function public.enforce_support_pending_update();

revoke all on function public.enforce_support_pending_update() from public;

-- Auditoria: somente admin/auditor leem. Inserts acontecem pelas funcoes controladas.
drop policy if exists audit_events_read on audit.events;
create policy audit_events_read on audit.events
for select to authenticated using (
  app_private.has_app_role(array['admin'::public.app_role, 'auditor'::public.app_role])
);

create or replace function audit.reject_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'audit.events e append-only';
end;
$$;

drop trigger if exists audit_events_append_only on audit.events;
create trigger audit_events_append_only
before update or delete on audit.events
for each row execute function audit.reject_mutation();

revoke all on function audit.reject_mutation() from public;

create or replace function audit.capture_operational_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  row_data jsonb;
  origin_text text := current_setting('app.change_origin', true);
  safe_origin audit.change_origin;
  safe_metadata jsonb;
begin
  if tg_op = 'DELETE' then
    row_data := to_jsonb(old);
  else
    row_data := to_jsonb(new);
  end if;

  if origin_text in ('n8n', 'appsmith', 'gateway', 'human', 'system') then
    safe_origin := origin_text::audit.change_origin;
  else
    safe_origin := 'human'::audit.change_origin;
  end if;

  safe_metadata := jsonb_strip_nulls(jsonb_build_object(
    'product', row_data ->> 'product',
    'status_normalized', row_data ->> 'status_normalized',
    'journey_state', row_data ->> 'journey_state',
    'pending_action_code', row_data ->> 'pending_action',
    'state', row_data ->> 'state'
  ));

  insert into audit.events (
    actor_id, actor_role, origin, event_type, entity_type,
    entity_id, operation_id, allowed, metadata
  ) values (
    auth.uid(), app_private.current_user_role(), safe_origin,
    lower(tg_op), tg_table_name,
    coalesce(row_data ->> 'id', row_data ->> 'operation_id'),
    case when (row_data ->> 'operation_id') ~
      '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
      then (row_data ->> 'operation_id')::uuid else null end,
    true, safe_metadata
  );
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

revoke all on function audit.capture_operational_change() from public;

do $$
declare
  table_ref regclass;
begin
  foreach table_ref in array array[
    'public.clients'::regclass,
    'public.consultations'::regclass,
    'public.offers'::regclass,
    'public.proposals'::regclass,
    'public.interactions'::regclass,
    'public.pending_items'::regclass,
    'public.technical_operations'::regclass
  ] loop
    execute format('drop trigger if exists audit_operational_change on %s', table_ref);
    execute format(
      'create trigger audit_operational_change after insert or update or delete on %s for each row execute function audit.capture_operational_change()',
      table_ref
    );
  end loop;
end $$;

-- Funcao controlada: nunca retorna ciphertext. Acesso negado retorna zero linhas
-- e registra tentativa sem valor sensivel; evita que a excecao reverta a auditoria.
create or replace function app_private.get_client_sensitive_summary(
  requested_client_id uuid,
  purpose_code text
)
returns table (
  client_id uuid,
  cpf_last4 text,
  has_document boolean,
  has_address boolean,
  has_bank_data boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  permitted boolean := app_private.has_app_role(
    array['admin'::public.app_role, 'operations'::public.app_role]
  );
  safe_purpose text;
begin
  safe_purpose := case
    when purpose_code ~ '^[A-Z0-9_:-]{2,80}$' then purpose_code
    else 'UNSPECIFIED'
  end;

  insert into audit.events (
    actor_id, actor_role, origin, event_type, entity_type,
    entity_id, allowed, purpose_code, metadata
  ) values (
    auth.uid(), app_private.current_user_role(), 'human',
    case when permitted then 'sensitive_summary_access' else 'sensitive_summary_denied' end,
    'client_sensitive_data', requested_client_id::text, permitted,
    safe_purpose, '{}'::jsonb
  );

  if not permitted then
    return;
  end if;

  return query
  select d.client_id, d.cpf_last4::text,
    d.rg_ciphertext is not null or d.document_metadata_ciphertext is not null,
    d.address_ciphertext is not null,
    d.bank_data_ciphertext is not null
  from app_private.client_sensitive_data d
  where d.client_id = requested_client_id and d.anonymized_at is null;
end;
$$;

revoke all on function app_private.get_client_sensitive_summary(uuid, text) from public;
revoke all on function app_private.get_client_sensitive_summary(uuid, text) from anon;
grant execute on function app_private.get_client_sensitive_summary(uuid, text) to authenticated;

-- Auditor acessa somente resumo nao sensivel por view security-invoker.
create or replace view public.audit_event_summaries
with (security_invoker = true)
as
select id, occurred_at, actor_role, origin, event_type, entity_type,
       entity_id, operation_id, allowed, purpose_code, metadata
from audit.events;

revoke all on public.audit_event_summaries from public, anon;
grant select on public.audit_event_summaries to authenticated;
grant usage on schema audit to authenticated;
grant select on audit.events to authenticated;
revoke insert, update, delete on audit.events from authenticated;

-- Permissoes de tabelas publicas; RLS continua sendo a barreira por linha.
grant select, insert, update, delete on public.user_profiles to authenticated;
grant select, insert, update, delete on
  public.clients, public.technical_operations, public.consultations,
  public.offers, public.proposals, public.interactions, public.pending_items
to authenticated;

revoke all on all tables in schema app_private from public, anon, authenticated;
revoke all on all sequences in schema app_private from public, anon, authenticated;

-- Nenhum papel da API grava diretamente no schema privado. Nesta fase, somente
-- o owner da migration pode carregar fixtures cifradas. No ambiente real,
-- n8n/Gateway usarao uma credencial PostgreSQL backend dedicada e sem LOGIN
-- via PostgREST; a criacao dessa credencial depende do projeto e fica fora da migration.

-- Buckets seguros. Sem policy em storage.objects: clientes nao acessam objetos.
-- URLs assinadas devem ser geradas sob demanda por backend e nunca persistidas.
do $$
begin
  if to_regclass('storage.buckets') is not null then
    insert into storage.buckets (id, name, public)
    values
      ('cbn-documents-private', 'cbn-documents-private', false),
      ('cbn-raw-payloads-private', 'cbn-raw-payloads-private', false),
      ('cbn-evidence-private', 'cbn-evidence-private', false),
      ('cbn-temporary-private', 'cbn-temporary-private', false)
    on conflict (id) do update set public = false;
  end if;
end $$;

comment on schema app_private is
  'Nao expor no PostgREST. Acesso apenas por backend/funcoes minimas controladas.';
comment on schema audit is
  'Trilha append-only sem valores sensiveis completos.';
