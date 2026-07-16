-- BKL-016 - reparos incrementais da revisao humana de retencao/legal hold.
-- Preserva integralmente a migration 20260718_001.

begin;

create or replace function app_private.has_applicable_legal_hold(
  p_entity_type text,
  p_entity_id uuid,
  p_client_id uuid,
  p_operation_id uuid
) returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from app_private.retention_controls c
    where c.legal_hold_active
      and c.deleted_at is null
      and (
        (c.entity_type = p_entity_type and c.entity_id = p_entity_id)
        or (c.entity_type = 'CLIENT' and c.entity_id = p_client_id)
      )
  );
$$;

revoke all on function app_private.has_applicable_legal_hold(text, uuid, uuid, uuid)
from public, anon, authenticated;

create or replace function app_private.client_anonymization_block_reason(p_client_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when exists (select 1 from public.proposals p where p.client_id = p_client_id)
      then 'PROPOSAL_POLICY_REQUIRED'
    when exists (select 1 from app_private.proposal_sensitive_data ps
      join public.proposals p on p.id = ps.proposal_id where p.client_id = p_client_id)
      then 'PROPOSAL_SENSITIVE_POLICY_REQUIRED'
    when exists (select 1 from app_private.protected_payloads p where p.client_id = p_client_id)
      then 'PAYLOAD_POLICY_REQUIRED'
    when exists (select 1 from app_private.protected_file_refs f where f.client_id = p_client_id)
      then 'FILE_POLICY_REQUIRED'
    else null
  end;
$$;

revoke all on function app_private.client_anonymization_block_reason(uuid)
from public, anon, authenticated;

create or replace function app_private.evaluate_retention_action(
  p_control_id uuid,
  p_action text,
  p_process_version text
) returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  c app_private.retention_controls%rowtype;
  allowed_result boolean;
  reason_code text;
  event_type text;
begin
  if p_action not in ('ANONYMIZE', 'DELETE') then
    raise exception using errcode = '22023', message = 'retention_action_rejected';
  end if;
  select * into strict c from app_private.retention_controls where id = p_control_id;
  allowed_result := not app_private.has_applicable_legal_hold(
      c.entity_type, c.entity_id, c.client_id, c.operation_id
    )
    and c.retention_until <= now()
    and (p_action <> 'DELETE' or c.deletion_eligible_at <= now())
    and c.deleted_at is null;
  reason_code := case
    when app_private.has_applicable_legal_hold(c.entity_type, c.entity_id, c.client_id, c.operation_id)
      then 'LEGAL_HOLD_SCOPE_ACTIVE'
    when c.retention_until > now() then 'RETENTION_NOT_EXPIRED'
    when p_action = 'DELETE' and c.deletion_eligible_at > now() then 'DELETION_NOT_ELIGIBLE'
    when c.deleted_at is not null then 'ALREADY_DELETED'
    else 'RETENTION_EXPIRED'
  end;
  event_type := case
    when p_action = 'ANONYMIZE' and allowed_result then 'ANONYMIZATION_ALLOWED'
    when p_action = 'ANONYMIZE' then 'ANONYMIZATION_DENIED'
    when allowed_result then 'DELETION_ALLOWED'
    else 'DELETION_DENIED'
  end;
  perform audit.record_retention_event(
    'RETENTION_EVALUATED', c.entity_type, c.entity_id, c.operation_id,
    c.purpose_code, allowed_result, reason_code, p_process_version
  );
  perform audit.record_retention_event(
    event_type, c.entity_type, c.entity_id, c.operation_id,
    c.purpose_code, allowed_result, reason_code, p_process_version
  );
  return allowed_result;
end;
$$;

create or replace function app_private.remove_legal_hold(
  p_control_id uuid,
  p_actor_ref text,
  p_process_version text
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare c app_private.retention_controls%rowtype;
begin
  if p_actor_ref !~ '^[A-Z0-9_:-]{3,80}$' then
    raise exception using errcode = '22023', message = 'legal_hold_actor_rejected';
  end if;
  select * into strict c from app_private.retention_controls where id = p_control_id for update;
  if not c.legal_hold_active or c.legal_hold_removal_requested_at is null then
    raise exception using errcode = '55000', message = 'legal_hold_explicit_request_required';
  end if;
  if c.legal_hold_removal_requested_by = p_actor_ref then
    raise exception using errcode = '42501', message = 'legal_hold_separation_of_duties_required';
  end if;
  update app_private.retention_controls set
    legal_hold_active = false,
    legal_hold_removed_at = now(),
    legal_hold_removed_by = p_actor_ref,
    status = case
      when anonymized_at is not null then 'ANONYMIZED'
      when deletion_eligible_at <= now() then 'ELIGIBLE'
      else 'ACTIVE'
    end,
    process_version = p_process_version
  where id = p_control_id;
  perform audit.record_retention_event(
    'LEGAL_HOLD_REMOVED', c.entity_type, c.entity_id, c.operation_id,
    c.purpose_code, true, 'EXPLICIT_INDEPENDENT_REVIEW', p_process_version
  );
end;
$$;

create or replace function app_private.anonymize_clients(
  p_control_ids uuid[],
  p_process_version text
) returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  c app_private.retention_controls%rowtype;
  processed integer := 0;
  denied boolean := false;
  child_reason text;
begin
  if p_control_ids is null or cardinality(p_control_ids) = 0 then
    raise exception using errcode = '22023', message = 'explicit_ids_required';
  end if;
  if cardinality(p_control_ids) > 10
     or cardinality(p_control_ids) <> (select count(distinct x) from unnest(p_control_ids) x) then
    raise exception using errcode = '22023', message = 'explicit_id_batch_rejected';
  end if;
  if (select count(*) from app_private.retention_controls where id = any(p_control_ids))
     <> cardinality(p_control_ids) then
    raise exception using errcode = 'P0002', message = 'retention_control_not_found';
  end if;

  -- Preflight completo: nenhuma linha e alterada se um membro do lote for negado.
  for c in
    select * from app_private.retention_controls
    where id = any(p_control_ids) order by id for update
  loop
    if c.entity_type <> 'CLIENT' then
      raise exception using errcode = '22023', message = 'anonymization_entity_rejected';
    end if;
    if c.anonymized_at is not null then continue; end if;
    if not app_private.evaluate_retention_action(c.id, 'ANONYMIZE', p_process_version) then
      denied := true;
      continue;
    end if;
    child_reason := app_private.client_anonymization_block_reason(c.entity_id);
    if child_reason is not null then
      perform audit.record_retention_event('RETENTION_EVALUATED', c.entity_type, c.entity_id,
        c.operation_id, c.purpose_code, false, child_reason, p_process_version);
      perform audit.record_retention_event('ANONYMIZATION_DENIED', c.entity_type, c.entity_id,
        c.operation_id, c.purpose_code, false, child_reason, p_process_version);
      denied := true;
    end if;
  end loop;
  if denied then return 0; end if;

  for c in
    select * from app_private.retention_controls
    where id = any(p_control_ids) and anonymized_at is null order by id for update
  loop
    -- Interacoes e pendencias preservam apenas codigos e estados tecnicos.
    update public.interactions set
      external_message_ref = null, event_summary_masked = null, automation_ref = null
    where client_id = c.entity_id;
    update public.pending_items set
      pending_reason_masked = null, resolution_masked = null, assigned_user_id = null
    where client_id = c.entity_id;
    delete from app_private.client_sensitive_data where client_id = c.entity_id;
    update public.clients set
      display_name = '[ANONYMIZED]', phone_masked = null, cpf_masked = null,
      lead_source = null, consultation_consent_source = null,
      journey_state = 'ANONYMIZED', anonymized_at = coalesce(anonymized_at, now())
    where id = c.entity_id;
    update app_private.retention_controls set
      anonymized_at = now(), status = 'ANONYMIZED', process_version = p_process_version
    where id = c.id;
    perform audit.record_retention_event('ANONYMIZATION_COMPLETED', c.entity_type, c.entity_id,
      c.operation_id, c.purpose_code, true, 'DIRECT_IDENTIFIERS_REMOVED', p_process_version);
    processed := processed + 1;
  end loop;
  return processed;
end;
$$;

create or replace function app_private.guard_anonymized_client_private_write()
returns trigger
language plpgsql
set search_path = ''
as $$
declare target_client uuid;
begin
  if tg_table_name = 'client_sensitive_data' then
    target_client := new.client_id;
  elsif tg_table_name = 'proposal_sensitive_data' then
    select client_id into target_client from public.proposals where id = new.proposal_id;
  else
    target_client := new.client_id;
  end if;
  if target_client is not null and exists (
    select 1 from public.clients where id = target_client and anonymized_at is not null
  ) then
    raise exception using errcode = '55000', message = 'anonymized_client_private_write_rejected';
  end if;
  return new;
end;
$$;

create trigger client_sensitive_prevent_reidentification
before insert or update on app_private.client_sensitive_data
for each row execute function app_private.guard_anonymized_client_private_write();
create trigger proposal_sensitive_prevent_reidentification
before insert or update on app_private.proposal_sensitive_data
for each row execute function app_private.guard_anonymized_client_private_write();
create trigger protected_payload_prevent_reidentification
before insert or update on app_private.protected_payloads
for each row execute function app_private.guard_anonymized_client_private_write();
create trigger protected_file_prevent_reidentification
before insert or update on app_private.protected_file_refs
for each row execute function app_private.guard_anonymized_client_private_write();

create or replace function app_private.guard_anonymized_client_public_child()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if exists (select 1 from public.clients where id = new.client_id and anonymized_at is not null) then
    raise exception using errcode = '55000', message = 'anonymized_client_child_write_rejected';
  end if;
  return new;
end;
$$;

create trigger proposals_prevent_reidentification
before insert or update on public.proposals
for each row execute function app_private.guard_anonymized_client_public_child();
create trigger interactions_prevent_reidentification
before insert or update on public.interactions
for each row execute function app_private.guard_anonymized_client_public_child();
create trigger pending_items_prevent_reidentification
before insert or update on public.pending_items
for each row execute function app_private.guard_anonymized_client_public_child();

create or replace function app_private.prepare_retention_deletion(
  p_control_ids uuid[], p_confirmation text, p_process_version text
) returns table (
  control_id uuid, entity_type text, entity_id uuid, bucket_name text, object_key text
)
language plpgsql
security definer
set search_path = ''
as $$
declare c app_private.retention_controls%rowtype;
declare denied boolean := false;
begin
  if p_confirmation <> 'synthetic-local-explicit-ids' then
    raise exception using errcode = '42501', message = 'human_confirmation_required';
  end if;
  if p_control_ids is null or cardinality(p_control_ids) = 0 then
    raise exception using errcode = '22023', message = 'explicit_ids_required';
  end if;
  if cardinality(p_control_ids) > 10
     or cardinality(p_control_ids) <> (select count(distinct x) from unnest(p_control_ids) x) then
    raise exception using errcode = '22023', message = 'explicit_id_batch_rejected';
  end if;
  if (select count(*) from app_private.retention_controls where id = any(p_control_ids))
     <> cardinality(p_control_ids) then
    raise exception using errcode = 'P0002', message = 'retention_control_not_found';
  end if;
  for c in select * from app_private.retention_controls
    where id = any(p_control_ids) order by id for update
  loop
    if c.entity_type not in ('PROTECTED_PAYLOAD', 'PROTECTED_FILE') then
      raise exception using errcode = '22023', message = 'physical_deletion_entity_rejected';
    end if;
    if not app_private.evaluate_retention_action(c.id, 'DELETE', p_process_version) then
      denied := true;
      continue;
    end if;
    if c.entity_type = 'PROTECTED_PAYLOAD' and (
      exists (select 1 from public.consultations x where x.protected_payload_ref = c.entity_id)
      or exists (select 1 from public.technical_operations x where x.protected_log_ref = c.entity_id)
      or exists (select 1 from public.proposals x where x.signing_link_ref = c.entity_id
        or x.final_authorization_evidence_payload_ref = c.entity_id)
    ) then
      perform audit.record_retention_event('RETENTION_EVALUATED', c.entity_type, c.entity_id,
        c.operation_id, c.purpose_code, false, 'ACTIVE_DEPENDENCY', p_process_version);
      perform audit.record_retention_event('DELETION_DENIED', c.entity_type, c.entity_id,
        c.operation_id, c.purpose_code, false, 'ACTIVE_DEPENDENCY', p_process_version);
      denied := true;
    end if;
  end loop;
  if denied then return; end if;
  update app_private.retention_controls set
    deletion_requested_at = now(), status = 'DELETION_PENDING', process_version = p_process_version
  where id = any(p_control_ids);
  return query
  select rc.id, rc.entity_type, rc.entity_id, f.bucket_name, f.object_key
  from app_private.retention_controls rc
  left join app_private.protected_file_refs f
    on rc.entity_type = 'PROTECTED_FILE' and f.id = rc.entity_id
  where rc.id = any(p_control_ids) order by rc.id;
end;
$$;

create or replace function app_private.complete_retention_deletion(
  p_control_id uuid, p_storage_absence_confirmed boolean, p_process_version text
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare c app_private.retention_controls%rowtype;
begin
  select * into strict c from app_private.retention_controls where id = p_control_id for update;
  if c.status <> 'DELETION_PENDING' then
    raise exception using errcode = '55000', message = 'deletion_completion_state_rejected';
  end if;
  -- Revalidacao obrigatoria imediatamente antes da conclusao.
  if not app_private.evaluate_retention_action(c.id, 'DELETE', p_process_version) then
    return;
  end if;
  if c.entity_type = 'PROTECTED_FILE' then
    if not p_storage_absence_confirmed then
      raise exception using errcode = '55000', message = 'storage_absence_confirmation_required';
    end if;
    delete from app_private.protected_file_refs where id = c.entity_id;
    perform audit.record_retention_event('STORAGE_DELETION_COMPLETED', c.entity_type, c.entity_id,
      c.operation_id, c.purpose_code, true, 'OBJECT_ABSENCE_VERIFIED', p_process_version);
  elsif c.entity_type = 'PROTECTED_PAYLOAD' then
    delete from app_private.protected_payloads where id = c.entity_id;
  else
    raise exception using errcode = '22023', message = 'physical_deletion_entity_rejected';
  end if;
  update app_private.retention_controls set
    deleted_at = now(), status = 'DELETED', process_version = p_process_version
  where id = c.id;
  perform audit.record_retention_event('DELETION_COMPLETED', c.entity_type, c.entity_id,
    c.operation_id, c.purpose_code, true, 'MINIMAL_AUDIT_RETAINED', p_process_version);
end;
$$;

revoke all on function app_private.guard_anonymized_client_private_write() from public, anon, authenticated;
revoke all on function app_private.guard_anonymized_client_public_child() from public, anon, authenticated;

commit;
