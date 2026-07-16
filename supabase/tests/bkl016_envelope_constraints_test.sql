\set ON_ERROR_STOP on

begin;

insert into public.clients (id, display_name, journey_state)
values (
  '91000000-0000-4000-8000-000000000001',
  '[SYNTHETIC TEST] Cliente envelope',
  'NEW'
);

insert into public.technical_operations (
  operation_id, client_id, product, action, session_alias
) values (
  '92000000-0000-4000-8000-000000000001',
  '91000000-0000-4000-8000-000000000001',
  'FGTS',
  'CONSULTAR',
  'synthetic-envelope-test'
);

-- Compatibilidade explicita: uma linha anterior a esta migration continua
-- valida, mas nao deve ser usada para novas escritas do servico envelope.
insert into app_private.protected_payloads (
  id, client_id, operation_id, payload_type, ciphertext,
  encryption_key_ref, encryption_version, retention_until
) values (
  '93000000-0000-4000-8000-000000000001',
  '91000000-0000-4000-8000-000000000001',
  '92000000-0000-4000-8000-000000000001',
  'SYNTHETIC_LEGACY', decode('01', 'hex'),
  'synthetic-local-key', 'legacy-v1', now() + interval '1 day'
);

-- Envelope completo de payload.
insert into app_private.protected_payloads (
  id, client_id, operation_id, payload_type, ciphertext,
  encryption_key_ref, encryption_version, retention_until,
  envelope_algorithm, envelope_version, wrapped_dek, content_nonce,
  authentication_tag, aad_version, aad_sha256
) values (
  '93000000-0000-4000-8000-000000000002',
  '91000000-0000-4000-8000-000000000001',
  '92000000-0000-4000-8000-000000000001',
  'SYNTHETIC_ENVELOPE', decode(repeat('11', 32), 'hex'),
  'local-test-kek', 'local-v1', now() + interval '1 day',
  'AES-256-GCM', 1, decode(repeat('aa', 64), 'hex'),
  decode(repeat('bb', 12), 'hex'), decode(repeat('cc', 16), 'hex'),
  1, repeat('d', 64)
);

-- Envelope completo de arquivo; ciphertext permanece no bucket privado.
insert into app_private.protected_file_refs (
  id, client_id, operation_id, bucket_name, object_key,
  encryption_key_ref, encryption_version, retention_until,
  envelope_algorithm, envelope_version, wrapped_dek, content_nonce,
  authentication_tag, aad_version, aad_sha256
) values (
  '94000000-0000-4000-8000-000000000001',
  '91000000-0000-4000-8000-000000000001',
  '92000000-0000-4000-8000-000000000001',
  'cbn-temporary-private',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/eeeeeeeeeeeeeeee',
  'local-test-kek', 'local-v1', now() + interval '1 day',
  'AES-256-GCM', 1, decode(repeat('ab', 64), 'hex'),
  decode(repeat('bc', 12), 'hex'), decode(repeat('cd', 16), 'hex'),
  1, repeat('e', 64)
);

