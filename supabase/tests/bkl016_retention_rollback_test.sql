\set ON_ERROR_STOP on

do $$
begin
  if to_regclass('app_private.retention_policies') is not null
     or to_regclass('app_private.retention_controls') is not null then
    raise exception 'rollback deixou tabelas de retencao';
  end if;
  if to_regprocedure('app_private.anonymize_clients(uuid[],text)') is not null
     or to_regprocedure('app_private.prepare_retention_deletion(uuid[],text,text)') is not null
     or to_regprocedure('audit.record_retention_event(text,text,uuid,uuid,text,boolean,text,text)') is not null then
    raise exception 'rollback deixou funcoes de retencao';
  end if;
  if exists (select 1 from pg_trigger where tgname in (
    'clients_prevent_reidentification', 'protected_payloads_guard_retention_delete',
    'protected_file_refs_guard_retention_delete'
  )) then raise exception 'rollback deixou triggers de retencao'; end if;
end
$$;

select 'BKL-016 retention rollback checks passed' as result;
