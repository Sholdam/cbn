begin;

-- Auditoria consistente das identidades tecnicas nos wrappers controlados.
-- Nenhum grant ou papel e alterado nesta migration incremental.

create or replace function app_private.retention_evaluate(
  p_control_id uuid, p_action text, p_process_version text
) returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  c app_private.retention_controls%rowtype;
  decision boolean;
begin
  select * into strict c from app_private.retention_controls where id = p_control_id;
  decision := app_private.evaluate_retention_action(p_control_id, p_action, p_process_version);
  perform audit.record_backend_identity_event(
    'CBN_RETENTION_OPERATOR', 'RETENTION_EVALUATED_BY_OPERATOR', c.entity_type,
    c.entity_id::text, c.operation_id, c.purpose_code, decision,
    case when decision then p_action || '_ALLOWED' else p_action || '_DENIED' end,
    p_process_version
  );
  return decision;
end;
$$;

create or replace function app_private.retention_apply_legal_hold(
  p_control_id uuid, p_reason_code text, p_process_version text
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  c app_private.retention_controls%rowtype;
  was_active boolean;
begin
  select * into strict c from app_private.retention_controls where id = p_control_id;
  was_active := c.legal_hold_active;
  perform app_private.apply_legal_hold(
    p_control_id, p_reason_code, 'CBN_RETENTION_OPERATOR', p_process_version
  );
  perform audit.record_backend_identity_event(
    'CBN_RETENTION_OPERATOR', 'LEGAL_HOLD_APPLIED_BY_OPERATOR', c.entity_type,
    c.entity_id::text, c.operation_id, c.purpose_code, not was_active,
    case when was_active then 'NO_STATE_CHANGE' else p_reason_code end,
    p_process_version
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
declare
  c app_private.retention_controls%rowtype;
  processed integer;
  previously_anonymized uuid[];
  changed boolean;
begin
  select coalesce(array_agg(id), array[]::uuid[])
  into previously_anonymized
  from app_private.retention_controls
  where id = any(p_control_ids) and anonymized_at is not null;

  processed := app_private.anonymize_clients(p_control_ids, p_process_version);
  for c in
    select * from app_private.retention_controls
    where id = any(p_control_ids) order by id
  loop
    changed := processed > 0
      and c.anonymized_at is not null
      and not (c.id = any(previously_anonymized));
    perform audit.record_backend_identity_event(
      'CBN_RETENTION_OPERATOR', 'CLIENT_ANONYMIZED_BY_OPERATOR', c.entity_type,
      c.entity_id::text, c.operation_id, c.purpose_code, changed,
      case when changed then 'ANONYMIZATION_COMPLETED' else 'NO_CHANGES' end,
      p_process_version
    );
  end loop;
  return processed;
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
declare
  c app_private.retention_controls%rowtype;
  already_pending uuid[];
  changed boolean;
begin
  select coalesce(array_agg(id), array[]::uuid[])
  into already_pending
  from app_private.retention_controls
  where id = any(p_control_ids) and status = 'DELETION_PENDING';

  return query select * from app_private.prepare_retention_deletion(
    p_control_ids, p_confirmation, p_process_version
  );

  for c in
    select * from app_private.retention_controls
    where id = any(p_control_ids) order by id
  loop
    changed := c.status = 'DELETION_PENDING'
      and not (c.id = any(already_pending));
    perform audit.record_backend_identity_event(
      'CBN_RETENTION_OPERATOR', 'DELETION_PREPARED_BY_OPERATOR', c.entity_type,
      c.entity_id::text, c.operation_id, c.purpose_code, changed,
      case when changed then 'EXPLICIT_IDS_PREPARED' else 'POLICY_DENIED' end,
      p_process_version
    );
  end loop;
end;
$$;

create or replace function app_private.retention_cancel_deletion(
  p_control_id uuid, p_reason_code text, p_process_version text
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare c app_private.retention_controls%rowtype;
begin
  select * into strict c from app_private.retention_controls where id = p_control_id;
  perform app_private.cancel_retention_deletion(p_control_id, p_reason_code, p_process_version);
  perform audit.record_backend_identity_event(
    'CBN_RETENTION_OPERATOR', 'DELETION_CANCELLED_BY_OPERATOR', c.entity_type,
    c.entity_id::text, c.operation_id, c.purpose_code, true,
    p_reason_code, p_process_version
  );
end;
$$;

create or replace function app_private.retention_request_hold_removal(
  p_control_id uuid, p_process_version text
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare c app_private.retention_controls%rowtype;
begin
  select * into strict c from app_private.retention_controls where id = p_control_id;
  perform app_private.request_legal_hold_removal(
    p_control_id, 'CBN_RETENTION_OPERATOR', p_process_version
  );
  perform audit.record_backend_identity_event(
    'CBN_RETENTION_OPERATOR', 'LEGAL_HOLD_REMOVAL_REQUESTED_BY_OPERATOR', c.entity_type,
    c.entity_id::text, c.operation_id, c.purpose_code, true,
    'EXPLICIT_REVIEW_REQUESTED', p_process_version
  );
end;
$$;

-- O evento generico da versao anterior e removido para que o wrapper seja o
-- unico ponto de auditoria da identidade do revisor.
create or replace function app_private.reject_legal_hold_removal(
  p_control_id uuid, p_actor_ref text, p_reason_code text, p_process_version text
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare c app_private.retention_controls%rowtype;
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
end;
$$;

create or replace function app_private.hold_review_removal(
  p_control_id uuid, p_decision text, p_reason_code text, p_process_version text
) returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare c app_private.retention_controls%rowtype;
begin
  if p_decision not in ('APPROVE', 'REJECT')
     or p_reason_code !~ '^[A-Z0-9_:-]{3,80}$'
     or p_process_version !~ '^[A-Za-z0-9._:-]{1,40}$' then
    raise exception using errcode = '22023', message = 'hold_review_metadata_rejected';
  end if;
  select * into strict c from app_private.retention_controls where id = p_control_id;
  if p_decision = 'APPROVE' then
    perform app_private.remove_legal_hold(
      p_control_id, 'CBN_HOLD_REVIEWER', p_process_version
    );
    perform audit.record_backend_identity_event(
      'CBN_HOLD_REVIEWER', 'LEGAL_HOLD_REMOVAL_APPROVED_BY_REVIEWER', c.entity_type,
      c.entity_id::text, c.operation_id, c.purpose_code, true,
      p_reason_code, p_process_version
    );
    return true;
  end if;

  perform app_private.reject_legal_hold_removal(
    p_control_id, 'CBN_HOLD_REVIEWER', p_reason_code, p_process_version
  );
  perform audit.record_backend_identity_event(
    'CBN_HOLD_REVIEWER', 'LEGAL_HOLD_REMOVAL_REJECTED_BY_REVIEWER', c.entity_type,
    c.entity_id::text, c.operation_id, c.purpose_code, false,
    p_reason_code, p_process_version
  );
  return false;
end;
$$;

create or replace function app_private.retention_complete_deletion(
  p_control_id uuid, p_storage_absence_confirmed boolean, p_process_version text
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  c app_private.retention_controls%rowtype;
  completed boolean;
begin
  select * into strict c from app_private.retention_controls where id = p_control_id;
  perform app_private.complete_retention_deletion(
    p_control_id, p_storage_absence_confirmed, p_process_version
  );
  select status = 'DELETED' and deleted_at is not null
  into completed
  from app_private.retention_controls where id = p_control_id;
  perform audit.record_backend_identity_event(
    'CBN_DELETION_EXECUTOR', 'DELETION_COMPLETED_BY_EXECUTOR', c.entity_type,
    c.entity_id::text, c.operation_id, c.purpose_code, coalesce(completed, false),
    case when completed then 'DELETION_COMPLETED' else 'POLICY_DENIED' end,
    p_process_version
  );
end;
$$;

-- Reafirma a mesma allowlist. Nenhum grant novo e criado.
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
