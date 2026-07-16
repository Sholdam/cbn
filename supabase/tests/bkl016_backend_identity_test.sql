\set ON_ERROR_STOP on

begin;

do $$
declare
  role_name text;
  r pg_catalog.pg_roles%rowtype;
begin
  foreach role_name in array array[
    'cbn_gateway_backend', 'cbn_retention_operator',
    'cbn_hold_reviewer', 'cbn_deletion_executor'
  ] loop
    select * into strict r from pg_catalog.pg_roles where rolname = role_name;
    if r.rolcanlogin or r.rolsuper or r.rolcreatedb or r.rolcreaterole
       or r.rolbypassrls or r.rolreplication or r.rolinherit then
      raise exception 'papel tecnico possui atributo privilegiado: %', role_name;
    end if;
  end loop;

  if exists (
    select 1 from pg_catalog.pg_auth_members m
    join pg_catalog.pg_roles member_role on member_role.oid = m.member
    join pg_catalog.pg_roles granted_role on granted_role.oid = m.roleid
    where (member_role.rolname like 'cbn_%' or granted_role.rolname like 'cbn_%')
      and not (
        granted_role.rolname in (
          'cbn_gateway_backend', 'cbn_retention_operator',
          'cbn_hold_reviewer', 'cbn_deletion_executor'
        ) and member_role.rolname = 'postgres'
      )
  ) then raise exception 'papel tecnico recebeu membership operacional'; end if;

  if exists (
       select 1
       from pg_catalog.pg_class c
       cross join lateral pg_catalog.aclexplode(
         coalesce(c.relacl, pg_catalog.acldefault('r', c.relowner))
       ) acl
       where c.oid = 'app_private.client_sensitive_data'::regclass
         and acl.grantee = 0 and acl.privilege_type in ('SELECT', 'INSERT', 'UPDATE', 'DELETE')
     )
     or has_table_privilege('anon', 'app_private.client_sensitive_data', 'SELECT')
     or has_table_privilege('authenticated', 'app_private.client_sensitive_data', 'SELECT') then
    raise exception 'papel web acessa tabela privada';
  end if;

  if has_function_privilege('anon', 'app_private.retention_evaluate(uuid,text,text)', 'EXECUTE')
     or has_function_privilege('authenticated', 'app_private.retention_evaluate(uuid,text,text)', 'EXECUTE')
     or has_function_privilege('anon', 'app_private.gateway_create_operation(uuid,uuid,public.credit_product,text,text,text)', 'EXECUTE')
     or has_function_privilege('authenticated', 'app_private.gateway_create_operation(uuid,uuid,public.credit_product,text,text,text)', 'EXECUTE')
     or has_function_privilege('anon', 'app_private.retention_anonymize_clients(uuid[],text)', 'EXECUTE')
     or has_function_privilege('authenticated', 'app_private.retention_prepare_deletion(uuid[],text,text)', 'EXECUTE') then
    raise exception 'papel web executa wrapper tecnico';
  end if;

  if not has_function_privilege('cbn_gateway_backend', 'app_private.gateway_create_operation(uuid,uuid,public.credit_product,text,text,text)', 'EXECUTE')
     or has_function_privilege('cbn_gateway_backend', 'app_private.retention_evaluate(uuid,text,text)', 'EXECUTE')
     or not has_function_privilege('cbn_retention_operator', 'app_private.retention_evaluate(uuid,text,text)', 'EXECUTE')
     or has_function_privilege('cbn_retention_operator', 'app_private.hold_review_removal(uuid,text,text,text)', 'EXECUTE')
     or not has_function_privilege('cbn_hold_reviewer', 'app_private.hold_review_removal(uuid,text,text,text)', 'EXECUTE')
     or has_function_privilege('cbn_hold_reviewer', 'app_private.retention_anonymize_clients(uuid[],text)', 'EXECUTE')
     or not has_function_privilege('cbn_deletion_executor', 'app_private.retention_complete_deletion(uuid,boolean,text)', 'EXECUTE')
     or has_function_privilege('cbn_deletion_executor', 'app_private.retention_prepare_deletion(uuid[],text,text)', 'EXECUTE') then
    raise exception 'grants nao correspondem a matriz minima';
  end if;

  if exists (
    select 1
    from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid = p.pronamespace
    cross join unnest(array[
      'cbn_gateway_backend', 'cbn_retention_operator',
      'cbn_hold_reviewer', 'cbn_deletion_executor'
    ]) as identity_role(role_name)
    where n.nspname in ('app_private', 'audit')
      and has_function_privilege(identity_role.role_name, p.oid, 'EXECUTE')
      and not (
        (identity_role.role_name = 'cbn_gateway_backend' and p.oid in (
          'app_private.gateway_create_operation(uuid,uuid,public.credit_product,text,text,text)'::regprocedure,
          'app_private.gateway_update_operation_state(uuid,text,text,text,text,text)'::regprocedure
        ))
        or (identity_role.role_name = 'cbn_retention_operator' and p.oid in (
          'app_private.retention_evaluate(uuid,text,text)'::regprocedure,
          'app_private.retention_apply_legal_hold(uuid,text,text)'::regprocedure,
          'app_private.retention_anonymize_clients(uuid[],text)'::regprocedure,
          'app_private.retention_prepare_deletion(uuid[],text,text)'::regprocedure,
          'app_private.retention_cancel_deletion(uuid,text,text)'::regprocedure,
          'app_private.retention_request_hold_removal(uuid,text)'::regprocedure
        ))
        or (identity_role.role_name = 'cbn_hold_reviewer' and p.oid =
          'app_private.hold_review_removal(uuid,text,text,text)'::regprocedure)
        or (identity_role.role_name = 'cbn_deletion_executor' and p.oid =
          'app_private.retention_complete_deletion(uuid,boolean,text)'::regprocedure)
      )
  ) then raise exception 'papel tecnico executa funcao privada fora da matriz'; end if;

  if exists (
    select 1 from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid = p.pronamespace
    join pg_catalog.pg_roles owner_role on owner_role.oid = p.proowner
    where n.nspname in ('app_private', 'audit')
      and p.proname in (
        'record_backend_identity_event', 'gateway_create_operation',
        'gateway_update_operation_state', 'retention_evaluate',
        'retention_apply_legal_hold', 'retention_anonymize_clients',
        'retention_prepare_deletion', 'retention_cancel_deletion',
        'retention_request_hold_removal', 'reject_legal_hold_removal',
        'hold_review_removal', 'retention_complete_deletion'
      )
      and (
        not p.prosecdef
        or not ('search_path=""' = any(coalesce(p.proconfig, array[]::text[])))
        or owner_role.rolname in (
          'cbn_gateway_backend', 'cbn_retention_operator',
          'cbn_hold_reviewer', 'cbn_deletion_executor'
        )
      )
  ) then raise exception 'wrapper sem SECURITY DEFINER/search_path/owner seguro'; end if;
