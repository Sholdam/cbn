\set ON_ERROR_STOP on

begin;

insert into app_private.retention_policies (
  id, policy_code, data_category, purpose_code, retention_period,
  policy_status, review_required
) values (
  'a1000000-0000-4000-8000-000000000001',
  'SYNTHETIC_LOCAL_POLICY', 'SYNTHETIC_CUSTOMER_DATA', 'SYNTHETIC_TEST',
  interval '1 day', 'ACTIVE', false
);

insert into public.clients (id, display_name, phone_masked, cpf_masked, journey_state)
values
  ('a2000000-0000-4000-8000-000000000001', '[SYNTHETIC TEST] Future', '+55 ** *****-0001', '***.***.***-01', 'NEW'),
  ('a2000000-0000-4000-8000-000000000002', '[SYNTHETIC TEST] Expired', '+55 ** *****-0002', '***.***.***-02', 'NEW');

insert into app_private.client_sensitive_data (
  client_id, cpf_ciphertext, encryption_key_ref, encryption_version, retention_until
) values
  ('a2000000-0000-4000-8000-000000000001', decode('53594e54484554494331', 'hex'), 'local-test-only', 'local-v1', now() + interval '1 day'),
  ('a2000000-0000-4000-8000-000000000002', decode('53594e54484554494332', 'hex'), 'local-test-only', 'local-v1', now() - interval '1 day');

insert into app_private.retention_controls (
  id, policy_id, entity_type, entity_id, client_id, purpose_code,
  retention_until, deletion_eligible_at, process_version, review_required
) values
  ('a3000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001',
   'CLIENT', 'a2000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001',
   'SYNTHETIC_TEST', now() + interval '1 day', now() + interval '2 days', 'test-v1', false),
  ('a3000000-0000-4000-8000-000000000002', 'a1000000-0000-4000-8000-000000000001',
   'CLIENT', 'a2000000-0000-4000-8000-000000000002', 'a2000000-0000-4000-8000-000000000002',
   'SYNTHETIC_TEST', now() - interval '2 days', now() - interval '1 day', 'test-v1', false);

do $$
declare processed integer;
begin
  if app_private.evaluate_retention_action(
    'a3000000-0000-4000-8000-000000000001', 'ANONYMIZE', 'test-v1'
  ) then raise exception 'retencao futura foi permitida'; end if;

  begin
    perform app_private.anonymize_clients(
      array['a3000000-0000-4000-8000-000000000001'::uuid], 'test-v1'
    );
    raise exception 'retencao futura foi anonimizada';
  exception when sqlstate '55000' then null;
  end;

  perform app_private.apply_legal_hold(
    'a3000000-0000-4000-8000-000000000002', 'SYNTHETIC_REVIEW', 'TECHNICAL_TEST', 'test-v1'
  );
  if app_private.evaluate_retention_action(
    'a3000000-0000-4000-8000-000000000002', 'ANONYMIZE', 'test-v1'
  ) then raise exception 'legal hold permitiu anonimizar'; end if;
  begin
    perform app_private.anonymize_clients(
      array['a3000000-0000-4000-8000-000000000002'::uuid], 'test-v1'
    );
    raise exception 'legal hold nao bloqueou anonimizacao';
  exception when sqlstate '55000' then null;
  end;
  begin
    perform app_private.remove_legal_hold(
      'a3000000-0000-4000-8000-000000000002', 'TECHNICAL_TEST', 'test-v1'
    );
    raise exception 'legal hold foi removido sem solicitacao';
  exception when sqlstate '55000' then null;
  end;
  perform app_private.request_legal_hold_removal(
    'a3000000-0000-4000-8000-000000000002', 'TECHNICAL_TEST', 'test-v1'
  );
  perform app_private.remove_legal_hold(
    'a3000000-0000-4000-8000-000000000002', 'TECHNICAL_REVIEWER', 'test-v1'
  );
  if not app_private.evaluate_retention_action(
    'a3000000-0000-4000-8000-000000000002', 'ANONYMIZE', 'test-v1'
  ) then raise exception 'hold removido nao liberou avaliacao'; end if;

  processed := app_private.anonymize_clients(
    array['a3000000-0000-4000-8000-000000000002'::uuid], 'test-v1'
  );
  if processed <> 1 then raise exception 'anonimizacao nao processou fixture'; end if;
  processed := app_private.anonymize_clients(
    array['a3000000-0000-4000-8000-000000000002'::uuid], 'test-v1'
  );
  if processed <> 0 then raise exception 'segunda anonimizacao nao foi idempotente'; end if;
  if exists (select 1 from app_private.client_sensitive_data where client_id = 'a2000000-0000-4000-8000-000000000002')
     or exists (
       select 1 from public.clients
       where id = 'a2000000-0000-4000-8000-000000000002'
         and (display_name <> '[ANONYMIZED]' or phone_masked is not null or cpf_masked is not null)
     ) then raise exception 'identificadores nao foram neutralizados'; end if;
  begin
    update public.clients set display_name = '[SYNTHETIC TEST] Revived'
    where id = 'a2000000-0000-4000-8000-000000000002';
    raise exception 'cliente anonimizado foi reanimado';
  exception when sqlstate '55000' then null;
  end;

  begin
    perform app_private.anonymize_clients(array[]::uuid[], 'test-v1');
    raise exception 'lista vazia foi aceita';
  exception when invalid_parameter_value then null;
  end;
