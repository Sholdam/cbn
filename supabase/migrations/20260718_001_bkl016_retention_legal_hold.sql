-- BKL-016 - retencao, anonimizacao, exclusao segura e legal hold.
-- Esta migration nao define prazo juridico. Politicas e datas precisam ser
-- aprovadas e fornecidas explicitamente antes de qualquer processamento.

begin;

create table app_private.retention_policies (
  id uuid primary key default extensions.gen_random_uuid(),
  policy_code text not null unique,
  data_category text not null,
  purpose_code text not null,
  retention_period interval,
  policy_status text not null default 'DRAFT',
  review_required boolean not null default true,
  review_due_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint retention_policies_codes_ck check (
    policy_code ~ '^[A-Z0-9_:-]{3,80}$'
    and data_category ~ '^[A-Z0-9_:-]{3,80}$'
    and purpose_code ~ '^[A-Z0-9_:-]{3,80}$'
  ),
  constraint retention_policies_status_ck check (
    policy_status in ('DRAFT', 'ACTIVE', 'SUSPENDED', 'RETIRED')
  ),
  constraint retention_policies_period_ck check (
    retention_period is null or retention_period > interval '0 seconds'
  ),
  constraint retention_policies_active_review_ck check (
    policy_status <> 'ACTIVE'
    or (retention_period is not null and review_required = false)
  )
);

comment on table app_private.retention_policies is
  'Configuracao tecnica sem PII. Nenhum prazo juridico e criado por esta migration.';

create table app_private.retention_controls (
  id uuid primary key default extensions.gen_random_uuid(),
  policy_id uuid not null references app_private.retention_policies(id) on delete restrict,
  entity_type text not null,
  entity_id uuid not null,
  client_id uuid references public.clients(id) on delete restrict,
  operation_id uuid references public.technical_operations(operation_id) on delete restrict,
  purpose_code text not null,
  retention_until timestamptz not null,
  deletion_eligible_at timestamptz not null,
  anonymized_at timestamptz,
  deletion_requested_at timestamptz,
  deleted_at timestamptz,
  status text not null default 'ACTIVE',
  legal_hold_active boolean not null default false,
  legal_hold_reason_code text,
  legal_hold_applied_at timestamptz,
  legal_hold_applied_by text,
  legal_hold_removal_requested_at timestamptz,
  legal_hold_removal_requested_by text,
  legal_hold_removed_at timestamptz,
  legal_hold_removed_by text,
  process_version text not null,
  review_required boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint retention_controls_entity_uk unique (entity_type, entity_id),
  constraint retention_controls_entity_type_ck check (
    entity_type in ('CLIENT', 'PROTECTED_PAYLOAD', 'PROTECTED_FILE')
  ),
  constraint retention_controls_codes_ck check (
    purpose_code ~ '^[A-Z0-9_:-]{3,80}$'
    and process_version ~ '^[A-Za-z0-9._:-]{1,40}$'
    and (legal_hold_reason_code is null or legal_hold_reason_code ~ '^[A-Z0-9_:-]{3,80}$')
    and (legal_hold_applied_by is null or legal_hold_applied_by ~ '^[A-Z0-9_:-]{3,80}$')
    and (legal_hold_removal_requested_by is null or legal_hold_removal_requested_by ~ '^[A-Z0-9_:-]{3,80}$')
    and (legal_hold_removed_by is null or legal_hold_removed_by ~ '^[A-Z0-9_:-]{3,80}$')
  ),
  constraint retention_controls_status_ck check (
    status in ('ACTIVE', 'ELIGIBLE', 'ANONYMIZED', 'DELETION_PENDING', 'DELETED', 'BLOCKED')
  ),
  constraint retention_controls_dates_ck check (
    deletion_eligible_at >= retention_until
    and (deleted_at is null or deletion_requested_at is not null)
    and (deleted_at is null or anonymized_at is null or deleted_at >= anonymized_at)
  ),
  constraint retention_controls_hold_ck check (
    (
      legal_hold_active
      and legal_hold_reason_code is not null
      and legal_hold_applied_at is not null
      and legal_hold_applied_by is not null
      and legal_hold_removed_at is null
      and legal_hold_removed_by is null
    ) or (
      not legal_hold_active
      and (
        legal_hold_applied_at is null
        or (legal_hold_removed_at is not null and legal_hold_removed_by is not null)
      )
    )
  ),
  constraint retention_controls_deleted_ck check (
    (status = 'DELETED') = (deleted_at is not null)
  )
);

