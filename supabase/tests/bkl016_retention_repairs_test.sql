\set ON_ERROR_STOP on

begin;

insert into app_private.retention_policies (
  id, policy_code, data_category, purpose_code, retention_period,
  policy_status, review_required
) values (
  'b1000000-0000-4000-8000-000000000001', 'SYNTHETIC_REPAIR_POLICY',
  'SYNTHETIC_CUSTOMER_DATA', 'SYNTHETIC_TEST', interval '1 day', 'ACTIVE', false
);

insert into public.clients (id, display_name, phone_masked, cpf_masked, journey_state)
values
  ('b2000000-0000-4000-8000-000000000001', '[SYNTHETIC TEST] Scope', '+55 ** *****-0201', '***.***.***-21', 'NEW'),
  ('b2000000-0000-4000-8000-000000000002', '[SYNTHETIC TEST] Children', '+55 ** *****-0202', '***.***.***-22', 'NEW');

insert into public.technical_operations (
  operation_id, client_id, product, action, session_alias, state
) values
  ('b3000000-0000-4000-8000-000000000001', 'b2000000-0000-4000-8000-000000000001',
   'FGTS', 'CONSULTAR', 'synthetic-scope', 'COMPLETED'),
  ('b3000000-0000-4000-8000-000000000002', 'b2000000-0000-4000-8000-000000000002',
   'CLT', 'CONSULTAR', 'synthetic-child', 'COMPLETED');

insert into app_private.protected_payloads (
  id, client_id, operation_id, payload_type, ciphertext,
  encryption_key_ref, encryption_version, retention_until
) values
  ('b4000000-0000-4000-8000-000000000001', 'b2000000-0000-4000-8000-000000000001',
   'b3000000-0000-4000-8000-000000000001', 'SYNTHETIC_SCOPE_PAYLOAD', decode('01', 'hex'),
   'local-test-only', 'local-v1', now() - interval '2 days');

insert into app_private.protected_file_refs (
  id, client_id, operation_id, bucket_name, object_key,
  encryption_key_ref, encryption_version, retention_until
) values
  ('b5000000-0000-4000-8000-000000000001', 'b2000000-0000-4000-8000-000000000001',
   'b3000000-0000-4000-8000-000000000001', 'cbn-temporary-private',
   'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb/aaaaaaaaaaaaaaaa',
   'local-test-only', 'local-v1', now() - interval '2 days'),
  ('b5000000-0000-4000-8000-000000000002', 'b2000000-0000-4000-8000-000000000002',
   'b3000000-0000-4000-8000-000000000002', 'cbn-temporary-private',
   'cccccccc-cccc-4ccc-8ccc-cccccccccccc/bbbbbbbbbbbbbbbb',
   'local-test-only', 'local-v1', now() - interval '2 days');

insert into app_private.client_sensitive_data (
  client_id, cpf_ciphertext, encryption_key_ref, encryption_version, retention_until
) values ('b2000000-0000-4000-8000-000000000002', decode('02', 'hex'),
  'local-test-only', 'local-v1', now() - interval '2 days');

insert into public.interactions (
  id, client_id, product, channel, direction, event_type,
  external_message_ref, event_summary_masked, automation_ref
) values ('b6000000-0000-4000-8000-000000000001',
  'b2000000-0000-4000-8000-000000000002', 'CLT', 'SYNTHETIC', 'INTERNAL',
  'SYNTHETIC_EVENT', 'synthetic-message-ref', '[SYNTHETIC MASKED]', 'synthetic-flow');

insert into public.pending_items (
  id, client_id, product, pending_type, pending_action,
  pending_reason_masked, resolution_masked
) values ('b7000000-0000-4000-8000-000000000001',
  'b2000000-0000-4000-8000-000000000002', 'CLT', 'SYNTHETIC_REVIEW',
  'SYNTHETIC_ACTION', '[SYNTHETIC MASKED]', '[SYNTHETIC MASKED]');