end
$$;

insert into public.clients (id, display_name, journey_state) values
  ('c1000000-0000-4000-8000-000000000001', '[SYNTHETIC TEST] Gateway', 'NEW'),
  ('c1000000-0000-4000-8000-000000000002', '[SYNTHETIC TEST] Anonymize', 'NEW'),
  ('c1000000-0000-4000-8000-000000000003', '[SYNTHETIC TEST] Hold', 'NEW'),
  ('c1000000-0000-4000-8000-000000000004', '[SYNTHETIC TEST] Delete', 'NEW');

insert into app_private.retention_policies (
  id, policy_code, data_category, purpose_code, retention_period,
  policy_status, review_required
) values (
  'c2000000-0000-4000-8000-000000000001', 'SYNTHETIC_BACKEND_IDENTITY',
  'SYNTHETIC_DATA', 'SYNTHETIC_TEST', interval '1 day', 'ACTIVE', false
);

insert into app_private.client_sensitive_data (
  client_id, cpf_ciphertext, encryption_key_ref, encryption_version, retention_until
) values (
  'c1000000-0000-4000-8000-000000000002', decode('01', 'hex'),
  'local-test-only', 'local-v1', now() - interval '2 days'
);

insert into app_private.retention_controls (
  id, policy_id, entity_type, entity_id, client_id, purpose_code,
  retention_until, deletion_eligible_at, status, process_version, review_required
) values
  ('c3000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000001',
   'CLIENT', 'c1000000-0000-4000-8000-000000000002', 'c1000000-0000-4000-8000-000000000002',
   'SYNTHETIC_TEST', now() - interval '2 days', now() - interval '1 day', 'ELIGIBLE', 'identity-v1', false),
  ('c3000000-0000-4000-8000-000000000002', 'c2000000-0000-4000-8000-000000000001',
   'CLIENT', 'c1000000-0000-4000-8000-000000000003', 'c1000000-0000-4000-8000-000000000003',
   'SYNTHETIC_TEST', now() - interval '2 days', now() - interval '1 day', 'ELIGIBLE', 'identity-v1', false);