do $$
begin
  begin
    insert into app_private.protected_payloads (
      client_id, operation_id, payload_type, ciphertext,
      encryption_key_ref, encryption_version, retention_until,
      envelope_algorithm, envelope_version, wrapped_dek, content_nonce,
      authentication_tag, aad_version, aad_sha256
    ) values (
      '91000000-0000-4000-8000-000000000001',
      '92000000-0000-4000-8000-000000000001',
      'SYNTHETIC_BAD_ALGORITHM', decode('01', 'hex'),
      'local-test-kek', 'local-v1', now() + interval '1 day',
      'AES-128-CBC', 1, decode(repeat('aa', 64), 'hex'),
      decode(repeat('bb', 12), 'hex'), decode(repeat('cc', 16), 'hex'),
      1, repeat('d', 64)
    );
    raise exception 'algoritmo incorreto foi aceito';
  exception when check_violation then
    null;
  end;

  begin
    insert into app_private.protected_payloads (
      client_id, operation_id, payload_type, ciphertext,
      encryption_key_ref, encryption_version, retention_until,
      envelope_algorithm, envelope_version, wrapped_dek, content_nonce,
      authentication_tag, aad_version, aad_sha256
    ) values (
      '91000000-0000-4000-8000-000000000001',
      '92000000-0000-4000-8000-000000000001',
      'SYNTHETIC_NULL_ALGORITHM', decode('01', 'hex'),
      'local-test-kek', 'local-v1', now() + interval '1 day',
      null, 1, decode(repeat('aa', 64), 'hex'),
      decode(repeat('bb', 12), 'hex'), decode(repeat('cc', 16), 'hex'),
      1, repeat('d', 64)
    );
    raise exception 'envelope parcial com algoritmo nulo foi aceito';
  exception when check_violation then
    null;
  end;

  begin
    insert into app_private.protected_payloads (
      client_id, operation_id, payload_type, ciphertext,
      encryption_key_ref, encryption_version, retention_until,
      envelope_algorithm, envelope_version, wrapped_dek, content_nonce,
      authentication_tag, aad_version, aad_sha256
    ) values (
      '91000000-0000-4000-8000-000000000001',
      '92000000-0000-4000-8000-000000000001',
      'SYNTHETIC_BAD_NONCE', decode('01', 'hex'),
      'local-test-kek', 'local-v1', now() + interval '1 day',
      'AES-256-GCM', 1, decode(repeat('aa', 64), 'hex'),
      decode(repeat('bb', 11), 'hex'), decode(repeat('cc', 16), 'hex'),
      1, repeat('d', 64)
    );
    raise exception 'nonce com tamanho incorreto foi aceito';
  exception when check_violation then
    null;
  end;

  begin
    insert into app_private.protected_payloads (
      client_id, operation_id, payload_type, ciphertext,
      encryption_key_ref, encryption_version, retention_until,
      envelope_algorithm, envelope_version, wrapped_dek, content_nonce,
      authentication_tag, aad_version, aad_sha256
    ) values (
      '91000000-0000-4000-8000-000000000001',
      '92000000-0000-4000-8000-000000000001',
      'SYNTHETIC_BAD_TAG', decode('01', 'hex'),
      'local-test-kek', 'local-v1', now() + interval '1 day',
      'AES-256-GCM', 1, decode(repeat('aa', 64), 'hex'),
      decode(repeat('bb', 12), 'hex'), decode(repeat('cc', 15), 'hex'),
      1, repeat('d', 64)
    );
    raise exception 'tag com tamanho incorreto foi aceita';
  exception when check_violation then
    null;
  end;

  begin
    insert into app_private.protected_payloads (
      client_id, operation_id, payload_type, ciphertext,
      encryption_key_ref, encryption_version, retention_until,
      envelope_algorithm, envelope_version
    ) values (
      '91000000-0000-4000-8000-000000000001',
      '92000000-0000-4000-8000-000000000001',
      'SYNTHETIC_PARTIAL', decode('01', 'hex'),
      'local-test-kek', 'local-v1', now() + interval '1 day',
      'AES-256-GCM', 1
    );
    raise exception 'envelope parcial foi aceito';
  exception when check_violation then
    null;
  end;

  begin
    insert into app_private.protected_file_refs (
      client_id, operation_id, bucket_name, object_key,
      encryption_key_ref, encryption_version, retention_until,
      envelope_algorithm, envelope_version, wrapped_dek, content_nonce,
      authentication_tag, aad_version, aad_sha256
    ) values (
      '91000000-0000-4000-8000-000000000001',
      '92000000-0000-4000-8000-000000000001',
      'cbn-temporary-private',
      'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb/ffffffffffffffff',
      '', 'local-v1', now() + interval '1 day',
      'AES-256-GCM', 1, decode(repeat('aa', 64), 'hex'),
      decode(repeat('bb', 12), 'hex'), decode(repeat('cc', 16), 'hex'),
      1, repeat('d', 64)
    );
    raise exception 'referencia de chave vazia foi aceita';
  exception when check_violation then
    null;
  end;
end
$$;

select 'BKL-016 envelope database constraints passed' as result;

rollback;