insert into app_private.retention_controls (
  id, policy_id, entity_type, entity_id, client_id, operation_id, purpose_code,
  retention_until, deletion_eligible_at, status, process_version, review_required
) values
  ('b8000000-0000-4000-8000-000000000001', 'b1000000-0000-4000-8000-000000000001',
   'CLIENT', 'b2000000-0000-4000-8000-000000000001', 'b2000000-0000-4000-8000-000000000001', null,
   'SYNTHETIC_TEST', now() - interval '2 days', now() - interval '1 day', 'ELIGIBLE', 'repair-v1', false),
  ('b8000000-0000-4000-8000-000000000002', 'b1000000-0000-4000-8000-000000000001',
   'PROTECTED_PAYLOAD', 'b4000000-0000-4000-8000-000000000001', 'b2000000-0000-4000-8000-000000000001',
   'b3000000-0000-4000-8000-000000000001', 'SYNTHETIC_TEST', now() - interval '2 days',
   now() - interval '1 day', 'ELIGIBLE', 'repair-v1', false),
  ('b8000000-0000-4000-8000-000000000003', 'b1000000-0000-4000-8000-000000000001',
   'PROTECTED_FILE', 'b5000000-0000-4000-8000-000000000001', 'b2000000-0000-4000-8000-000000000001',
   'b3000000-0000-4000-8000-000000000001', 'SYNTHETIC_TEST', now() - interval '2 days',
   now() - interval '1 day', 'ELIGIBLE', 'repair-v1', false),
  ('b8000000-0000-4000-8000-000000000004', 'b1000000-0000-4000-8000-000000000001',
   'CLIENT', 'b2000000-0000-4000-8000-000000000002', 'b2000000-0000-4000-8000-000000000002', null,
   'SYNTHETIC_TEST', now() - interval '2 days', now() - interval '1 day', 'ELIGIBLE', 'repair-v1', false);

do $$
declare result_count integer;
declare changed_count integer;
begin
  -- Dependencia filha exige politica propria; nenhuma marcacao parcial ocorre.
  changed_count := app_private.anonymize_clients(
    array['b8000000-0000-4000-8000-000000000004'::uuid], 'repair-v1'
  );
  if changed_count <> 0
     or (select anonymized_at from public.clients where id = 'b2000000-0000-4000-8000-000000000002') is not null
     or not exists (select 1 from app_private.client_sensitive_data where client_id = 'b2000000-0000-4000-8000-000000000002') then
    raise exception 'anonimizacao com dependencia nao falhou fechada';
  end if;
  if not exists (select 1 from audit.events where event_type = 'ANONYMIZATION_DENIED'
    and entity_id = 'b2000000-0000-4000-8000-000000000002' and allowed = false)
    or not exists (select 1 from audit.events where event_type = 'RETENTION_EVALUATED'
    and entity_id = 'b2000000-0000-4000-8000-000000000002' and allowed = false) then
    raise exception 'auditoria persistente da dependencia ausente';
  end if;

  -- Hold superior de CLIENT protege payload e arquivo sem replicacao manual.
  perform app_private.apply_legal_hold(
    'b8000000-0000-4000-8000-000000000001', 'SYNTHETIC_SCOPE', 'TECHNICAL_REQUESTER', 'repair-v1'
  );
  select count(*) into result_count from app_private.prepare_retention_deletion(
    array['b8000000-0000-4000-8000-000000000002'::uuid],
    'synthetic-local-explicit-ids', 'repair-v1'
  );
  if result_count <> 0 then raise exception 'hold do cliente nao bloqueou payload'; end if;
  select count(*) into result_count from app_private.prepare_retention_deletion(
    array['b8000000-0000-4000-8000-000000000003'::uuid],
    'synthetic-local-explicit-ids', 'repair-v1'
  );
  if result_count <> 0 then raise exception 'hold do cliente nao bloqueou arquivo'; end if;
  if not exists (select 1 from app_private.protected_payloads where id = 'b4000000-0000-4000-8000-000000000001')
     or not exists (select 1 from app_private.protected_file_refs where id = 'b5000000-0000-4000-8000-000000000001') then
    raise exception 'entidade foi removida durante hold superior';
  end if;
  perform app_private.request_legal_hold_removal(
    'b8000000-0000-4000-8000-000000000001', 'TECHNICAL_REQUESTER', 'repair-v1'
  );
  begin
    perform app_private.remove_legal_hold(
      'b8000000-0000-4000-8000-000000000001', 'TECHNICAL_REQUESTER', 'repair-v1'
    );
    raise exception 'mesmo ator aprovou remocao de hold';
  exception when insufficient_privilege then null;
  end;
  perform app_private.remove_legal_hold(
    'b8000000-0000-4000-8000-000000000001', 'TECHNICAL_APPROVER', 'repair-v1'
  );

  -- Hold aplicado depois do prepare bloqueia a conclusao e preserva a referencia.
  perform * from app_private.prepare_retention_deletion(
    array['b8000000-0000-4000-8000-000000000003'::uuid],
    'synthetic-local-explicit-ids', 'repair-v1'
  );
  perform app_private.apply_legal_hold(
    'b8000000-0000-4000-8000-000000000001', 'SYNTHETIC_LATE_HOLD', 'TECHNICAL_REQUESTER', 'repair-v1'
  );
  perform app_private.complete_retention_deletion(
    'b8000000-0000-4000-8000-000000000003', true, 'repair-v1'
  );
  if (select status from app_private.retention_controls where id = 'b8000000-0000-4000-8000-000000000003') <> 'DELETION_PENDING'
     or not exists (select 1 from app_private.protected_file_refs where id = 'b5000000-0000-4000-8000-000000000001') then
    raise exception 'hold tardio nao bloqueou complete';
  end if;
  if not exists (select 1 from audit.events where event_type = 'DELETION_DENIED'
    and entity_id = 'b5000000-0000-4000-8000-000000000001' and allowed = false) then
    raise exception 'negacao tardia nao persistiu';
  end if;
