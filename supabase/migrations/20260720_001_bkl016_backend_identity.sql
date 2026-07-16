begin;

-- BKL-016: identidades tecnicas sem LOGIN. Nenhuma credencial e criada aqui.
do $$
declare
  role_name text;
begin
  foreach role_name in array array[
    'cbn_gateway_backend',
    'cbn_retention_operator',
    'cbn_hold_reviewer',
    'cbn_deletion_executor'
  ] loop
    if exists (select 1 from pg_catalog.pg_roles where rolname = role_name) then
      raise exception using errcode = '42710', message = 'backend_identity_role_already_exists';
    end if;
    execute format(
      'create role %I nologin nosuperuser nocreatedb nocreaterole noinherit noreplication nobypassrls',
      role_name
    );
  end loop;
end
$$;

comment on role cbn_gateway_backend is
  'BKL-016: operacoes comuns do Gateway somente por wrappers controlados.';
comment on role cbn_retention_operator is
  'BKL-016: avaliacao, anonimizacao, hold e preparacao/cancelamento de descarte.';
comment on role cbn_hold_reviewer is
  'BKL-016: revisao independente de solicitacao de remocao de legal hold.';
comment on role cbn_deletion_executor is
  'BKL-016: conclusao controlada de descarte depois de ausencia do Storage.';

revoke all on schema public, app_private, audit from
  cbn_gateway_backend, cbn_retention_operator, cbn_hold_reviewer, cbn_deletion_executor;
revoke all on all tables in schema public, app_private, audit from
  cbn_gateway_backend, cbn_retention_operator, cbn_hold_reviewer, cbn_deletion_executor;
revoke all on all sequences in schema public, app_private, audit from
  cbn_gateway_backend, cbn_retention_operator, cbn_hold_reviewer, cbn_deletion_executor;
revoke all on all functions in schema public, app_private, audit from
  cbn_gateway_backend, cbn_retention_operator, cbn_hold_reviewer, cbn_deletion_executor;
revoke execute on all functions in schema app_private, audit from public;
alter default privileges in schema app_private, audit
  revoke execute on functions from public;

grant usage on schema app_private to
  cbn_gateway_backend, cbn_retention_operator, cbn_hold_reviewer, cbn_deletion_executor;

create or replace function audit.record_backend_identity_event(
  p_technical_role text,
  p_event_type text,
  p_entity_type text,
  p_entity_id text,
  p_operation_id uuid,
  p_purpose_code text,
  p_allowed boolean,
  p_reason_code text,
  p_process_version text
) returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_technical_role not in (
      'CBN_GATEWAY_BACKEND', 'CBN_RETENTION_OPERATOR',
      'CBN_HOLD_REVIEWER', 'CBN_DELETION_EXECUTOR'
    )
    or p_event_type !~ '^[A-Z0-9_:-]{3,80}$'
    or p_entity_type !~ '^[A-Z0-9_:-]{2,80}$'
    or p_entity_id !~ '^[A-Za-z0-9_:-]{1,120}$'
    or p_purpose_code !~ '^[A-Z0-9_:-]{3,80}$'
    or p_reason_code !~ '^[A-Z0-9_:-]{3,80}$'
    or p_process_version !~ '^[A-Za-z0-9._:-]{1,40}$' then
    raise exception using errcode = '22023', message = 'backend_audit_metadata_rejected';
  end if;

  insert into audit.events (
    origin, event_type, entity_type, entity_id, operation_id,
    allowed, purpose_code, metadata
  ) values (
    'gateway', p_event_type, p_entity_type, p_entity_id, p_operation_id,
    p_allowed, p_purpose_code,
    jsonb_build_object(
      'technical_role', p_technical_role,
      'reason_code', p_reason_code,
      'process_version', p_process_version,
      'identity_model', 'BKL016_BACKEND_IDENTITY_V1'
    )
  );
end;
$$;

revoke all on function audit.record_backend_identity_event(
  text, text, text, text, uuid, text, boolean, text, text
) from public, anon, authenticated,
  cbn_gateway_backend, cbn_retention_operator, cbn_hold_reviewer, cbn_deletion_executor;

