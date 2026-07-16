\set ON_ERROR_STOP on

do $$
declare
  unexpected_count integer;
begin
  select count(*)
  into unexpected_count
  from information_schema.columns
  where table_schema = 'app_private'
    and table_name in ('protected_payloads', 'protected_file_refs')
    and column_name in (
      'envelope_algorithm', 'envelope_version', 'wrapped_dek',
      'content_nonce', 'authentication_tag', 'aad_version', 'aad_sha256'
    );

  if unexpected_count <> 0 then
    raise exception 'rollback deixou % colunas de envelope', unexpected_count;
  end if;

  if exists (
    select 1
    from pg_constraint
    where conname like 'protected_payloads_envelope_%'
       or conname like 'protected_file_refs_envelope_%'
  ) then
    raise exception 'rollback deixou constraints de envelope';
  end if;

  if to_regclass('app_private.protected_payloads') is null
     or to_regclass('app_private.protected_file_refs') is null then
    raise exception 'rollback removeu tabelas base da BKL-016';
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'app_private'
      and table_name = 'protected_file_refs'
      and column_name = 'encryption_version'
  ) then
    raise exception 'rollback deixou encryption_version incremental em protected_file_refs';
  end if;
end
$$;

select 'BKL-016 envelope rollback checks passed' as result;