end
$$;

insert into public.technical_operations (
  operation_id, client_id, product, action, session_alias, state
) values (
  'a4000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001', 'FGTS', 'CONSULTAR',
  'synthetic-retention-test', 'COMPLETED'
);

insert into app_private.protected_payloads (
  id, client_id, operation_id, payload_type, ciphertext,
  encryption_key_ref, encryption_version, retention_until
) values (
  'a5000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'a4000000-0000-4000-8000-000000000001', 'SYNTHETIC_RETENTION',
  decode('53594e544845544943', 'hex'), 'local-test-only', 'local-v1', now() - interval '2 days'
);

insert into app_private.protected_file_refs (
  id, client_id, operation_id, bucket_name, object_key,
  encryption_key_ref, encryption_version, retention_until
) values (
  'a6000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'a4000000-0000-4000-8000-000000000001',
  'cbn-temporary-private', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/ffffffffffffffff',
  'local-test-only', 'local-v1', now() - interval '2 days'
);

insert into app_private.retention_controls (
  id, policy_id, entity_type, entity_id, client_id, operation_id, purpose_code,
  retention_until, deletion_eligible_at, status, process_version, review_required
) values
  ('a7000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001',
   'PROTECTED_PAYLOAD', 'a5000000-0000-4000-8000-000000000001',
   'a2000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000001',
   'SYNTHETIC_TEST', now() - interval '2 days', now() - interval '1 day', 'ELIGIBLE', 'test-v1', false),
  ('a7000000-0000-4000-8000-000000000002', 'a1000000-0000-4000-8000-000000000001',
   'PROTECTED_FILE', 'a6000000-0000-4000-8000-000000000001',
   'a2000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000001',
   'SYNTHETIC_TEST', now() - interval '2 days', now() - interval '1 day', 'ELIGIBLE', 'test-v1', false);