create or replace function app_private.gateway_create_operation(
  p_operation_id uuid,
  p_client_id uuid,
  p_product public.credit_product,
  p_action text,
  p_session_alias text,
  p_gateway_version text
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_operation_id is null or p_client_id is null
     or p_action not in ('CONSULTAR', 'CRIAR_PROPOSTA', 'CONSULTAR_STATUS', 'REENVIAR_LINK')
     or p_session_alias !~ '^[A-Za-z0-9._:-]{1,80}$'
     or p_gateway_version !~ '^[A-Za-z0-9._:-]{1,40}$' then
    raise exception using errcode = '22023', message = 'gateway_operation_metadata_rejected';
  end if;

  insert into public.technical_operations (
    operation_id, client_id, product, action, session_alias, state,
    gateway_version, started_at
  ) values (
    p_operation_id, p_client_id, p_product, p_action, p_session_alias,
    'RECEIVED', p_gateway_version, now()
  );

  perform audit.record_backend_identity_event(
    'CBN_GATEWAY_BACKEND', 'GATEWAY_OPERATION_CREATED', 'TECHNICAL_OPERATION',
    p_operation_id::text, p_operation_id, 'CREDIT_OPERATION', true,
    'CONTROLLED_WRAPPER', p_gateway_version
  );
  return p_operation_id;
end;
$$;

create or replace function app_private.gateway_update_operation_state(
  p_operation_id uuid,
  p_state text,
  p_current_step text,
  p_outcome_code text,
  p_error_code text,
  p_process_version text
) returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  changed integer;
begin
  if p_operation_id is null
     or p_state not in (
       'RECEIVED', 'LOCK_ACQUIRED', 'COMMAND_PREPARED', 'COMMAND_SENT',
       'WAITING_RESPONSE', 'RESPONSE_RECEIVED', 'NORMALIZED', 'COMPLETED',
       'RETRY_PENDING', 'HUMAN_REVIEW', 'FAILED_FINAL'
     )
     or (p_current_step is not null and p_current_step !~ '^[A-Z0-9_:-]{1,80}$')
     or (p_outcome_code is not null and p_outcome_code !~ '^[A-Z0-9_:-]{1,80}$')
     or (p_error_code is not null and p_error_code !~ '^[A-Z0-9_:-]{1,80}$')
     or p_process_version !~ '^[A-Za-z0-9._:-]{1,40}$' then
    raise exception using errcode = '22023', message = 'gateway_state_metadata_rejected';
  end if;

  update public.technical_operations
  set state = p_state,
      current_step = p_current_step,
      outcome_code = p_outcome_code,
      error_code = p_error_code,
      gateway_version = p_process_version,
      finished_at = case when p_state in ('COMPLETED', 'FAILED_FINAL') then now() else finished_at end
  where operation_id = p_operation_id;
  get diagnostics changed = row_count;
  if changed <> 1 then
    raise exception using errcode = 'P0002', message = 'gateway_operation_not_found';
  end if;

  perform audit.record_backend_identity_event(
    'CBN_GATEWAY_BACKEND', 'GATEWAY_OPERATION_STATE_CHANGED', 'TECHNICAL_OPERATION',
    p_operation_id::text, p_operation_id, 'CREDIT_OPERATION', true,
    p_state, p_process_version
  );
  return true;
end;
$$;

create or replace function app_private.retention_evaluate(
  p_control_id uuid, p_action text, p_process_version text
) returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  return app_private.evaluate_retention_action(p_control_id, p_action, p_process_version);
end;
$$;

create or replace function app_private.retention_apply_legal_hold(
  p_control_id uuid, p_reason_code text, p_process_version text
) returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app_private.apply_legal_hold(
    p_control_id, p_reason_code, 'CBN_RETENTION_OPERATOR', p_process_version
  );
end;
$$;

create or replace function app_private.retention_anonymize_clients(
  p_control_ids uuid[], p_process_version text
) returns integer
language plpgsql
security definer
set search_path = ''
as $$
begin
  return app_private.anonymize_clients(p_control_ids, p_process_version);
end;
$$;

create or replace function app_private.retention_prepare_deletion(
  p_control_ids uuid[], p_confirmation text, p_process_version text
) returns table (
  control_id uuid, entity_type text, entity_id uuid,
  bucket_name text, object_key text
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  return query select * from app_private.prepare_retention_deletion(
    p_control_ids, p_confirmation, p_process_version
  );
end;
$$;

create or replace function app_private.retention_cancel_deletion(
  p_control_id uuid, p_reason_code text, p_process_version text
) returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app_private.cancel_retention_deletion(p_control_id, p_reason_code, p_process_version);
end;
$$;

create or replace function app_private.retention_request_hold_removal(
  p_control_id uuid, p_process_version text
) returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app_private.request_legal_hold_removal(
    p_control_id, 'CBN_RETENTION_OPERATOR', p_process_version
  );
end;
$$;

create or replace function app_private.reject_legal_hold_removal(
  p_control_id uuid, p_actor_ref text, p_reason_code text, p_process_version text
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  c app_private.retention_controls%rowtype;
begin
  if p_actor_ref !~ '^[A-Z0-9_:-]{3,80}$'
     or p_reason_code !~ '^[A-Z0-9_:-]{3,80}$'
     or p_process_version !~ '^[A-Za-z0-9._:-]{1,40}$' then
    raise exception using errcode = '22023', message = 'hold_review_metadata_rejected';
  end if;
  select * into strict c from app_private.retention_controls
  where id = p_control_id for update;
  if not c.legal_hold_active or c.legal_hold_removal_requested_at is null then
    raise exception using errcode = '55000', message = 'legal_hold_explicit_request_required';
  end if;
  if c.legal_hold_removal_requested_by = p_actor_ref then
    raise exception using errcode = '42501', message = 'legal_hold_separation_of_duties_required';
  end if;

  update app_private.retention_controls
  set legal_hold_removal_requested_at = null,
      legal_hold_removal_requested_by = null,
      process_version = p_process_version
  where id = p_control_id;

  perform audit.record_backend_identity_event(
    'CBN_HOLD_REVIEWER', 'LEGAL_HOLD_REMOVAL_REJECTED', c.entity_type,
    c.entity_id::text, c.operation_id, c.purpose_code, false,
    p_reason_code, p_process_version
  );
end;
$$;

create or replace function app_private.hold_review_removal(
  p_control_id uuid, p_decision text, p_reason_code text, p_process_version text
) returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_decision not in ('APPROVE', 'REJECT')
     or p_reason_code !~ '^[A-Z0-9_:-]{3,80}$'
     or p_process_version !~ '^[A-Za-z0-9._:-]{1,40}$' then
    raise exception using errcode = '22023', message = 'hold_review_metadata_rejected';
  end if;
  if p_decision = 'APPROVE' then
    perform app_private.remove_legal_hold(
      p_control_id, 'CBN_HOLD_REVIEWER', p_process_version
    );
    return true;
  elsif p_decision = 'REJECT' then
    perform app_private.reject_legal_hold_removal(
      p_control_id, 'CBN_HOLD_REVIEWER', p_reason_code, p_process_version
    );
    return false;
  end if;
  raise exception using errcode = '22023', message = 'hold_review_decision_rejected';
end;
$$;

create or replace function app_private.retention_complete_deletion(
  p_control_id uuid, p_storage_absence_confirmed boolean, p_process_version text
) returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app_private.complete_retention_deletion(
    p_control_id, p_storage_absence_confirmed, p_process_version
  );
end;
$$;

-- Nenhum wrapper e exposto a papeis web. Funcoes internas continuam privadas.
revoke all on function app_private.gateway_create_operation(uuid, uuid, public.credit_product, text, text, text)
  from public, anon, authenticated, cbn_retention_operator, cbn_hold_reviewer, cbn_deletion_executor;
revoke all on function app_private.gateway_update_operation_state(uuid, text, text, text, text, text)
  from public, anon, authenticated, cbn_retention_operator, cbn_hold_reviewer, cbn_deletion_executor;
revoke all on function app_private.retention_evaluate(uuid, text, text)
  from public, anon, authenticated, cbn_gateway_backend, cbn_hold_reviewer, cbn_deletion_executor;
revoke all on function app_private.retention_apply_legal_hold(uuid, text, text)
  from public, anon, authenticated, cbn_gateway_backend, cbn_hold_reviewer, cbn_deletion_executor;
revoke all on function app_private.retention_anonymize_clients(uuid[], text)
  from public, anon, authenticated, cbn_gateway_backend, cbn_hold_reviewer, cbn_deletion_executor;
revoke all on function app_private.retention_prepare_deletion(uuid[], text, text)
  from public, anon, authenticated, cbn_gateway_backend, cbn_hold_reviewer, cbn_deletion_executor;
revoke all on function app_private.retention_cancel_deletion(uuid, text, text)
  from public, anon, authenticated, cbn_gateway_backend, cbn_hold_reviewer, cbn_deletion_executor;
revoke all on function app_private.retention_request_hold_removal(uuid, text)
  from public, anon, authenticated, cbn_gateway_backend, cbn_hold_reviewer, cbn_deletion_executor;
revoke all on function app_private.reject_legal_hold_removal(uuid, text, text, text)
  from public, anon, authenticated, cbn_gateway_backend, cbn_retention_operator, cbn_hold_reviewer, cbn_deletion_executor;
revoke all on function app_private.hold_review_removal(uuid, text, text, text)
  from public, anon, authenticated, cbn_gateway_backend, cbn_retention_operator, cbn_deletion_executor;
revoke all on function app_private.retention_complete_deletion(uuid, boolean, text)
  from public, anon, authenticated, cbn_gateway_backend, cbn_retention_operator, cbn_hold_reviewer;

grant execute on function app_private.gateway_create_operation(
  uuid, uuid, public.credit_product, text, text, text
) to cbn_gateway_backend;
grant execute on function app_private.gateway_update_operation_state(
  uuid, text, text, text, text, text
) to cbn_gateway_backend;

grant execute on function app_private.retention_evaluate(uuid, text, text),
  app_private.retention_apply_legal_hold(uuid, text, text),
  app_private.retention_anonymize_clients(uuid[], text),
  app_private.retention_prepare_deletion(uuid[], text, text),
  app_private.retention_cancel_deletion(uuid, text, text),
  app_private.retention_request_hold_removal(uuid, text)
to cbn_retention_operator;

grant execute on function app_private.hold_review_removal(uuid, text, text, text)
  to cbn_hold_reviewer;
grant execute on function app_private.retention_complete_deletion(uuid, boolean, text)
  to cbn_deletion_executor;

commit;