set local role cbn_gateway_backend;
select app_private.gateway_create_operation(
  'c4000000-0000-4000-8000-000000000001',
  'c1000000-0000-4000-8000-000000000001', 'FGTS', 'CONSULTAR',
  'synthetic-gateway', 'identity-v1'
);
select app_private.gateway_update_operation_state(
  'c4000000-0000-4000-8000-000000000001', 'COMPLETED',
  'SYNTHETIC_DONE', 'SYNTHETIC_OK', null, 'identity-v1'
);
do $$
begin
  begin
    perform * from app_private.client_sensitive_data;
    raise exception 'gateway leu client_sensitive_data';
  exception when insufficient_privilege then null; end;
  begin
    perform * from app_private.proposal_sensitive_data;
    raise exception 'gateway leu proposal_sensitive_data';
  exception when insufficient_privilege then null; end;
  begin
    perform * from app_private.protected_payloads;
    raise exception 'gateway leu protected_payloads';
  exception when insufficient_privilege then null; end;
  begin
    perform * from app_private.protected_file_refs;
    raise exception 'gateway leu protected_file_refs';
  exception when insufficient_privilege then null; end;
  begin
    perform * from audit.events;
    raise exception 'gateway leu auditoria';
  exception when insufficient_privilege then null; end;
  begin
    delete from public.clients where id = 'c1000000-0000-4000-8000-000000000001';
    raise exception 'gateway executou DELETE direto';
  exception when insufficient_privilege then null; end;
end
$$;
reset role;

-- Usa uma identidade sintética sem privilegio administrativo para provar que
-- membership em Gateway nao permite assumir/reconfigurar outros papeis.
create role cbn_identity_test_principal
  nologin nosuperuser nocreatedb nocreaterole noinherit noreplication nobypassrls;
grant cbn_gateway_backend to cbn_identity_test_principal;
set session authorization cbn_identity_test_principal;
set role cbn_gateway_backend;
do $$
begin
  begin
    perform set_config('role', 'cbn_hold_reviewer', true);
    raise exception 'gateway assumiu papel nao concedido';
  exception when insufficient_privilege then null; end;
  begin
    execute 'grant cbn_hold_reviewer to cbn_gateway_backend';
    raise exception 'gateway executou GRANT';
  exception when insufficient_privilege then null; end;
  begin
    execute 'alter role cbn_hold_reviewer createdb';
    raise exception 'gateway executou ALTER ROLE';
  exception when insufficient_privilege then null; end;
  begin
    execute 'create role cbn_forbidden_role';
    raise exception 'gateway executou CREATE ROLE';
  exception when insufficient_privilege then null; end;
end
$$;
reset role;
reset session authorization;
drop role cbn_identity_test_principal;

do $$
begin
  if not exists (
    select 1 from public.technical_operations
    where operation_id = 'c4000000-0000-4000-8000-000000000001'
      and state = 'COMPLETED'
  ) then raise exception 'wrapper operacional nao persistiu estado'; end if;
end
$$;

