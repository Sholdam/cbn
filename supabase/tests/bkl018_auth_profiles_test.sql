\set ON_ERROR_STOP on

begin;

-- Fixtures Auth exclusivamente sinteticas, sem senha utilizavel ou e-mail real.
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, email_change,
  email_change_token_new, recovery_token
) values
  ('00000000-0000-0000-0000-000000000000', '91000000-0000-4000-8000-000000000001',
   'authenticated', 'authenticated', 'admin.bkl018@example.invalid', '', now(),
   '{"provider":"email","providers":["email"]}', '{"fixture":"synthetic"}', now(), now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '91000000-0000-4000-8000-000000000002',
   'authenticated', 'authenticated', 'operations.bkl018@example.invalid', '', now(),
   '{"provider":"email","providers":["email"]}', '{"fixture":"synthetic"}', now(), now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '91000000-0000-4000-8000-000000000003',
   'authenticated', 'authenticated', 'support.bkl018@example.invalid', '', now(),
   '{"provider":"email","providers":["email"]}', '{"fixture":"synthetic"}', now(), now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '91000000-0000-4000-8000-000000000004',
   'authenticated', 'authenticated', 'auditor.bkl018@example.invalid', '', now(),
   '{"provider":"email","providers":["email"]}', '{"fixture":"synthetic"}', now(), now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '91000000-0000-4000-8000-000000000005',
   'authenticated', 'authenticated', 'pending.bkl018@example.invalid', '', now(),
   '{"provider":"email","providers":["email"]}', '{"fixture":"synthetic"}', now(), now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '91000000-0000-4000-8000-000000000006',
   'authenticated', 'authenticated', 'disabled.bkl018@example.invalid', '', now(),
   '{"provider":"email","providers":["email"]}', '{"fixture":"synthetic"}', now(), now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '91000000-0000-4000-8000-000000000007',
   'authenticated', 'authenticated', 'no-profile.bkl018@example.invalid', '', now(),
   '{"provider":"email","providers":["email"]}', '{"fixture":"synthetic"}', now(), now(), '', '', '', ''),
  ('00000000-0000-0000-8000-000000000000', '91000000-0000-4000-8000-000000000008',
   'authenticated', 'authenticated', 'target.bkl018@example.invalid', '', now(),
   '{"provider":"email","providers":["email"]}', '{"fixture":"synthetic"}', now(), now(), '', '', '', '');

insert into public.user_profiles (user_id, role, display_name, active, status) values
  ('91000000-0000-4000-8000-000000000001', 'admin', null, true, 'ACTIVE'),
  ('91000000-0000-4000-8000-000000000002', 'operations', null, true, 'ACTIVE'),
  ('91000000-0000-4000-8000-000000000003', 'support', null, true, 'ACTIVE'),
  ('91000000-0000-4000-8000-000000000004', 'auditor', null, true, 'ACTIVE'),
  ('91000000-0000-4000-8000-000000000005', 'support', null, false, 'PENDING_REVIEW'),
  ('91000000-0000-4000-8000-000000000006', 'operations', null, false, 'DISABLED');

insert into public.clients (
  id, display_name, phone_masked, cpf_masked, lead_source, journey_state
) values (
  '92000000-0000-4000-8000-000000000001', '[SYNTHETIC TEST] Masked client',
  '+55 ** *****-0000', '***.***.***-00', 'synthetic_bkl018', 'TEST_READY'
);

-- Estrutura, grants e funcoes seguras.
do $$
declare
  unsafe text;