create index retention_controls_due_idx
  on app_private.retention_controls(status, deletion_eligible_at)
  where deleted_at is null;
create index retention_controls_hold_idx
  on app_private.retention_controls(legal_hold_active, entity_type)
  where legal_hold_active;

alter table app_private.retention_policies enable row level security;
alter table app_private.retention_policies force row level security;
alter table app_private.retention_controls enable row level security;
alter table app_private.retention_controls force row level security;

revoke all on app_private.retention_policies, app_private.retention_controls
from public, anon, authenticated;

create trigger retention_policies_set_updated_at
before update on app_private.retention_policies
for each row execute function public.set_updated_at();

create trigger retention_controls_set_updated_at
before update on app_private.retention_controls
for each row execute function public.set_updated_at();

create or replace function app_private.enforce_retention_control_target()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  target_client uuid;
  target_operation uuid;
begin
  if new.entity_type = 'CLIENT' then
    if not exists (select 1 from public.clients where id = new.entity_id)
       or new.client_id is distinct from new.entity_id
       or new.operation_id is not null then
      raise exception using errcode = '23503', message = 'retention_client_target_mismatch';
    end if;
  elsif new.entity_type = 'PROTECTED_PAYLOAD' then
    select client_id, operation_id into target_client, target_operation
    from app_private.protected_payloads where id = new.entity_id;
    if not found or new.client_id is distinct from target_client
       or new.operation_id is distinct from target_operation then
      raise exception using errcode = '23503', message = 'retention_payload_target_mismatch';
    end if;
  elsif new.entity_type = 'PROTECTED_FILE' then
    select client_id, operation_id into target_client, target_operation
    from app_private.protected_file_refs where id = new.entity_id;
    if not found or new.client_id is distinct from target_client
       or new.operation_id is distinct from target_operation then
      raise exception using errcode = '23503', message = 'retention_file_target_mismatch';
    end if;
  end if;
  return new;
end;
$$;

create trigger retention_controls_enforce_target
before insert or update of entity_type, entity_id, client_id, operation_id
on app_private.retention_controls
for each row execute function app_private.enforce_retention_control_target();