set local role cbn_retention_operator;
do $$
declare processed integer;
begin
  if not app_private.retention_evaluate(
    'c3000000-0000-4000-8000-000000000001', 'ANONYMIZE', 'identity-v1'
  ) then raise exception 'operador nao avaliou retencao'; end if;
  processed := app_private.retention_anonymize_clients(
    array['c3000000-0000-4000-8000-000000000001'::uuid], 'identity-v1'
  );
  if processed <> 1 then raise exception 'operador nao anonimizou fixture permitida'; end if;
  processed := app_private.retention_anonymize_clients(
    array['c3000000-0000-4000-8000-000000000001'::uuid], 'identity-v1'
  );
  if processed <> 0 then raise exception 'segunda anonimizacao alterou fixture'; end if;
  perform app_private.retention_apply_legal_hold(
    'c3000000-0000-4000-8000-000000000002', 'SYNTHETIC_REVIEW', 'identity-v1'
  );
  perform app_private.retention_request_hold_removal(
    'c3000000-0000-4000-8000-000000000002', 'identity-v1'
  );
  begin
    perform app_private.hold_review_removal(
      'c3000000-0000-4000-8000-000000000002', 'APPROVE', 'SYNTHETIC_APPROVAL', 'identity-v1'
    );
    raise exception 'solicitante aprovou a propria remocao';
  exception when insufficient_privilege then null; end;
  begin
    perform * from app_private.client_sensitive_data;
    raise exception 'operador leu dados privados';
  exception when insufficient_privilege then null; end;
  begin
    perform app_private.retention_complete_deletion(
      'c3000000-0000-4000-8000-000000000002', true, 'identity-v1'
    );
    raise exception 'operador concluiu exclusao';
  exception when insufficient_privilege then null; end;
  begin
    perform * from app_private.retention_prepare_deletion(array[]::uuid[],
      'synthetic-local-explicit-ids', 'identity-v1');
    raise exception 'lista vazia foi aceita';
  exception when invalid_parameter_value then null; end;
  begin
    perform * from app_private.retention_prepare_deletion(
      array_fill('c3000000-0000-4000-8000-000000000002'::uuid, array[11]),
      'synthetic-local-explicit-ids', 'identity-v1');
    raise exception 'lote acima do limite foi aceito';
  exception when invalid_parameter_value then null; end;
end
$$;
reset role;

set local role cbn_hold_reviewer;
do $$
begin
  if not app_private.hold_review_removal(
    'c3000000-0000-4000-8000-000000000002', 'APPROVE',
    'SYNTHETIC_APPROVAL', 'identity-v1'
  ) then raise exception 'revisor independente nao aprovou remocao'; end if;
  begin
    perform app_private.retention_anonymize_clients(
      array['c3000000-0000-4000-8000-000000000002'::uuid], 'identity-v1'
    );
    raise exception 'revisor iniciou anonimizacao';
  exception when insufficient_privilege then null; end;
  begin
    perform * from app_private.retention_prepare_deletion(
      array['c3000000-0000-4000-8000-000000000002'::uuid],
      'synthetic-local-explicit-ids', 'identity-v1');
    raise exception 'revisor preparou exclusao';
  exception when insufficient_privilege then null; end;
  begin
    update public.clients set journey_state = 'HUMAN_REVIEW'
    where id = 'c1000000-0000-4000-8000-000000000003';
    raise exception 'revisor alterou dado operacional';
  exception when insufficient_privilege then null; end;
end
$$;
reset role;

-- Prova do caminho de rejeicao independente, sem remover o hold.
set local role cbn_retention_operator;
select app_private.retention_apply_legal_hold(
  'c3000000-0000-4000-8000-000000000002', 'SYNTHETIC_SECOND_REVIEW', 'identity-v1'
);
select app_private.retention_request_hold_removal(
  'c3000000-0000-4000-8000-000000000002', 'identity-v1'
);
reset role;
set local role cbn_hold_reviewer;
select app_private.hold_review_removal(
  'c3000000-0000-4000-8000-000000000002', 'REJECT',
  'SYNTHETIC_REJECTED', 'identity-v1'
);
reset role;

do $$
begin
  if not exists (
    select 1 from app_private.retention_controls
    where id = 'c3000000-0000-4000-8000-000000000002'
      and legal_hold_active and legal_hold_removal_requested_at is null
  ) then raise exception 'rejeicao nao preservou hold'; end if;
end
$$;

