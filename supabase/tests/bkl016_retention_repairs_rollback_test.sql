\set ON_ERROR_STOP on

do $$
begin
  if exists (select 1 from pg_trigger where tgname in (
    'client_sensitive_prevent_reidentification',
    'proposal_sensitive_prevent_reidentification',
    'protected_payload_prevent_reidentification',
    'protected_file_prevent_reidentification',
    'proposals_prevent_reidentification',
    'interactions_prevent_reidentification',
    'pending_items_prevent_reidentification'
  )) then
    raise exception 'rollback deixou triggers incrementais de reidentificacao';
  end if;
  if to_regclass('app_private.retention_controls') is null
     or to_regprocedure('app_private.evaluate_retention_action(uuid,text,text)') is null then
    raise exception 'rollback dos reparos removeu estrutura base indispensavel';
  end if;
end
$$;

select 'BKL-016 retention repair rollback checks passed' as result;
