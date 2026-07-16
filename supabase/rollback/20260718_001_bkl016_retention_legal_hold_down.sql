-- BKL-016 - rollback fail-closed de retencao e legal hold.
begin;

do $$
begin
  if exists (select 1 from app_private.retention_policies)
     or exists (select 1 from app_private.retention_controls)
     or exists (
       select 1 from audit.events where event_type in (
         'RETENTION_EVALUATED', 'ANONYMIZATION_ALLOWED', 'ANONYMIZATION_DENIED',
         'ANONYMIZATION_COMPLETED', 'LEGAL_HOLD_APPLIED',
         'LEGAL_HOLD_REMOVAL_REQUESTED', 'LEGAL_HOLD_REMOVED',
         'DELETION_ALLOWED', 'DELETION_DENIED', 'DELETION_COMPLETED',
         'STORAGE_DELETION_COMPLETED'
       )
     ) then
    raise exception using errcode = '55000',
      message = 'Rollback de retencao recusado: existe estado indispensavel';
  end if;
end
$$;

drop trigger if exists clients_prevent_reidentification on public.clients;
drop trigger if exists protected_payloads_guard_retention_delete on app_private.protected_payloads;
drop trigger if exists protected_file_refs_guard_retention_delete on app_private.protected_file_refs;
drop trigger if exists retention_controls_enforce_target on app_private.retention_controls;
drop trigger if exists retention_controls_set_updated_at on app_private.retention_controls;
drop trigger if exists retention_policies_set_updated_at on app_private.retention_policies;
drop function if exists app_private.guard_retention_controlled_delete();
drop function if exists app_private.prevent_client_reidentification();
drop function if exists app_private.enforce_retention_control_target();
drop function if exists app_private.cancel_retention_deletion(uuid, text, text);
drop function if exists app_private.complete_retention_deletion(uuid, boolean, text);
drop function if exists app_private.prepare_retention_deletion(uuid[], text, text);
drop function if exists app_private.anonymize_clients(uuid[], text);
drop function if exists app_private.remove_legal_hold(uuid, text, text);
drop function if exists app_private.request_legal_hold_removal(uuid, text, text);
drop function if exists app_private.apply_legal_hold(uuid, text, text, text);
drop function if exists app_private.evaluate_retention_action(uuid, text, text);
drop function if exists audit.record_retention_event(text, text, uuid, uuid, text, boolean, text, text);

drop table if exists app_private.retention_controls;
drop table if exists app_private.retention_policies;

commit;