-- Fixture de descarte de payload, preparada por um papel e concluida por outro.
insert into public.technical_operations (
  operation_id, client_id, product, action, session_alias, state
) values (
  'c4000000-0000-4000-8000-000000000004',
  'c1000000-0000-4000-8000-000000000004', 'CLT', 'CONSULTAR',
  'synthetic-delete', 'COMPLETED'
);
insert into app_private.protected_payloads (
  id, client_id, operation_id, payload_type, ciphertext,
  encryption_key_ref, encryption_version, retention_until
) values (
  'c5000000-0000-4000-8000-000000000004',
  'c1000000-0000-4000-8000-000000000004',
  'c4000000-0000-4000-8000-000000000004', 'SYNTHETIC_IDENTITY_PAYLOAD',
  decode('04', 'hex'), 'local-test-only', 'local-v1', now() - interval '2 days'
);
insert into app_private.retention_controls (
  id, policy_id, entity_type, entity_id, client_id, operation_id, purpose_code,
  retention_until, deletion_eligible_at, status, process_version, review_required
) values (
  'c3000000-0000-4000-8000-000000000004', 'c2000000-0000-4000-8000-000000000001',
  'PROTECTED_PAYLOAD', 'c5000000-0000-4000-8000-000000000004',
  'c1000000-0000-4000-8000-000000000004', 'c4000000-0000-4000-8000-000000000004',
  'SYNTHETIC_TEST', now() - interval '2 days', now() - interval '1 day',
  'ELIGIBLE', 'identity-v1', false
);

set local role cbn_retention_operator;
do $$
declare inventory_count integer;
begin
  select count(*) into inventory_count from app_private.retention_prepare_deletion(
    array['c3000000-0000-4000-8000-000000000004'::uuid],
    'synthetic-local-explicit-ids', 'identity-v1'
  );
  if inventory_count <> 1 then raise exception 'operador nao preparou inventario explicito'; end if;
  perform app_private.retention_cancel_deletion(
    'c3000000-0000-4000-8000-000000000004',
    'SYNTHETIC_RETRY', 'identity-v1'
  );
  select count(*) into inventory_count from app_private.retention_prepare_deletion(
    array['c3000000-0000-4000-8000-000000000004'::uuid],
    'synthetic-local-explicit-ids', 'identity-v1'
  );
  if inventory_count <> 1 then raise exception 'operador nao repreparou inventario explicito'; end if;
end
$$;
reset role;

set local role cbn_deletion_executor;
select app_private.retention_complete_deletion(
  'c3000000-0000-4000-8000-000000000004', true, 'identity-v1'
);
do $$
begin
  begin
    perform * from app_private.retention_prepare_deletion(
      array['c3000000-0000-4000-8000-000000000004'::uuid],
      'synthetic-local-explicit-ids', 'identity-v1');
    raise exception 'executor preparou exclusao';
  exception when insufficient_privilege then null; end;
end
$$;
reset role;

do $$
declare
  expected record;
