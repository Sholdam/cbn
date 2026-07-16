-- BKL-016 - metadados versionados para criptografia envelope.
-- Esta migration nao executa criptografia e nao cria chaves. Ela apenas
-- persiste, de forma atomica, o material necessario para recuperar envelopes
-- produzidos pelo servico backend autorizado.

begin;

alter table app_private.protected_payloads
  add column if not exists envelope_algorithm text,
  add column if not exists envelope_version smallint,
  add column if not exists wrapped_dek bytea,
  add column if not exists content_nonce bytea,
  add column if not exists authentication_tag bytea,
  add column if not exists aad_version smallint,
  add column if not exists aad_sha256 text;

alter table app_private.protected_payloads
  drop constraint if exists protected_payloads_envelope_algorithm_ck,
  drop constraint if exists protected_payloads_envelope_version_ck,
  drop constraint if exists protected_payloads_envelope_binary_sizes_ck,
  drop constraint if exists protected_payloads_envelope_aad_ck,
  drop constraint if exists protected_payloads_envelope_key_ref_ck,
  drop constraint if exists protected_payloads_envelope_coherence_ck;

alter table app_private.protected_payloads
  add constraint protected_payloads_envelope_algorithm_ck check (
    envelope_algorithm is null or envelope_algorithm = 'AES-256-GCM'
  ),
  add constraint protected_payloads_envelope_version_ck check (
    envelope_version is null or envelope_version = 1
  ),
  add constraint protected_payloads_envelope_binary_sizes_ck check (
    (wrapped_dek is null or octet_length(wrapped_dek) between 32 and 16384)
    and (content_nonce is null or octet_length(content_nonce) = 12)
    and (authentication_tag is null or octet_length(authentication_tag) = 16)
  ),
  add constraint protected_payloads_envelope_aad_ck check (
    aad_version is null or (
      aad_version = 1
      and aad_sha256 ~ '^[a-f0-9]{64}$'
    )
  ),
  add constraint protected_payloads_envelope_key_ref_ck check (
    envelope_version is null or (
      btrim(encryption_key_ref) <> ''
      and btrim(encryption_version) <> ''
    )
  ),
  add constraint protected_payloads_envelope_coherence_ck check (
    (
      num_nonnulls(
        envelope_algorithm, envelope_version, wrapped_dek, content_nonce,
        authentication_tag, aad_version, aad_sha256
      ) = 0
    )
    or (
      num_nonnulls(
        envelope_algorithm, envelope_version, wrapped_dek, content_nonce,
        authentication_tag, aad_version, aad_sha256
      ) = 7
      and envelope_algorithm = 'AES-256-GCM'
      and envelope_version = 1
      and wrapped_dek is not null
      and content_nonce is not null
      and authentication_tag is not null
      and aad_version = 1
      and aad_sha256 is not null
      and octet_length(ciphertext) > 0
    )
  );

comment on column app_private.protected_payloads.envelope_algorithm is
  'Algoritmo de conteudo. BKL-016 aceita apenas AES-256-GCM na versao 1.';
comment on column app_private.protected_payloads.wrapped_dek is
  'DEK aleatoria cifrada pelo adaptador KMS; nunca armazena a DEK em claro.';
comment on column app_private.protected_payloads.content_nonce is
  'Nonce unico de 12 bytes usado no AES-GCM; nao e secreto.';
comment on column app_private.protected_payloads.authentication_tag is
  'Tag de autenticacao de 16 bytes produzida pelo AES-GCM.';
comment on column app_private.protected_payloads.aad_sha256 is
  'SHA-256 hexadecimal da AAD canonica; a AAD contem apenas identificadores e contexto.';

alter table app_private.protected_file_refs
  add column if not exists encryption_version text,
  add column if not exists envelope_algorithm text,
  add column if not exists envelope_version smallint,
  add column if not exists wrapped_dek bytea,
  add column if not exists content_nonce bytea,
  add column if not exists authentication_tag bytea,
  add column if not exists aad_version smallint,
  add column if not exists aad_sha256 text;

alter table app_private.protected_file_refs
  drop constraint if exists protected_file_refs_envelope_algorithm_ck,
  drop constraint if exists protected_file_refs_envelope_version_ck,
  drop constraint if exists protected_file_refs_envelope_binary_sizes_ck,
  drop constraint if exists protected_file_refs_envelope_aad_ck,
  drop constraint if exists protected_file_refs_envelope_key_ref_ck,
  drop constraint if exists protected_file_refs_envelope_coherence_ck;

alter table app_private.protected_file_refs
  add constraint protected_file_refs_envelope_algorithm_ck check (
    envelope_algorithm is null or envelope_algorithm = 'AES-256-GCM'
  ),
  add constraint protected_file_refs_envelope_version_ck check (
    envelope_version is null or envelope_version = 1
  ),
  add constraint protected_file_refs_envelope_binary_sizes_ck check (
    (wrapped_dek is null or octet_length(wrapped_dek) between 32 and 16384)
    and (content_nonce is null or octet_length(content_nonce) = 12)
    and (authentication_tag is null or octet_length(authentication_tag) = 16)
  ),
  add constraint protected_file_refs_envelope_aad_ck check (
    aad_version is null or (
      aad_version = 1
      and aad_sha256 ~ '^[a-f0-9]{64}$'
    )
  ),
  add constraint protected_file_refs_envelope_key_ref_ck check (
    envelope_version is null or (
      encryption_key_ref is not null
      and btrim(encryption_key_ref) <> ''
      and encryption_version is not null
      and btrim(encryption_version) <> ''
    )
  ),
  add constraint protected_file_refs_envelope_coherence_ck check (
    (
      num_nonnulls(
        envelope_algorithm, envelope_version, wrapped_dek, content_nonce,
        authentication_tag, aad_version, aad_sha256
      ) = 0
    )
    or (
      num_nonnulls(
        envelope_algorithm, envelope_version, wrapped_dek, content_nonce,
        authentication_tag, aad_version, aad_sha256
      ) = 7
      and envelope_algorithm = 'AES-256-GCM'
      and envelope_version = 1
      and wrapped_dek is not null
      and content_nonce is not null
      and authentication_tag is not null
      and aad_version = 1
      and aad_sha256 is not null
    )
  );

comment on column app_private.protected_file_refs.encryption_version is
  'Versao imutavel da KEK que protegeu a DEK do objeto.';
comment on column app_private.protected_file_refs.wrapped_dek is
  'DEK aleatoria cifrada pelo adaptador KMS; nunca armazena a DEK em claro.';
comment on column app_private.protected_file_refs.aad_sha256 is
  'SHA-256 hexadecimal da AAD canonica, incluindo bucket e object_key.';

commit;