begin
  if exists (
    select 1 from information_schema.role_table_grants
    where table_schema = 'public' and table_name = 'user_profiles'
      and grantee in ('anon', 'authenticated', 'service_role')
  ) then raise exception 'papel web possui acesso direto a user_profiles'; end if;

  select string_agg(format('%I.%I', n.nspname, p.proname), ', ')
  into unsafe
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where p.oid in (
    'audit.record_human_profile_event(text,uuid,boolean,text,text,text,public.app_role,text)'::regprocedure,
    'public.admin_create_human_profile(uuid,public.app_role,text,text,text)'::regprocedure,
    'public.admin_change_human_role(uuid,public.app_role,text,text)'::regprocedure,
    'public.admin_disable_human_profile(uuid,text,text)'::regprocedure,
    'public.admin_reactivate_human_profile(uuid,text,text)'::regprocedure,
    'public.get_my_profile()'::regprocedure
  ) and (not p.prosecdef or not ('search_path=""' = any(coalesce(p.proconfig, array[]::text[]))));
  if unsafe is not null then raise exception 'funcao controlada insegura: %', unsafe; end if;

  if has_function_privilege('anon', 'public.get_my_profile()', 'EXECUTE')
     or has_function_privilege('service_role', 'public.get_my_profile()', 'EXECUTE')
     or has_function_privilege('authenticated',
       'audit.record_human_profile_event(text,uuid,boolean,text,text,text,public.app_role,text)', 'EXECUTE') then
    raise exception 'grant de funcao humana acima do minimo';
  end if;
end
$$;

-- Anon nao possui acesso operacional nem RPC humana.
set local role anon;
do $$ begin
  begin
    perform count(*) from public.clients;
    raise exception 'anon acessou dados operacionais';
  exception when insufficient_privilege then null; end;
  begin
    perform * from public.get_my_profile();
    raise exception 'anon executou RPC de perfil';
  exception when insufficient_privilege then null; end;
end $$;
reset role;

-- Authenticated sem perfil nao acessa dados e recebe perfil vazio.
set local role authenticated;
select set_config('request.jwt.claim.sub', '91000000-0000-4000-8000-000000000007', true);
do $$
begin
  if (select count(*) from public.clients) <> 0 then
    raise exception 'usuario sem perfil acessou operacao';
  end if;
  if (select count(*) from public.get_my_profile()) <> 0 then
    raise exception 'usuario sem perfil recebeu perfil inexistente';
  end if;
end $$;
reset role;

-- Pending e disabled conhecem apenas seu estado tecnico minimo; operacao e negada.
set local role authenticated;
select set_config('request.jwt.claim.sub', '91000000-0000-4000-8000-000000000005', true);
do $$ begin
  if (select count(*) from public.clients) <> 0 then raise exception 'pending acessou operacao'; end if;
  if (select status from public.get_my_profile()) <> 'PENDING_REVIEW' then
    raise exception 'pending nao recebeu estado minimo';
  end if;
end $$;
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', '91000000-0000-4000-8000-000000000006', true);
do $$ begin
  if (select count(*) from public.clients) <> 0 then raise exception 'disabled acessou operacao'; end if;
  if (select status from public.get_my_profile()) <> 'DISABLED' then
    raise exception 'disabled nao recebeu estado minimo';
  end if;
end $$;
reset role;

-- Operations, support e auditor nao administram perfis.
set local role authenticated;
select set_config('request.jwt.claim.sub', '91000000-0000-4000-8000-000000000002', true);
do $$ begin
  if public.admin_change_human_role(
    '91000000-0000-4000-8000-000000000004', 'support', 'BKL018_TEST', 'bkl018-v1'
  ) then raise exception 'operations administrou perfil'; end if;
  begin
    perform count(*) from app_private.client_sensitive_data;
    raise exception 'operations acessou privado';
  exception when insufficient_privilege then null; end;
end $$;
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', '91000000-0000-4000-8000-000000000003', true);
do $$
declare p text; c text;
begin
  if public.admin_change_human_role(
    '91000000-0000-4000-8000-000000000003', 'admin', 'BKL018_TEST', 'bkl018-v1'
  ) then raise exception 'support se elevou'; end if;
  select phone_masked, cpf_masked into p, c from public.clients limit 1;
  if position('*' in p) = 0 or position('*' in c) = 0 then
    raise exception 'support recebeu identificador completo';
  end if;
end $$;
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', '91000000-0000-4000-8000-000000000004', true);
do $$
declare affected integer;
begin
  if public.admin_disable_human_profile(
    '91000000-0000-4000-8000-000000000002', 'BKL018_TEST', 'bkl018-v1'
  ) then raise exception 'auditor administrou perfil'; end if;
  update public.clients set journey_state = 'AUDITOR_MUTATION_DENIED'
  where id = '92000000-0000-4000-8000-000000000001';
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'auditor alterou dado operacional'; end if;
  begin
    perform count(*) from app_private.protected_payloads;
    raise exception 'auditor acessou ciphertext';
  exception when insufficient_privilege then null; end;
