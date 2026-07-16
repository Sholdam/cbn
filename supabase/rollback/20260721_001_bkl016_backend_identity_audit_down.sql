begin;

-- Fail closed: eventos do modelo novo sao evidencia indispensavel e nao podem
-- perder a semantica dos wrappers que os produziram.
do $$
begin
  if exists (
    select 1 from audit.events
    where metadata ->> 'identity_model' = 'BKL016_BACKEND_IDENTITY_V1'
  ) then
    raise exception using errcode = '55000',
      message = 'Rollback de auditoria da identidade backend recusado: existe auditoria indispensavel';
  end if;
end
$$;

-- Restaura exatamente os wrappers definidos pela migration 20260720_001.
create or replace function app_private.retention_evaluate(
  p_control_id uuid, p_action text, p_process_version text
) returns boolean
language plpgsql security definer set search_path = ''
as $$
begin
  return app_private.evaluate_retention_action(p_control_id, p_action, p_process_version);
end;
$$;

create or replace function app_private.retention_apply_legal_hold(
  p_control_id uuid, p_reason_code text, p_process_version text
) returns void
language plpgsql security definer set search_path = ''
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
language plpgsql security definer set search_path = ''
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
language plpgsql security definer set search_path = ''
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
language plpgsql security definer set search_path = ''
as $$
begin
  perform app_private.cancel_retention_deletion(p_control_id, p_reason_code, p_process_version);
end;
$$;

create or replace function app_private.retention_request_hold_removal(
  p_control_id uuid, p_process_version text
) returns void
language plpgsql security definer set search_path = ''
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
language plpgsql security definer set search_path = ''
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
language plpgsql security definer set search_path = ''
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
language plpgsql security definer set search_path = ''
as $$
begin
  perform app_private.complete_retention_deletion(
    p_control_id, p_storage_absence_confirmed, p_process_version
  );
end;
$$;

-- Reafirma a allowlist original, sem ampliar privilegios.
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

commit;