end
$$;

-- Remove a dependencia de arquivo do segundo cliente e comprova anonimização integral.
delete from app_private.protected_file_refs where id = 'b5000000-0000-4000-8000-000000000002';

do $$
declare changed_count integer;
begin
  changed_count := app_private.anonymize_clients(
    array['b8000000-0000-4000-8000-000000000004'::uuid], 'repair-v1'
  );
  if changed_count <> 1 then raise exception 'anonimizacao limpa foi recusada'; end if;
  if exists (select 1 from app_private.client_sensitive_data where client_id = 'b2000000-0000-4000-8000-000000000002')
     or exists (select 1 from app_private.protected_payloads where client_id = 'b2000000-0000-4000-8000-000000000002')
     or exists (select 1 from app_private.protected_file_refs where client_id = 'b2000000-0000-4000-8000-000000000002')
     or exists (select 1 from public.interactions where client_id = 'b2000000-0000-4000-8000-000000000002'
       and num_nonnulls(external_message_ref, event_summary_masked, automation_ref) > 0)
     or exists (select 1 from public.pending_items where client_id = 'b2000000-0000-4000-8000-000000000002'
       and num_nonnulls(pending_reason_masked, resolution_masked, assigned_user_id) > 0) then
    raise exception 'inventario reteve dado incompativel';
  end if;
  begin
    insert into app_private.client_sensitive_data (
      client_id, cpf_ciphertext, encryption_key_ref, encryption_version
    ) values ('b2000000-0000-4000-8000-000000000002', decode('03', 'hex'),
      'local-test-only', 'local-v1');
    raise exception 'reinsercao privada foi aceita';
  exception when sqlstate '55000' then null;
  end;
  begin
    insert into public.interactions (
      client_id, channel, direction, event_type, event_summary_masked
    ) values ('b2000000-0000-4000-8000-000000000002', 'SYNTHETIC', 'INTERNAL',
      'SYNTHETIC_EVENT', '[SYNTHETIC MASKED]');
    raise exception 'novo filho publico foi aceito';
  exception when sqlstate '55000' then null;
  end;
end
$$;

-- Protecao de proposal_sensitive_data para cliente ja anonimizado, mesmo com
-- proposta preexistente (fixture base exclusivamente sintetica).
update public.clients set display_name = '[ANONYMIZED]', phone_masked = null,
  cpf_masked = null, lead_source = null, consultation_consent_source = null,
  journey_state = 'ANONYMIZED', anonymized_at = now()
where id = '10000000-0000-4000-8000-000000000001';

do $$
begin
  begin
    insert into app_private.proposal_sensitive_data (
      proposal_id, bank_data_ciphertext, encryption_key_ref, encryption_version
    ) values ('60000000-0000-4000-8000-000000000001', decode('04', 'hex'),
      'local-test-only', 'local-v1');
    raise exception 'proposta sensivel de cliente anonimizado foi aceita';
  exception when sqlstate '55000' then null;
  end;
end
$$;

select 'BKL-016 retention repair checks passed' as result;

rollback;
