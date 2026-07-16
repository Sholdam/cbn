-- BKL-016 - verificacoes remotas somente para projeto Supabase de desenvolvimento.
-- Este arquivo nao cria fixtures. A suite transacional local e executada depois
-- pelo validador PowerShell e termina com ROLLBACK.

begin;

do $$
declare
  expected_tables text[] := array[
    'public.clients', 'public.consultations', 'public.offers',
    'public.proposals', 'public.interactions', 'public.pending_items',
    'public.technical_operations', 'public.user_profiles',
    'app_private.client_sensitive_data',
    'app_private.proposal_sensitive_data',
    'app_private.protected_payloads',
    'app_private.protected_file_refs', 'audit.events'
  ];
  table_name text;
  expected_roles text[] := array['admin', 'operations', 'support', 'auditor'];
  actual_roles text[];
begin
  foreach table_name in array expected_tables loop
    if to_regclass(table_name) is null then
      raise exception 'Migration BKL-016 ausente ou incompleta: tabela esperada nao existe';
    end if;
  end loop;

  if to_regclass('supabase_migrations.schema_migrations') is not null
     and not exists (
       select 1
       from supabase_migrations.schema_migrations
       where version like '20260715%'
     ) then
    raise exception 'Migration BKL-016 nao consta no historico remoto';
  end if;

  select array_agg(e.enumlabel order by e.enumsortorder)
    into actual_roles
  from pg_type t
  join pg_namespace n on n.oid = t.typnamespace
  join pg_enum e on e.enumtypid = t.oid
  where n.nspname = 'public' and t.typname = 'app_role';

  if actual_roles is distinct from expected_roles then
    raise exception 'Roles BKL-016 ausentes ou divergentes';
  end if;
end $$;

do $$
declare
  missing_rls text;
begin
  select string_agg(format('%I.%I', n.nspname, c.relname), ', ')
    into missing_rls
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where (n.nspname, c.relname) in (
    ('public', 'clients'), ('public', 'consultations'),
    ('public', 'offers'), ('public', 'proposals'),
    ('public', 'interactions'), ('public', 'pending_items'),
    ('public', 'technical_operations'), ('public', 'user_profiles'),
    ('app_private', 'client_sensitive_data'),
    ('app_private', 'proposal_sensitive_data'),
    ('app_private', 'protected_payloads'),
    ('app_private', 'protected_file_refs'), ('audit', 'events')
  ) and not c.relrowsecurity;

  if missing_rls is not null then
    raise exception 'RLS desativada em tabela BKL-016';
  end if;
end $$;

do $$
declare
  unsafe_functions integer;
  unexpected_grants integer;
begin
  select count(*) into unsafe_functions
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname in ('app_private', 'audit')
    and p.prosecdef
    and not ('search_path=""' = any(coalesce(p.proconfig, array[]::text[])));

  if unsafe_functions <> 0 then
    raise exception 'SECURITY DEFINER sem search_path vazio';
  end if;

  select count(*) into unexpected_grants
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relname in (
      'clients', 'consultations', 'offers', 'proposals', 'interactions',
      'pending_items', 'technical_operations', 'user_profiles'
    )
    and has_table_privilege('anon', c.oid, 'SELECT,INSERT,UPDATE,DELETE');

  if unexpected_grants <> 0 then
    raise exception 'anon possui grant operacional inesperado';
  end if;

  select count(*) into unexpected_grants
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'app_private'
    and has_table_privilege('authenticated', c.oid, 'SELECT,INSERT,UPDATE,DELETE');

  if unexpected_grants <> 0 then
    raise exception 'authenticated possui acesso direto ao schema privado';
  end if;

  select count(*) into unexpected_grants
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'app_private'
    and has_function_privilege('anon', p.oid, 'EXECUTE');

  if unexpected_grants <> 0 then
    raise exception 'anon possui EXECUTE em funcao privada';
  end if;
end $$;

do $$
declare
  exposed_private_setting integer;
begin
  select count(*) into exposed_private_setting
  from pg_db_role_setting s
  cross join lateral unnest(s.setconfig) setting
  where setting ~* '^pgrst\.db_schemas='
    and setting ~* '(^|[=,[:space:]])(app_private|audit)([,[:space:]]|$)';

  if exposed_private_setting <> 0 then
    raise exception 'Schema privado configurado para exposicao no PostgREST';
  end if;
end $$;

do $$
declare
  expected_private_buckets integer;
  public_buckets integer;
  public_policies integer;
