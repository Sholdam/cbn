-- Rollback fail-closed dos reparos de retencao/legal hold.
-- As redefinicoes conservadoras das funcoes permanecem intencionalmente; voltar
-- ao comportamento vulneravel nao e uma operacao segura.
begin;

do $$
begin
  if exists (select 1 from app_private.retention_controls)
     or exists (select 1 from app_private.retention_policies)
     or exists (select 1 from public.clients where anonymized_at is not null)
     or exists (select 1 from audit.events where event_type in (
       'RETENTION_EVALUATED', 'ANONYMIZATION_DENIED', 'ANONYMIZATION_COMPLETED',
       'LEGAL_HOLD_APPLIED', 'LEGAL_HOLD_REMOVAL_REQUESTED', 'LEGAL_HOLD_REMOVED',
       'DELETION_DENIED', 'DELETION_COMPLETED', 'STORAGE_DELETION_COMPLETED'
     )) then
    raise exception using errcode = '55000',
      message = 'Rollback dos reparos recusado: existe estado ou auditoria indispensavel';
  end if;
end
$$;

drop trigger if exists client_sensitive_prevent_reidentification on app_private.client_sensitive_data;
drop trigger if exists proposal_sensitive_prevent_reidentification on app_private.proposal_sensitive_data;
drop trigger if exists protected_payload_prevent_reidentification on app_private.protected_payloads;
drop trigger if exists protected_file_prevent_reidentification on app_private.protected_file_refs;
drop trigger if exists proposals_prevent_reidentification on public.proposals;
drop trigger if exists interactions_prevent_reidentification on public.interactions;
drop trigger if exists pending_items_prevent_reidentification on public.pending_items;
drop function if exists app_private.guard_anonymized_client_private_write();
drop function if exists app_private.guard_anonymized_client_public_child();

-- Helpers de escopo sao mantidos porque as funcoes reparadas dependem deles.
-- Um rollback destrutivo exigiria restaurar deliberadamente o defeito anterior.

commit;
