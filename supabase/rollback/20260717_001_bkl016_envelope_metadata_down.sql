-- BKL-016 - rollback manual dos metadados de envelope.
-- Fail closed: remover estes campos com envelopes gravados destruiria a
-- capacidade de descriptografar dados ainda validos.

begin;

do $$
begin
  if exists (
    select 1
    from app_private.protected_payloads
    where envelope_version is not null
  ) or exists (
    select 1
    from app_private.protected_file_refs
    where envelope_version is not null
  ) then
    raise exception using
      errcode = '55000',
      message = 'Rollback de envelope recusado: existem envelopes novos';
  end if;
end
$$;

alter table app_private.protected_payloads
  drop constraint if exists protected_payloads_envelope_coherence_ck,
  drop constraint if exists protected_payloads_envelope_key_ref_ck,
  drop constraint if exists protected_payloads_envelope_aad_ck,
  drop constraint if exists protected_payloads_envelope_binary_sizes_ck,
  drop constraint if exists protected_payloads_envelope_version_ck,
  drop constraint if exists protected_payloads_envelope_algorithm_ck;

alter table app_private.protected_payloads
  drop column if exists aad_sha256,
  drop column if exists aad_version,
  drop column if exists authentication_tag,
  drop column if exists content_nonce,
  drop column if exists wrapped_dek,
  drop column if exists envelope_version,
  drop column if exists envelope_algorithm;

alter table app_private.protected_file_refs
  drop constraint if exists protected_file_refs_envelope_coherence_ck,
  drop constraint if exists protected_file_refs_envelope_key_ref_ck,
  drop constraint if exists protected_file_refs_envelope_aad_ck,
  drop constraint if exists protected_file_refs_envelope_binary_sizes_ck,
  drop constraint if exists protected_file_refs_envelope_version_ck,
  drop constraint if exists protected_file_refs_envelope_algorithm_ck;

alter table app_private.protected_file_refs
  drop column if exists aad_sha256,
  drop column if exists aad_version,
  drop column if exists authentication_tag,
  drop column if exists content_nonce,
  drop column if exists wrapped_dek,
  drop column if exists envelope_version,
  drop column if exists envelope_algorithm,
  drop column if exists encryption_version;

commit;