begin
  if to_regclass('storage.buckets') is null
     or to_regclass('storage.objects') is null then
    raise exception 'Storage Supabase nao esta disponivel no projeto';
  end if;

  select count(*) into expected_private_buckets
  from storage.buckets
  where id in (
    'cbn-documents-private', 'cbn-raw-payloads-private',
    'cbn-evidence-private', 'cbn-temporary-private'
  ) and public is false;

  if expected_private_buckets <> 4 then
    raise exception 'Buckets privados BKL-016 ausentes ou divergentes';
  end if;

  select count(*) into public_buckets
  from storage.buckets
  where id in (
    'cbn-documents-private', 'cbn-raw-payloads-private',
    'cbn-evidence-private', 'cbn-temporary-private'
  ) and public is true;

  if public_buckets <> 0 then
    raise exception 'Bucket BKL-016 esta publico';
  end if;

  select count(*) into public_policies
  from pg_policies p
  where p.schemaname = 'storage'
    and p.tablename = 'objects'
    and exists (
      select 1 from unnest(p.roles) role_name
      where lower(role_name::text) in ('public', 'anon')
    );

  if public_policies <> 0 then
    raise exception 'Policy publica ou anon detectada em storage.objects';
  end if;

  if exists (
    select 1
    from storage.objects
    where bucket_id in (
      'cbn-documents-private', 'cbn-raw-payloads-private',
      'cbn-evidence-private', 'cbn-temporary-private'
    ) and (
      name !~ '^[a-f0-9-]{16,200}(?:/[a-f0-9-]{16,200})*$'
      or name ~ '[0-9]{11}'
    )
  ) then
    raise exception 'Objeto BKL-016 possui nome fora do padrao UUID/hash';
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'consultations_operation_owner_product_fk'
      and conrelid = 'public.consultations'::regclass
  ) then
    raise exception 'Integridade cliente/produto/operacao ausente em consultations';
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'proposals_operation_owner_product_fk'
      and conrelid = 'public.proposals'::regclass
  ) then
    raise exception 'Integridade cliente/produto/operacao ausente em proposals';
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'proposals_final_authorization_evidence_payload_ref_fk'
      and conrelid = 'public.proposals'::regclass
  ) then
    raise exception 'Integridade da evidencia final ausente';
  end if;

  if not exists (
    select 1 from pg_trigger
    where tgname = 'offers_protect_snapshot'
      and tgrelid = 'public.offers'::regclass
      and tgenabled <> 'D'
      and not tgisinternal
  ) then
    raise exception 'Protecao de snapshot de oferta ausente';
  end if;

  if not exists (
    select 1 from pg_trigger
    where tgname = 'audit_events_append_only'
      and tgrelid = 'audit.events'::regclass
      and tgenabled <> 'D'
      and not tgisinternal
  ) then
    raise exception 'Protecao append-only da auditoria ausente';
  end if;
end $$;

do $$
declare
  item record;
  unsafe_value boolean;
  unsafe_pattern text := '(eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{16,}|-----BEGIN [A-Z ]*PRIVATE KEY-----|(?:sk-|ghp_|github_pat_|xox[baprs]-|sb_secret_)[A-Za-z0-9_-]{16,}|https://[^[:space:]"'']+/storage/v1/object/sign/|[?&](?:token|signature)=[A-Za-z0-9._~-]{12,}|[0-9]{3}\.?[0-9]{3}\.?[0-9]{3}-?[0-9]{2})';
begin
  for item in
    select c.table_schema, c.table_name, c.column_name
    from information_schema.columns c
    where c.table_schema in ('public', 'app_private')
      and c.data_type in ('text', 'character varying', 'character')
      and to_regclass(format('%I.%I', c.table_schema, c.table_name)) is not null
  loop
    execute format(
      'select exists (select 1 from %I.%I where %I::text ~ $1)',
      item.table_schema, item.table_name, item.column_name
    ) using unsafe_pattern into unsafe_value;

    if unsafe_value then
      raise exception 'Dado real ou segredo aparente detectado em tabela BKL-016';
    end if;
  end loop;

  if exists (
    select 1 from auth.users
    where email is not null and email !~* '@example\.invalid$'
  ) then
    raise exception 'Usuario Auth nao sintetico detectado no projeto isolado';
  end if;

  if exists (
    select 1 from audit.events
    where metadata::text ~ unsafe_pattern
  ) then
    raise exception 'Dado real ou segredo aparente detectado na auditoria';
  end if;
end $$;

rollback;

select 'BKL-016 remote structural checks passed' as result;
