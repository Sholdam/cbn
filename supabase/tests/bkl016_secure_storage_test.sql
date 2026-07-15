-- Execute depois da migration, em uma base Supabase local descartavel:
--   supabase db reset
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/bkl016_secure_storage_test.sql

begin;

do $$
declare
  expected text[] := array[
    'public.clients', 'public.consultations', 'public.offers',
    'public.proposals', 'public.interactions', 'public.pending_items',
    'public.technical_operations', 'public.user_profiles',
    'app_private.client_sensitive_data',
    'app_private.proposal_sensitive_data',
    'app_private.protected_payloads',
    'app_private.protected_file_refs', 'audit.events'
  ];
  item text;
begin
  foreach item in array expected loop
    if to_regclass(item) is null then
      raise exception 'Tabela esperada ausente: %', item;
    end if;
  end loop;
end $$;

do $$
declare
  missing text;
begin
  select string_agg(format('%I.%I', n.nspname, c.relname), ', ')
    into missing
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where (n.nspname, c.relname) in (
    ('public', 'clients'), ('public', 'consultations'), ('public', 'offers'),
    ('public', 'proposals'), ('public', 'interactions'),
    ('public', 'pending_items'), ('public', 'technical_operations'),
    ('public', 'user_profiles'),
    ('app_private', 'client_sensitive_data'),
    ('app_private', 'proposal_sensitive_data'),
    ('app_private', 'protected_payloads'),
    ('app_private', 'protected_file_refs'), ('audit', 'events')
  ) and not c.relrowsecurity;

  if missing is not null then
    raise exception 'RLS desativada em: %', missing;
  end if;
end $$;

-- Sem perfil, a funcao usada pelas policies deve negar acesso.
do $$
begin
  perform set_config('request.jwt.claim.sub', '90000000-0000-4000-8000-000000000001', true);
  if app_private.has_app_role(array['admin'::public.app_role]) then
    raise exception 'Usuario sem perfil recebeu papel administrativo';
  end if;
end $$;

-- Schemas privados nao possuem policy direta para authenticated/anon.
do $$
declare
  policy_count integer;
  direct_grant_count integer;
begin
  select count(*) into policy_count
  from pg_policies
  where schemaname = 'app_private';

  if policy_count <> 0 then
    raise exception 'Tabelas privadas nao devem ter policies diretas nesta fase';
  end if;

  select count(*) into direct_grant_count
  from information_schema.role_table_grants
  where table_schema = 'app_private'
    and grantee in ('anon', 'authenticated')
    and privilege_type in ('SELECT', 'INSERT', 'UPDATE', 'DELETE');

  if direct_grant_count <> 0 then
    raise exception 'Anon/authenticated recebeu grant direto no schema privado';
  end if;
end $$;

-- Auditor tem somente policies SELECT; nenhuma policy de mutacao o inclui.
do $$
declare
  mutation_policy_count integer;
begin
  select count(*) into mutation_policy_count
  from pg_policies
  where schemaname in ('public', 'audit')
    and cmd in ('INSERT', 'UPDATE', 'DELETE', 'ALL')
    and (
      coalesce(qual, '') ilike '%auditor%'
      or coalesce(with_check, '') ilike '%auditor%'
    );

  if mutation_policy_count <> 0 then
    raise exception 'Auditor aparece em policy de mutacao';
  end if;
end $$;

-- operation_id e globalmente unico na tabela canonica.
do $$
begin
  insert into public.technical_operations (
    operation_id, client_id, product, action, session_alias
  ) values (
    '91000000-0000-4000-8000-000000000001', null, 'CLT',
    'CONSULTAR', 'synthetic-test-alias'
  );

  begin
    insert into public.technical_operations (
      operation_id, client_id, product, action, session_alias
    ) values (
      '91000000-0000-4000-8000-000000000001', null, 'CLT',
      'CONSULTAR', 'synthetic-test-alias'
    );
    raise exception 'operation_id duplicado foi aceito';
  exception when unique_violation then
    null;
  end;
end $$;

-- Produto aceita somente FGTS/CLT.
do $$
begin
  begin
    perform 'INVALID_PRODUCT'::public.credit_product;
    raise exception 'Produto invalido foi aceito';
  exception when invalid_text_representation then
    null;
  end;
end $$;

-- Proposta exige oferta valida e coerente.
do $$
begin
  insert into public.clients (id, display_name, journey_state)
  values (
    '96000000-0000-4000-8000-000000000001',
    '[SYNTHETIC TEST] Constraint Fixture',
    'TEST_ONLY'
  ) on conflict (id) do nothing;

  insert into public.technical_operations (
    operation_id, client_id, product, action, session_alias
  ) values (
    '92000000-0000-4000-8000-000000000001',
    '96000000-0000-4000-8000-000000000001', 'CLT',
    'CRIAR_PROPOSTA', 'synthetic-test-alias'
  );

  begin
    insert into public.proposals (
      id, client_id, offer_id, product, operation_id,
      final_authorization_evidence_ref, authorized_at
    ) values (
      '93000000-0000-4000-8000-000000000001',
      '96000000-0000-4000-8000-000000000001',
      '94000000-0000-4000-8000-000000000001',
      'CLT',
      '92000000-0000-4000-8000-000000000001',
      '95000000-0000-4000-8000-000000000001',
      now()
    );
    raise exception 'Proposta sem oferta valida foi aceita';
  exception when foreign_key_violation then
    null;
  end;
end $$;

-- A trilha nao pode ser alterada nem removida.
do $$
declare
  event_id bigint;
begin
  insert into audit.events (
    origin, event_type, entity_type, entity_id, metadata
  ) values ('system', 'synthetic_test', 'test', 'synthetic', '{}')
  returning id into event_id;

  begin
    update audit.events set event_type = 'changed' where id = event_id;
    raise exception 'Evento de auditoria foi alterado';
  exception when raise_exception then
    if sqlerrm <> 'audit.events e append-only' then raise; end if;
  end;
end $$;

rollback;

select 'BKL-016 database checks passed' as result;