do $$
declare inventory_count integer;
begin
  perform app_private.apply_legal_hold(
    'a7000000-0000-4000-8000-000000000002', 'SYNTHETIC_REVIEW', 'TECHNICAL_TEST', 'test-v1'
  );
  if app_private.evaluate_retention_action(
    'a7000000-0000-4000-8000-000000000002', 'DELETE', 'test-v1'
  ) then raise exception 'legal hold permitiu exclusao'; end if;
  begin
    delete from app_private.protected_file_refs where id = 'a6000000-0000-4000-8000-000000000001';
    raise exception 'legal hold permitiu exclusao direta do arquivo';
  exception when sqlstate '55000' then null;
  end;
  begin
    perform * from app_private.prepare_retention_deletion(
      array['a7000000-0000-4000-8000-000000000002'::uuid],
      'synthetic-local-explicit-ids', 'test-v1'
    );
    raise exception 'legal hold permitiu preparar exclusao';
  exception when sqlstate '55000' then null;
  end;
  perform app_private.request_legal_hold_removal(
    'a7000000-0000-4000-8000-000000000002', 'TECHNICAL_TEST', 'test-v1'
  );
  perform app_private.remove_legal_hold(
    'a7000000-0000-4000-8000-000000000002', 'TECHNICAL_REVIEWER', 'test-v1'
  );

  begin
    perform * from app_private.prepare_retention_deletion(null, 'synthetic-local-explicit-ids', 'test-v1');
    raise exception 'IDs nulos foram aceitos';
  exception when invalid_parameter_value then null;
  end;
  begin
    perform * from app_private.prepare_retention_deletion(array[]::uuid[], 'synthetic-local-explicit-ids', 'test-v1');
    raise exception 'lista vazia foi aceita';
  exception when invalid_parameter_value then null;
  end;
  begin
    perform * from app_private.prepare_retention_deletion(
      array_fill('a7000000-0000-4000-8000-000000000002'::uuid, array[11]),
      'synthetic-local-explicit-ids', 'test-v1'
    );
    raise exception 'lote acima do limite foi aceito';
  exception when invalid_parameter_value then null;
  end;
  begin
    perform * from app_private.prepare_retention_deletion(
      array['a7000000-0000-4000-8000-000000000002'::uuid], 'confirm-all', 'test-v1'
    );
    raise exception 'confirmacao humana incorreta foi aceita';
  exception when insufficient_privilege then null;
  end;

  select count(*) into inventory_count from app_private.prepare_retention_deletion(
    array['a7000000-0000-4000-8000-000000000002'::uuid],
    'synthetic-local-explicit-ids', 'test-v1'
  );
  if inventory_count <> 1 then raise exception 'inventario explicito incorreto'; end if;
  begin
    perform app_private.complete_retention_deletion(
      'a7000000-0000-4000-8000-000000000002', false, 'test-v1'
    );
    raise exception 'falha de Storage marcou exclusao concluida';
  exception when sqlstate '55000' then null;
  end;
  if (select status from app_private.retention_controls where id = 'a7000000-0000-4000-8000-000000000002') <> 'DELETION_PENDING'
     or not exists (select 1 from app_private.protected_file_refs where id = 'a6000000-0000-4000-8000-000000000001') then
    raise exception 'falha parcial corrompeu estado anterior';
  end if;
  perform app_private.cancel_retention_deletion(
    'a7000000-0000-4000-8000-000000000002', 'STORAGE_DELETE_FAILED', 'test-v1'
  );
  perform * from app_private.prepare_retention_deletion(
    array['a7000000-0000-4000-8000-000000000002'::uuid],
    'synthetic-local-explicit-ids', 'test-v1'
  );
  perform app_private.complete_retention_deletion(
    'a7000000-0000-4000-8000-000000000002', true, 'test-v1'
  );
  if exists (select 1 from app_private.protected_file_refs where id = 'a6000000-0000-4000-8000-000000000001')
     or (select status from app_private.retention_controls where id = 'a7000000-0000-4000-8000-000000000002') <> 'DELETED' then
    raise exception 'exclusao explicita nao concluiu';
  end if;
end
$$;

-- Simula dependencia ativa do payload sem introduzir PII.
update public.technical_operations
set protected_log_ref = 'a5000000-0000-4000-8000-000000000001'
where operation_id = 'a4000000-0000-4000-8000-000000000001';

do $$
begin
  begin
    perform * from app_private.prepare_retention_deletion(
      array['a7000000-0000-4000-8000-000000000001'::uuid],
      'synthetic-local-explicit-ids', 'test-v1'
    );
    raise exception 'dependencia ativa foi ignorada';
  exception when foreign_key_violation then null;
  end;
  if exists (
    select 1 from audit.events
    where (event_type like '%RETENTION%' or event_type like '%DELETION%' or event_type like '%LEGAL_HOLD%')
      and metadata::text ~ '(https?://|[0-9]{11}|token|secret|password|session)'
  ) then raise exception 'auditoria contem dado proibido'; end if;

  if has_table_privilege('anon', 'app_private.retention_controls', 'SELECT')
     or has_table_privilege('authenticated', 'app_private.retention_controls', 'SELECT')
     or has_function_privilege('anon', 'app_private.anonymize_clients(uuid[],text)', 'EXECUTE')
     or has_function_privilege('authenticated', 'app_private.prepare_retention_deletion(uuid[],text,text)', 'EXECUTE') then
    raise exception 'RLS/grants privados foram ampliados';
  end if;
end
$$;

select 'BKL-016 retention and legal hold checks passed' as result;

rollback;