create or replace function audit.record_retention_event(
  p_event_type text,
  p_entity_type text,
  p_entity_id uuid,
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
  if p_event_type not in (
    'RETENTION_EVALUATED', 'ANONYMIZATION_ALLOWED', 'ANONYMIZATION_DENIED',
    'ANONYMIZATION_COMPLETED', 'LEGAL_HOLD_APPLIED',
    'LEGAL_HOLD_REMOVAL_REQUESTED', 'LEGAL_HOLD_REMOVED',
    'DELETION_ALLOWED', 'DELETION_DENIED', 'DELETION_COMPLETED',
    'STORAGE_DELETION_COMPLETED'
  ) then
    raise exception using errcode = '22023', message = 'retention_event_type_rejected';
  end if;
  if p_entity_type !~ '^[A-Z0-9_:-]{3,80}$'
     or p_purpose_code !~ '^[A-Z0-9_:-]{3,80}$'
     or p_reason_code !~ '^[A-Z0-9_:-]{3,80}$'
     or p_process_version !~ '^[A-Za-z0-9._:-]{1,40}$' then
    raise exception using errcode = '22023', message = 'retention_audit_metadata_rejected';
  end if;
  insert into audit.events (
    origin, event_type, entity_type, entity_id, operation_id,
    allowed, purpose_code, metadata
  ) values (
    'system', p_event_type, p_entity_type, p_entity_id::text, p_operation_id,
    p_allowed, p_purpose_code,
    jsonb_build_object('reason_code', p_reason_code, 'process_version', p_process_version)
  );
end;
$$;

revoke all on function audit.record_retention_event(text, text, uuid, uuid, text, boolean, text, text)
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
  allowed_result := not c.legal_hold_active
    and c.retention_until <= now()
    and (p_action <> 'DELETE' or c.deletion_eligible_at <= now())
    and c.deleted_at is null;
  reason_code := case
    when c.legal_hold_active then 'LEGAL_HOLD_ACTIVE'
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

create or replace function app_private.apply_legal_hold(
  p_control_id uuid,
  p_reason_code text,
  p_actor_ref text,
  p_process_version text
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare c app_private.retention_controls%rowtype;
begin
  if p_reason_code !~ '^[A-Z0-9_:-]{3,80}$'
     or p_actor_ref !~ '^[A-Z0-9_:-]{3,80}$' then
    raise exception using errcode = '22023', message = 'legal_hold_metadata_rejected';
  end if;
  select * into strict c from app_private.retention_controls where id = p_control_id for update;
  if c.deleted_at is not null or c.status = 'DELETION_PENDING' then
    raise exception using errcode = '55000', message = 'legal_hold_state_rejected';
  end if;
  if not c.legal_hold_active then
    update app_private.retention_controls set
      legal_hold_active = true,
      legal_hold_reason_code = p_reason_code,
      legal_hold_applied_at = now(),
      legal_hold_applied_by = p_actor_ref,
      legal_hold_removal_requested_at = null,
      legal_hold_removal_requested_by = null,
      legal_hold_removed_at = null,
      legal_hold_removed_by = null,
      status = 'BLOCKED',
      process_version = p_process_version
    where id = p_control_id;
  end if;
  perform audit.record_retention_event(
    'LEGAL_HOLD_APPLIED', c.entity_type, c.entity_id, c.operation_id,
    c.purpose_code, true, p_reason_code, p_process_version
  );
end;
$$;

create or replace function app_private.request_legal_hold_removal(
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
  if not c.legal_hold_active then
    raise exception using errcode = '55000', message = 'legal_hold_not_active';
  end if;
  update app_private.retention_controls set
    legal_hold_removal_requested_at = now(),
    legal_hold_removal_requested_by = p_actor_ref,
    process_version = p_process_version
  where id = p_control_id;
  perform audit.record_retention_event(
    'LEGAL_HOLD_REMOVAL_REQUESTED', c.entity_type, c.entity_id, c.operation_id,
    c.purpose_code, true, 'EXPLICIT_REVIEW', p_process_version
  );
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
  update app_private.retention_controls set
    legal_hold_active = false,
    legal_hold_removed_at = now(),
    legal_hold_removed_by = p_actor_ref,
    status = case when deletion_eligible_at <= now() then 'ELIGIBLE' else 'ACTIVE' end,
    process_version = p_process_version
  where id = p_control_id;
  perform audit.record_retention_event(
    'LEGAL_HOLD_REMOVED', c.entity_type, c.entity_id, c.operation_id,
    c.purpose_code, true, 'EXPLICIT_REVIEW', p_process_version
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
begin
  if p_control_ids is null or cardinality(p_control_ids) = 0 then
    raise exception using errcode = '22023', message = 'explicit_ids_required';
  end if;
  if cardinality(p_control_ids) > 10
     or cardinality(p_control_ids) <> (select count(distinct x) from unnest(p_control_ids) x) then
    raise exception using errcode = '22023', message = 'explicit_id_batch_rejected';
  end if;
  for c in
    select * from app_private.retention_controls
    where id = any(p_control_ids)
    order by id for update
  loop
    if c.entity_type <> 'CLIENT' then
      raise exception using errcode = '22023', message = 'anonymization_entity_rejected';
    end if;
    if c.anonymized_at is not null then
      continue;
    end if;
    if c.legal_hold_active then
      perform audit.record_retention_event('ANONYMIZATION_DENIED', c.entity_type, c.entity_id,
        c.operation_id, c.purpose_code, false, 'LEGAL_HOLD_ACTIVE', p_process_version);
      raise exception using errcode = '55000', message = 'legal_hold_blocks_anonymization';
    end if;
    if c.retention_until > now() then
      perform audit.record_retention_event('ANONYMIZATION_DENIED', c.entity_type, c.entity_id,
        c.operation_id, c.purpose_code, false, 'RETENTION_NOT_EXPIRED', p_process_version);
      raise exception using errcode = '55000', message = 'retention_not_expired';
    end if;
    perform audit.record_retention_event('ANONYMIZATION_ALLOWED', c.entity_type, c.entity_id,
      c.operation_id, c.purpose_code, true, 'RETENTION_EXPIRED', p_process_version);
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
  if (select count(*) from app_private.retention_controls where id = any(p_control_ids))
     <> cardinality(p_control_ids) then
    raise exception using errcode = 'P0002', message = 'retention_control_not_found';
  end if;
  return processed;
end;
$$;

create or replace function app_private.prevent_client_reidentification()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.anonymized_at is not null and (
    new.anonymized_at is null
    or new.display_name <> '[ANONYMIZED]'
    or new.phone_masked is not null
    or new.cpf_masked is not null
    or new.lead_source is not null
    or new.consultation_consent_source is not null
  ) then
    raise exception using errcode = '55000', message = 'anonymized_client_revival_rejected';
  end if;
  return new;
end;
$$;

create trigger clients_prevent_reidentification
before update on public.clients
for each row execute function app_private.prevent_client_reidentification();

create or replace function app_private.prepare_retention_deletion(
  p_control_ids uuid[],
  p_confirmation text,
  p_process_version text
) returns table (
  control_id uuid, entity_type text, entity_id uuid,
  bucket_name text, object_key text
)
language plpgsql
security definer
set search_path = ''
as $$
declare c app_private.retention_controls%rowtype;
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
  for c in
    select * from app_private.retention_controls
    where id = any(p_control_ids)
    order by id for update
  loop
    if c.entity_type not in ('PROTECTED_PAYLOAD', 'PROTECTED_FILE') then
      raise exception using errcode = '22023', message = 'physical_deletion_entity_rejected';
    end if;
    if c.legal_hold_active then
      perform audit.record_retention_event('DELETION_DENIED', c.entity_type, c.entity_id,
        c.operation_id, c.purpose_code, false, 'LEGAL_HOLD_ACTIVE', p_process_version);
      raise exception using errcode = '55000', message = 'legal_hold_blocks_deletion';
    end if;
    if c.retention_until > now() or c.deletion_eligible_at > now() then
      perform audit.record_retention_event('DELETION_DENIED', c.entity_type, c.entity_id,
        c.operation_id, c.purpose_code, false, 'RETENTION_NOT_EXPIRED', p_process_version);
      raise exception using errcode = '55000', message = 'deletion_not_eligible';
    end if;
    if c.status = 'DELETED' then
      raise exception using errcode = '55000', message = 'already_deleted';
    end if;
    if c.entity_type = 'PROTECTED_PAYLOAD' and (
      exists (select 1 from public.consultations x where x.protected_payload_ref = c.entity_id)
      or exists (select 1 from public.technical_operations x where x.protected_log_ref = c.entity_id)
      or exists (select 1 from public.proposals x where x.signing_link_ref = c.entity_id
        or x.final_authorization_evidence_payload_ref = c.entity_id)
    ) then
      perform audit.record_retention_event('DELETION_DENIED', c.entity_type, c.entity_id,
        c.operation_id, c.purpose_code, false, 'ACTIVE_DEPENDENCY', p_process_version);
      raise exception using errcode = '23503', message = 'active_dependency_blocks_deletion';
    end if;
    update app_private.retention_controls set
      deletion_requested_at = now(), status = 'DELETION_PENDING', process_version = p_process_version
    where id = c.id;
    perform audit.record_retention_event('DELETION_ALLOWED', c.entity_type, c.entity_id,
      c.operation_id, c.purpose_code, true, 'EXPLICIT_IDS_CONFIRMED', p_process_version);
  end loop;
  if (select count(*) from app_private.retention_controls where id = any(p_control_ids))
     <> cardinality(p_control_ids) then
    raise exception using errcode = 'P0002', message = 'retention_control_not_found';
  end if;
  return query
  select rc.id, rc.entity_type, rc.entity_id, f.bucket_name, f.object_key
  from app_private.retention_controls rc
  left join app_private.protected_file_refs f
    on rc.entity_type = 'PROTECTED_FILE' and f.id = rc.entity_id
  where rc.id = any(p_control_ids)
  order by rc.id;
end;
$$;

create or replace function app_private.complete_retention_deletion(
  p_control_id uuid,
  p_storage_absence_confirmed boolean,
  p_process_version text
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare c app_private.retention_controls%rowtype;
begin
  select * into strict c from app_private.retention_controls where id = p_control_id for update;
  if c.status <> 'DELETION_PENDING' or c.legal_hold_active then
    raise exception using errcode = '55000', message = 'deletion_completion_state_rejected';
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

create or replace function app_private.cancel_retention_deletion(
  p_control_id uuid,
  p_reason_code text,
  p_process_version text
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare c app_private.retention_controls%rowtype;
begin
  if p_reason_code !~ '^[A-Z0-9_:-]{3,80}$' then
    raise exception using errcode = '22023', message = 'deletion_reason_rejected';
  end if;
  select * into strict c from app_private.retention_controls where id = p_control_id for update;
  if c.status <> 'DELETION_PENDING' then
    raise exception using errcode = '55000', message = 'deletion_not_pending';
  end if;
  update app_private.retention_controls set
    deletion_requested_at = null, status = 'ELIGIBLE', process_version = p_process_version
  where id = c.id;
  perform audit.record_retention_event('DELETION_DENIED', c.entity_type, c.entity_id,
    c.operation_id, c.purpose_code, false, p_reason_code, p_process_version);
end;
$$;

create or replace function app_private.guard_retention_controlled_delete()
returns trigger
language plpgsql
set search_path = ''
as $$
declare c app_private.retention_controls%rowtype;
begin
  select * into c from app_private.retention_controls
  where entity_type = tg_argv[0] and entity_id = old.id;
  if found and (c.legal_hold_active or c.status <> 'DELETION_PENDING') then
    raise exception using errcode = '55000', message = 'controlled_entity_delete_rejected';
  end if;
  return old;
end;
$$;

create trigger protected_payloads_guard_retention_delete
before delete on app_private.protected_payloads
for each row execute function app_private.guard_retention_controlled_delete('PROTECTED_PAYLOAD');

create trigger protected_file_refs_guard_retention_delete
before delete on app_private.protected_file_refs
for each row execute function app_private.guard_retention_controlled_delete('PROTECTED_FILE');

revoke all on function app_private.apply_legal_hold(uuid, text, text, text) from public, anon, authenticated;
revoke all on function app_private.evaluate_retention_action(uuid, text, text) from public, anon, authenticated;
revoke all on function app_private.request_legal_hold_removal(uuid, text, text) from public, anon, authenticated;
revoke all on function app_private.remove_legal_hold(uuid, text, text) from public, anon, authenticated;
revoke all on function app_private.anonymize_clients(uuid[], text) from public, anon, authenticated;
revoke all on function app_private.prepare_retention_deletion(uuid[], text, text) from public, anon, authenticated;
revoke all on function app_private.complete_retention_deletion(uuid, boolean, text) from public, anon, authenticated;
revoke all on function app_private.cancel_retention_deletion(uuid, text, text) from public, anon, authenticated;
revoke all on function app_private.prevent_client_reidentification() from public, anon, authenticated;
revoke all on function app_private.enforce_retention_control_target() from public, anon, authenticated;
revoke all on function app_private.guard_retention_controlled_delete() from public, anon, authenticated;

commit;
