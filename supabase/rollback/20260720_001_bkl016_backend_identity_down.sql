begin;

-- Rollback manual e destrutivo somente para uma stack local de desenvolvimento limpa.
do $$
declare
  role_name text;
begin
  if exists (
    select 1 from audit.events
    where metadata ->> 'identity_model' = 'BKL016_BACKEND_IDENTITY_V1'
  ) then
    raise exception using errcode = '55000',
      message = 'Rollback de identidade backend recusado: existe auditoria indispensavel';
  end if;

  if exists (
    select 1 from app_private.retention_controls
    where legal_hold_active
       or legal_hold_removal_requested_at is not null
       or status in ('DELETION_PENDING', 'DELETED', 'ANONYMIZED')
       or anonymized_at is not null
       or deleted_at is not null
  ) then
    raise exception using errcode = '55000',
      message = 'Rollback de identidade backend recusado: existe estado de retencao indispensavel';
  end if;

  foreach role_name in array array[
    'cbn_gateway_backend', 'cbn_retention_operator',
    'cbn_hold_reviewer', 'cbn_deletion_executor'
  ] loop
    if exists (
      select 1 from pg_catalog.pg_auth_members m
      join pg_catalog.pg_roles member_role on member_role.oid = m.member
      join pg_catalog.pg_roles granted_role on granted_role.oid = m.roleid
      where (member_role.rolname = role_name or granted_role.rolname = role_name)
        and not (granted_role.rolname = role_name and member_role.rolname = 'postgres')
    ) then
      raise exception using errcode = '55000',
        message = 'Rollback de identidade backend recusado: papel possui membership';
    end if;
    if exists (
      select 1 from pg_catalog.pg_class c
      join pg_catalog.pg_roles r on r.oid = c.relowner
      where r.rolname = role_name
    ) or exists (
      select 1 from pg_catalog.pg_proc p
      join pg_catalog.pg_roles r on r.oid = p.proowner
      where r.rolname = role_name
    ) then
      raise exception using errcode = '55000',
        message = 'Rollback de identidade backend recusado: papel possui objeto';
    end if;
  end loop;
end
$$;

revoke execute on function app_private.gateway_create_operation(
  uuid, uuid, public.credit_product, text, text, text
) from cbn_gateway_backend;
revoke execute on function app_private.gateway_update_operation_state(
  uuid, text, text, text, text, text
) from cbn_gateway_backend;
revoke execute on function app_private.retention_evaluate(uuid, text, text),
  app_private.retention_apply_legal_hold(uuid, text, text),
  app_private.retention_anonymize_clients(uuid[], text),
  app_private.retention_prepare_deletion(uuid[], text, text),
  app_private.retention_cancel_deletion(uuid, text, text),
  app_private.retention_request_hold_removal(uuid, text)
from cbn_retention_operator;
revoke execute on function app_private.hold_review_removal(uuid, text, text, text)
  from cbn_hold_reviewer;
revoke execute on function app_private.retention_complete_deletion(uuid, boolean, text)
  from cbn_deletion_executor;

drop function if exists app_private.retention_complete_deletion(uuid, boolean, text);
drop function if exists app_private.hold_review_removal(uuid, text, text, text);
drop function if exists app_private.reject_legal_hold_removal(uuid, text, text, text);
drop function if exists app_private.retention_request_hold_removal(uuid, text);
drop function if exists app_private.retention_cancel_deletion(uuid, text, text);
drop function if exists app_private.retention_prepare_deletion(uuid[], text, text);
drop function if exists app_private.retention_anonymize_clients(uuid[], text);
drop function if exists app_private.retention_apply_legal_hold(uuid, text, text);
drop function if exists app_private.retention_evaluate(uuid, text, text);
drop function if exists app_private.gateway_update_operation_state(uuid, text, text, text, text, text);
drop function if exists app_private.gateway_create_operation(
  uuid, uuid, public.credit_product, text, text, text
);
drop function if exists audit.record_backend_identity_event(
  text, text, text, text, uuid, text, boolean, text, text
);

revoke all on schema public, app_private, audit from
  cbn_gateway_backend, cbn_retention_operator, cbn_hold_reviewer, cbn_deletion_executor;
revoke cbn_gateway_backend, cbn_retention_operator,
  cbn_hold_reviewer, cbn_deletion_executor from postgres;
drop role cbn_deletion_executor;
drop role cbn_hold_reviewer;
drop role cbn_retention_operator;
drop role cbn_gateway_backend;

-- Deliberadamente nao concede nada a PUBLIC, anon ou authenticated.
commit;