begin
  if exists (
    select 1 from app_private.protected_payloads
    where id = 'c5000000-0000-4000-8000-000000000004'
  ) or not exists (
    select 1 from app_private.retention_controls
    where id = 'c3000000-0000-4000-8000-000000000004'
      and status = 'DELETED' and deleted_at is not null
  ) then raise exception 'executor nao concluiu descarte controlado'; end if;

  if exists (
    select 1 from audit.events
    where metadata ->> 'identity_model' = 'BKL016_BACKEND_IDENTITY_V1'
      and metadata::text ~* '(https?://|[0-9]{11}|cpf|telefone|address|password|token|secret|session|ciphertext)'
  ) then raise exception 'auditoria tecnica contem dado proibido'; end if;

  for expected in
    select * from (values
      ('CBN_GATEWAY_BACKEND', 'GATEWAY_OPERATION_CREATED'),
      ('CBN_RETENTION_OPERATOR', 'RETENTION_EVALUATED_BY_OPERATOR'),
      ('CBN_RETENTION_OPERATOR', 'CLIENT_ANONYMIZED_BY_OPERATOR'),
      ('CBN_RETENTION_OPERATOR', 'LEGAL_HOLD_APPLIED_BY_OPERATOR'),
      ('CBN_RETENTION_OPERATOR', 'LEGAL_HOLD_REMOVAL_REQUESTED_BY_OPERATOR'),
      ('CBN_RETENTION_OPERATOR', 'DELETION_PREPARED_BY_OPERATOR'),
      ('CBN_RETENTION_OPERATOR', 'DELETION_CANCELLED_BY_OPERATOR'),
      ('CBN_HOLD_REVIEWER', 'LEGAL_HOLD_REMOVAL_APPROVED_BY_REVIEWER'),
      ('CBN_HOLD_REVIEWER', 'LEGAL_HOLD_REMOVAL_REJECTED_BY_REVIEWER'),
      ('CBN_DELETION_EXECUTOR', 'DELETION_COMPLETED_BY_EXECUTOR')
    ) as required_event(technical_role, event_type)
  loop
    if not exists (
      select 1 from audit.events e
      where e.event_type = expected.event_type
        and e.metadata ->> 'technical_role' = expected.technical_role
        and e.metadata ->> 'identity_model' = 'BKL016_BACKEND_IDENTITY_V1'
        and e.metadata ? 'reason_code'
        and e.metadata ? 'process_version'
    ) then
      raise exception 'evento de identidade ausente/incorreto: % %',
        expected.technical_role, expected.event_type;
    end if;
  end loop;

  if exists (
    select 1 from audit.events
    where metadata ->> 'identity_model' = 'BKL016_BACKEND_IDENTITY_V1'
      and event_type = 'LEGAL_HOLD_REMOVAL_REJECTED'
  ) then raise exception 'evento generico duplicou auditoria do revisor'; end if;

  if not exists (
    select 1 from audit.events
    where event_type = 'CLIENT_ANONYMIZED_BY_OPERATOR'
      and metadata ->> 'technical_role' = 'CBN_RETENTION_OPERATOR'
      and allowed = false
      and metadata ->> 'reason_code' = 'NO_CHANGES'
  ) then raise exception 'zero alteracoes foi registrado como sucesso'; end if;

  if not exists (
    select 1 from audit.events
    where event_type = 'LEGAL_HOLD_REMOVAL_REJECTED_BY_REVIEWER'
      and metadata ->> 'technical_role' = 'CBN_HOLD_REVIEWER'
      and allowed = false
  ) or not exists (
    select 1 from audit.events
    where event_type = 'LEGAL_HOLD_REMOVAL_APPROVED_BY_REVIEWER'
      and metadata ->> 'technical_role' = 'CBN_HOLD_REVIEWER'
      and allowed = true
  ) or not exists (
    select 1 from audit.events
    where event_type = 'DELETION_COMPLETED_BY_EXECUTOR'
      and metadata ->> 'technical_role' = 'CBN_DELETION_EXECUTOR'
      and allowed = true
  ) then raise exception 'resultado allowed incorreto na auditoria de identidade'; end if;

  if (select count(*) from audit.events
      where event_type = 'RETENTION_EVALUATED_BY_OPERATOR') <> 1
     or (select count(*) from audit.events
      where event_type = 'CLIENT_ANONYMIZED_BY_OPERATOR') <> 2
     or (select count(*) from audit.events
      where event_type = 'LEGAL_HOLD_APPLIED_BY_OPERATOR') <> 2
     or (select count(*) from audit.events
      where event_type = 'LEGAL_HOLD_REMOVAL_REQUESTED_BY_OPERATOR') <> 2
     or (select count(*) from audit.events
      where event_type = 'DELETION_PREPARED_BY_OPERATOR') <> 2
     or (select count(*) from audit.events
      where event_type = 'DELETION_CANCELLED_BY_OPERATOR') <> 1
     or (select count(*) from audit.events
      where event_type = 'LEGAL_HOLD_REMOVAL_APPROVED_BY_REVIEWER') <> 1
     or (select count(*) from audit.events
      where event_type = 'LEGAL_HOLD_REMOVAL_REJECTED_BY_REVIEWER') <> 1
     or (select count(*) from audit.events
      where event_type = 'DELETION_COMPLETED_BY_EXECUTOR') <> 1 then
    raise exception 'auditoria duplicada ou ausente apos falha tecnica';
  end if;
end
$$;

select 'BKL-016 backend identity and privilege checks passed' as result;

rollback;