end $$;
reset role;

-- Admin usa somente RPC: cria, atribui/altera papel, desativa e reativa.
set local role authenticated;
select set_config('request.jwt.claim.sub', '91000000-0000-4000-8000-000000000001', true);
do $$
begin
  begin
    update public.user_profiles set role = 'admin'
    where user_id = '91000000-0000-4000-8000-000000000003';
    raise exception 'admin alterou user_profiles diretamente';
  exception when insufficient_privilege then null; end;

  if public.admin_change_human_role(
    '91000000-0000-4000-8000-000000000001', 'operations', 'BKL018_TEST', 'bkl018-v1'
  ) then raise exception 'admin alterou o proprio papel'; end if;

  if not public.admin_create_human_profile(
    '91000000-0000-4000-8000-000000000008', 'support', 'PENDING_REVIEW',
    'BKL018_TEST', 'bkl018-v1'
  ) then raise exception 'admin nao criou perfil'; end if;
  if not public.admin_change_human_role(
    '91000000-0000-4000-8000-000000000008', 'auditor', 'BKL018_TEST', 'bkl018-v1'
  ) then raise exception 'admin nao alterou papel'; end if;
  if not public.admin_disable_human_profile(
    '91000000-0000-4000-8000-000000000008', 'BKL018_TEST', 'bkl018-v1'
  ) then raise exception 'admin nao desativou perfil'; end if;
  if not public.admin_reactivate_human_profile(
    '91000000-0000-4000-8000-000000000008', 'BKL018_TEST', 'bkl018-v1'
  ) then raise exception 'admin nao reativou perfil'; end if;

  begin
    perform count(*) from app_private.client_sensitive_data;
    raise exception 'admin acessou dados privados';
  exception when insufficient_privilege then null; end;

  begin
    execute $sql$select public.admin_change_human_role(
      '91000000-0000-4000-8000-000000000008',
      'cbn_gateway_backend'::public.app_role, 'BKL018_TEST', 'bkl018-v1')$sql$;
    raise exception 'papel tecnico foi atribuido a humano';
  exception when invalid_text_representation then null; end;
end $$;
reset role;

-- service_role nao e identidade humana final e nao executa as RPCs.
set local role service_role;
do $$ begin
  begin
    perform * from public.get_my_profile();
    raise exception 'service_role usada como identidade humana';
  exception when insufficient_privilege then null; end;
end $$;
reset role;

-- Auditoria minima persistiu recusas e sucessos sem PII/segredo.
do $$
declare
  forbidden integer;
begin
  if not exists (select 1 from audit.events
    where event_type = 'HUMAN_ROLE_ELEVATION_DENIED'
      and metadata ->> 'identity_model' = 'BKL018_HUMAN_PROFILE_V1'
      and allowed = false)
    or not exists (select 1 from audit.events
    where event_type = 'HUMAN_PROFILE_CREATED' and allowed)
    or not exists (select 1 from audit.events
    where event_type = 'HUMAN_ROLE_CHANGED' and allowed)
    or not exists (select 1 from audit.events
    where event_type = 'HUMAN_PROFILE_DISABLED' and allowed)
    or not exists (select 1 from audit.events
    where event_type = 'HUMAN_PROFILE_REACTIVATED' and allowed) then
    raise exception 'auditoria humana minima incompleta';
  end if;

  select count(*) into forbidden from audit.events
  where metadata ->> 'identity_model' = 'BKL018_HUMAN_PROFILE_V1'
    and lower(concat_ws(' ', entity_id, purpose_code, metadata::text)) ~
      '(example[.]invalid|e-mail|email|cpf|telefone|phone|senha|password|jwt|token|ciphertext|signed.?url)';
  if forbidden <> 0 then raise exception 'auditoria humana contem dado proibido'; end if;
end $$;

select 'BKL-018 authentication profiles and permissions passed' as result;

rollback;
