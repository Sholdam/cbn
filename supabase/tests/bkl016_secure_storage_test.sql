-- BKL-016 — testes de banco e RLS com fixtures exclusivamente sinteticas.
-- Execute somente em uma base Supabase local descartavel, depois da migration:
--   supabase db reset
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/bkl016_secure_storage_test.sql
-- O arquivo restaura role/claims e termina com ROLLBACK.

begin;

-- Estrutura e RLS.
do $$
declare
  expected text[] := array[
    'public.clients', 'public.consultations', 'public.offers',
    'public.proposals', 'public.interactions', 'public.pending_items',
    'public.technical_operations', 'public.user_profiles',
    'app_private.client_sensitive_data',
    'app_private.proposal_sensitive_data',
    'app_private.protected_payloads',
    'app_private.protected_file_refs', 'audit.events'
  ];
  item text;
  missing text;
begin
  foreach item in array expected loop
    if to_regclass(item) is null then
      raise exception 'Tabela esperada ausente: %', item;
    end if;
  end loop;

  select string_agg(format('%I.%I', n.nspname, c.relname), ', ')
    into missing
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where (n.nspname, c.relname) in (
    ('public', 'clients'), ('public', 'consultations'), ('public', 'offers'),
    ('public', 'proposals'), ('public', 'interactions'),
    ('public', 'pending_items'), ('public', 'technical_operations'),
    ('public', 'user_profiles'),
    ('app_private', 'client_sensitive_data'),
    ('app_private', 'proposal_sensitive_data'),
    ('app_private', 'protected_payloads'),
    ('app_private', 'protected_file_refs'), ('audit', 'events')
  ) and not c.relrowsecurity;

  if missing is not null then
    raise exception 'RLS desativada em: %', missing;
  end if;
end $$;

-- SECURITY DEFINER deve fixar search_path vazio; anon nao recebe EXECUTE.
do $$
declare
  unsafe_functions text;
  anon_execute_count integer;
begin
  select string_agg(format('%I.%I', n.nspname, p.proname), ', ')
    into unsafe_functions
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname in ('app_private', 'audit')
    and p.prosecdef
    and not ('search_path=""' = any(coalesce(p.proconfig, array[]::text[])));

  if unsafe_functions is not null then
    raise exception 'SECURITY DEFINER sem search_path vazio: %', unsafe_functions;
  end if;

  select count(*) into anon_execute_count
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'app_private'
    and p.proname in (
      'current_user_role', 'has_app_role', 'get_client_sensitive_summary'
    )
    and has_function_privilege('anon', p.oid, 'EXECUTE');

  if anon_execute_count <> 0 then
    raise exception 'anon possui EXECUTE desnecessario em funcao privada';
  end if;
end $$;

-- Usuarios Auth sinteticos. Nao ha senha utilizavel nem e-mail real.
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, email_change,
  email_change_token_new, recovery_token
) values
  ('00000000-0000-0000-0000-000000000000', '81000000-0000-4000-8000-000000000001',
   'authenticated', 'authenticated', 'admin.bkl016@example.invalid', '', now(),
   '{"provider":"email","providers":["email"]}', '{"fixture":"synthetic"}',
   now(), now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '81000000-0000-4000-8000-000000000002',
   'authenticated', 'authenticated', 'operations.bkl016@example.invalid', '', now(),
   '{"provider":"email","providers":["email"]}', '{"fixture":"synthetic"}',
   now(), now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '81000000-0000-4000-8000-000000000003',
   'authenticated', 'authenticated', 'support.bkl016@example.invalid', '', now(),
   '{"provider":"email","providers":["email"]}', '{"fixture":"synthetic"}',
   now(), now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '81000000-0000-4000-8000-000000000004',
   'authenticated', 'authenticated', 'auditor.bkl016@example.invalid', '', now(),
   '{"provider":"email","providers":["email"]}', '{"fixture":"synthetic"}',
   now(), now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '81000000-0000-4000-8000-000000000005',
   'authenticated', 'authenticated', 'no-profile.bkl016@example.invalid', '', now(),
   '{"provider":"email","providers":["email"]}', '{"fixture":"synthetic"}',
   now(), now(), '', '', '', '');

insert into public.user_profiles (user_id, role, display_name) values
  ('81000000-0000-4000-8000-000000000001', 'admin', '[SYNTHETIC TEST] Admin'),
  ('81000000-0000-4000-8000-000000000002', 'operations', '[SYNTHETIC TEST] Operations'),
  ('81000000-0000-4000-8000-000000000003', 'support', '[SYNTHETIC TEST] Support'),
  ('81000000-0000-4000-8000-000000000004', 'auditor', '[SYNTHETIC TEST] Auditor');

select set_config('app.change_origin', 'system', true);

-- Fixtures operacionais, privadas e de auditoria.
insert into public.clients (
  id, display_name, phone_masked, cpf_masked, lead_source, journey_state
) values (
  '82000000-0000-4000-8000-000000000001',
  '[SYNTHETIC TEST] RLS Fixture', '+55 ** *****-0000',
  '***.***.***-00', 'synthetic_rls_test', 'TEST_READY'
);

insert into public.technical_operations (
  operation_id, correlation_id, client_id, product, action,
  session_alias, state, attempt_count
) values
  ('83000000-0000-4000-8000-000000000001',
   '83000000-0000-4000-8000-000000000011',
   '82000000-0000-4000-8000-000000000001', 'FGTS', 'CONSULTAR',
   'synthetic-fgts-alias', 'COMPLETED', 1),
  ('83000000-0000-4000-8000-000000000002',
   '83000000-0000-4000-8000-000000000012',
   '82000000-0000-4000-8000-000000000001', 'FGTS', 'CRIAR_PROPOSTA',
   'synthetic-fgts-alias', 'COMPLETED', 1);

insert into public.consultations (
  id, client_id, product, operation_id, status_raw,
  status_normalized, response_code, session_alias
) values (
  '84000000-0000-4000-8000-000000000001',
  '82000000-0000-4000-8000-000000000001', 'FGTS',
  '83000000-0000-4000-8000-000000000001',
  'SYNTHETIC_SUCCESS', 'COMPLETED', 'SYNTHETIC_OK', 'synthetic-fgts-alias'
);

insert into public.offers (
  id, consultation_id, client_id, product, operation_id,
  lender_code, lender_name, plan_code, term_count,
  installment_amount, released_amount, snapshot_hash
) values (
  '84000000-0000-4000-8000-000000000002',
  '84000000-0000-4000-8000-000000000001',
  '82000000-0000-4000-8000-000000000001', 'FGTS',
  '83000000-0000-4000-8000-000000000001',
  'SYNTHETIC_BANK', '[SYNTHETIC TEST] Banco', 'SYNTHETIC_PLAN',
  12, 10.00, 100.00,
  '0000000000000000000000000000000000000000000000000000000000000000'
);

insert into app_private.protected_payloads (
  id, client_id, operation_id, payload_type, ciphertext,
  encryption_key_ref, encryption_version, retention_until
) values
  ('85000000-0000-4000-8000-000000000001',
   '82000000-0000-4000-8000-000000000001',
   '83000000-0000-4000-8000-000000000002',
   'FINAL_AUTHORIZATION_EVIDENCE', decode('53594e544845544943', 'hex'),
   'synthetic-kms-key-ref', 'synthetic-v1', now() + interval '1 day'),
  ('85000000-0000-4000-8000-000000000002',
   '82000000-0000-4000-8000-000000000001', null,
   'SYNTHETIC_GENERIC_PAYLOAD', decode('00', 'hex'),
   'synthetic-kms-key-ref', 'synthetic-v1', now() + interval '1 day');

insert into public.proposals (
  id, client_id, offer_id, product, operation_id,
  status_raw, status_normalized,
  final_authorization_evidence_payload_ref, authorized_at
) values (
  '86000000-0000-4000-8000-000000000001',
  '82000000-0000-4000-8000-000000000001',
  '84000000-0000-4000-8000-000000000002', 'FGTS',
  '83000000-0000-4000-8000-000000000002',
  'SYNTHETIC_CREATED', 'CREATED',
  '85000000-0000-4000-8000-000000000001', now()
);

insert into public.interactions (
  id, client_id, proposal_id, product, channel, direction,
  event_type, event_summary_masked, actor_type
) values (
  '87000000-0000-4000-8000-000000000001',
  '82000000-0000-4000-8000-000000000001',
  '86000000-0000-4000-8000-000000000001', 'FGTS',
  'INTERNAL_TEST', 'INTERNAL', 'SYNTHETIC_EVENT',
  '[SYNTHETIC TEST] evento mascarado', 'system'
);

insert into public.pending_items (
  id, client_id, proposal_id, product, pending_type,
  priority, pending_action, pending_reason_masked, status
) values (
  '88000000-0000-4000-8000-000000000001',
  '82000000-0000-4000-8000-000000000001',
  '86000000-0000-4000-8000-000000000001', 'FGTS',
  'SYNTHETIC_REVIEW', 'NORMAL', 'CONTACT_CLIENT',
  '[SYNTHETIC TEST] motivo mascarado', 'OPEN'
);

insert into app_private.client_sensitive_data (
  client_id, cpf_ciphertext, cpf_lookup_token, cpf_last4,
  encryption_key_ref, encryption_version, retention_until
) values (
  '82000000-0000-4000-8000-000000000001', decode('00', 'hex'),
  'synthetic-opaque-lookup-token', '0000',
  'synthetic-kms-key-ref', 'synthetic-v1', now() + interval '1 day'
);

-- Constraints de mascara rejeitam valores completos, inclusive se um asterisco
-- for prefixado a todos os digitos. Os valores sao construidos em runtime.
do $$
begin
  begin
    insert into public.clients (id, display_name, cpf_masked)
    values (
      '89000000-0000-4000-8000-000000000001',
      '[SYNTHETIC TEST] CPF completo', repeat('1', 11)
    );
    raise exception 'CPF completo foi aceito em cpf_masked';
  exception when check_violation then null;
  end;

  begin
    insert into public.clients (id, display_name, cpf_masked)
    values (
      '89000000-0000-4000-8000-000000000002',
      '[SYNTHETIC TEST] CPF completo com mascara falsa', '*' || repeat('1', 11)
    );
    raise exception 'CPF completo prefixado por asterisco foi aceito';
  exception when check_violation then null;
  end;

  begin
    insert into public.clients (id, display_name, phone_masked)
    values (
      '89000000-0000-4000-8000-000000000003',
      '[SYNTHETIC TEST] Telefone completo', '+' || repeat('5', 13)
    );
    raise exception 'Telefone completo foi aceito em phone_masked';
  exception when check_violation then null;
  end;

  begin
    insert into public.clients (id, display_name, phone_masked)
    values (
      '89000000-0000-4000-8000-000000000004',
      '[SYNTHETIC TEST] Telefone completo com mascara falsa', '*' || repeat('5', 13)
    );
    raise exception 'Telefone completo prefixado por asterisco foi aceito';
  exception when check_violation then null;
  end;
end $$;

-- event_type aceita somente codigo normalizado conservador.
do $$
begin
  begin
    insert into public.interactions (
      id, client_id, channel, direction, event_type, actor_type
    ) values (
      '87000000-0000-4000-8000-000000000099',
      '82000000-0000-4000-8000-000000000001',
      'INTERNAL_TEST', 'INTERNAL', 'invalid event text', 'system'
    );
    raise exception 'event_type livre foi aceito';
  exception when check_violation then null;
  end;
end $$;

-- operation_id e unico; produto aceita somente FGTS/CLT.
do $$
begin
  begin
    insert into public.technical_operations (
      operation_id, product, action, session_alias
    ) values (
      '83000000-0000-4000-8000-000000000001', 'FGTS',
      'CONSULTAR', 'synthetic-duplicate-alias'
    );
    raise exception 'operation_id duplicado foi aceito';
  exception when unique_violation then null;
  end;

  begin
    perform 'INVALID_PRODUCT'::public.credit_product;
    raise exception 'Produto invalido foi aceito';
  exception when invalid_text_representation then null;
  end;
end $$;

-- Proposta exige oferta coerente e evidencia protegida valida.
insert into public.technical_operations (
  operation_id, correlation_id, client_id, product, action, session_alias
) values
  ('83000000-0000-4000-8000-000000000003',
   '83000000-0000-4000-8000-000000000013',
   '82000000-0000-4000-8000-000000000001', 'FGTS',
   'CRIAR_PROPOSTA', 'synthetic-fgts-alias'),
  ('83000000-0000-4000-8000-000000000004',
   '83000000-0000-4000-8000-000000000014',
   '82000000-0000-4000-8000-000000000001', 'CLT',
   'CRIAR_PROPOSTA', 'synthetic-clt-alias'),
  ('83000000-0000-4000-8000-000000000005',
   '83000000-0000-4000-8000-000000000015',
   '82000000-0000-4000-8000-000000000001', 'FGTS',
   'CRIAR_PROPOSTA', 'synthetic-fgts-alias');

do $$
begin
  begin
    insert into public.proposals (
      id, client_id, offer_id, product, operation_id,
      final_authorization_evidence_payload_ref, authorized_at
    ) values (
      '86000000-0000-4000-8000-000000000002',
      '82000000-0000-4000-8000-000000000001',
      '84000000-0000-4000-8000-000000000002', 'FGTS',
      '83000000-0000-4000-8000-000000000003',
      '85000000-0000-4000-8000-000000000099', now()
    );
    raise exception 'Proposta sem evidencia protegida valida foi aceita';
  exception when foreign_key_violation then null;
  end;

  begin
    insert into public.proposals (
      id, client_id, offer_id, product, operation_id,
      final_authorization_evidence_payload_ref, authorized_at
    ) values (
      '86000000-0000-4000-8000-000000000005',
      '82000000-0000-4000-8000-000000000001',
      '84000000-0000-4000-8000-000000000002', 'FGTS',
      '83000000-0000-4000-8000-000000000003',
      '85000000-0000-4000-8000-000000000002', now()
    );
    raise exception 'Payload generico foi aceito como evidencia final';
  exception when foreign_key_violation then null;
  end;

  begin
    insert into public.proposals (
      id, client_id, offer_id, product, operation_id,
      final_authorization_evidence_payload_ref, authorized_at
    ) values (
      '86000000-0000-4000-8000-000000000003',
      '82000000-0000-4000-8000-000000000001',
      '84000000-0000-4000-8000-000000000002', 'CLT',
      '83000000-0000-4000-8000-000000000004',
      '85000000-0000-4000-8000-000000000001', now()
    );
    raise exception 'Proposta com oferta de outro produto foi aceita';
  exception when foreign_key_violation then null;
  end;

  begin
    insert into public.proposals (
      id, client_id, offer_id, product, operation_id,
      final_authorization_evidence_payload_ref, authorized_at
    ) values (
      '86000000-0000-4000-8000-000000000004',
      '82000000-0000-4000-8000-000000000001',
      '84000000-0000-4000-8000-000000000002', 'FGTS',
      '83000000-0000-4000-8000-000000000005', null, now()
    );
    raise exception 'Proposta sem evidencia foi aceita';
  exception when not_null_violation then null;
  end;
end $$;

-- anon: sem leitura interna, schema privado ou funcoes auxiliares.
set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claim.role', 'anon', true);
do $$
begin
  begin
    perform count(*) from public.clients;
    raise exception 'anon leu tabela interna';
  exception when insufficient_privilege then null;
  end;

  begin
    perform count(*) from app_private.client_sensitive_data;
    raise exception 'anon leu tabela privada';
  exception when insufficient_privilege then null;
  end;

  begin
    perform app_private.current_user_role();
    raise exception 'anon executou funcao auxiliar privada';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

-- authenticated sem perfil: grants existem, mas RLS retorna zero linhas.
set local role authenticated;
select set_config('request.jwt.claim.sub', '81000000-0000-4000-8000-000000000005', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
do $$
declare
  visible_rows integer;
begin
  select count(*) into visible_rows from public.clients;
  if visible_rows <> 0 then
    raise exception 'Usuario sem perfil leu dados operacionais';
  end if;

  begin
    perform count(*) from app_private.client_sensitive_data;
    raise exception 'Usuario sem perfil leu schema privado';
  exception when insufficient_privilege then null;
  end;

  select count(*) into visible_rows
  from app_private.get_client_sensitive_summary(
    '82000000-0000-4000-8000-000000000001', 'NO_PROFILE_TEST'
  );
  if visible_rows <> 0 then
    raise exception 'Usuario sem perfil recebeu resumo sensivel';
  end if;
end $$;
reset role;

-- auditor: leitura operacional/auditoria, nenhuma mutacao ou acesso privado.
set local role authenticated;
select set_config('request.jwt.claim.sub', '81000000-0000-4000-8000-000000000004', true);
do $$
declare
  visible_rows integer;
  affected integer;
begin
  select count(*) into visible_rows from public.clients
  where id = '82000000-0000-4000-8000-000000000001';
  if visible_rows <> 1 then raise exception 'Auditor nao leu dado permitido'; end if;

  select count(*) into visible_rows from public.audit_event_summaries;
  if visible_rows = 0 then raise exception 'Auditor nao leu trilha permitida'; end if;

  update public.clients set journey_state = 'AUDITOR_FORBIDDEN'
  where id = '82000000-0000-4000-8000-000000000001';
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'Auditor alterou cliente'; end if;

  delete from public.clients
  where id = '82000000-0000-4000-8000-000000000001';
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'Auditor excluiu cliente'; end if;

  begin
    insert into public.clients (display_name) values ('[SYNTHETIC TEST] Auditor insert');
    raise exception 'Auditor inseriu cliente';
  exception when insufficient_privilege then null;
  end;

  begin
    perform count(*) from app_private.client_sensitive_data;
    raise exception 'Auditor leu schema privado';
  exception when insufficient_privilege then null;
  end;

  select count(*) into visible_rows
  from app_private.get_client_sensitive_summary(
    '82000000-0000-4000-8000-000000000001', 'AUDIT_TEST'
  );
  if visible_rows <> 0 then raise exception 'Auditor recebeu resumo sensivel'; end if;
end $$;
reset role;

-- support: somente atendimento, interacao e tratamento controlado de pendencia.
set local role authenticated;
select set_config('request.jwt.claim.sub', '81000000-0000-4000-8000-000000000003', true);
do $$
declare
  visible_rows integer;
  affected integer;
begin
  select count(*) into visible_rows from public.clients
  where id = '82000000-0000-4000-8000-000000000001';
  if visible_rows <> 1 then raise exception 'Support nao leu cliente necessario'; end if;

  select count(*) into visible_rows from public.pending_items
  where id = '88000000-0000-4000-8000-000000000001';
  if visible_rows <> 1 then raise exception 'Support nao leu pendencia'; end if;

  select count(*) into visible_rows from public.consultations
  where id = '84000000-0000-4000-8000-000000000001';
  if visible_rows <> 1 then raise exception 'Support nao leu consulta necessaria'; end if;

  select count(*) into visible_rows from public.proposals
  where id = '86000000-0000-4000-8000-000000000001';
  if visible_rows <> 1 then raise exception 'Support nao leu proposta necessaria'; end if;

  select count(*) into visible_rows from public.interactions
  where id = '87000000-0000-4000-8000-000000000001';
  if visible_rows <> 1 then raise exception 'Support nao leu interacao necessaria'; end if;

  select count(*) into visible_rows from public.offers;
  if visible_rows <> 0 then raise exception 'Support leu ofertas fora do escopo'; end if;

  select count(*) into visible_rows from public.technical_operations;
  if visible_rows <> 0 then raise exception 'Support leu operacoes tecnicas'; end if;

  update public.pending_items
  set status = 'IN_PROGRESS', resolution_masked = '[SYNTHETIC TEST] em tratamento'
  where id = '88000000-0000-4000-8000-000000000001';
  get diagnostics affected = row_count;
  if affected <> 1 then raise exception 'Support nao tratou pendencia permitida'; end if;

  begin
    update public.pending_items set pending_type = 'FORBIDDEN_CHANGE'
    where id = '88000000-0000-4000-8000-000000000001';
    raise exception 'Support alterou estrutura da pendencia';
  exception when raise_exception then
    if sqlerrm <> 'Support pode alterar somente tratamento e resolucao da pendencia' then
      raise;
    end if;
  end;

  insert into public.interactions (
    client_id, proposal_id, product, channel, direction,
    event_type, event_summary_masked, actor_type
  ) values (
    '82000000-0000-4000-8000-000000000001',
    '86000000-0000-4000-8000-000000000001', 'FGTS',
    'INTERNAL_TEST', 'INTERNAL', 'SUPPORT_NOTE',
    '[SYNTHETIC TEST] nota mascarada', 'human'
  );

  update public.proposals set status_normalized = 'SUPPORT_FORBIDDEN'
  where id = '86000000-0000-4000-8000-000000000001';
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'Support alterou proposta'; end if;

  begin
    perform count(*) from app_private.client_sensitive_data;
    raise exception 'Support leu schema privado';
  exception when insufficient_privilege then null;
  end;

  select count(*) into visible_rows
  from app_private.get_client_sensitive_summary(
    '82000000-0000-4000-8000-000000000001', 'SUPPORT_TEST'
  );
  if visible_rows <> 0 then raise exception 'Support recebeu resumo sensivel'; end if;
end $$;
reset role;

-- operations: cria/atualiza operacionais, nao exclui; resumo controlado permitido.
set local role authenticated;
select set_config('request.jwt.claim.sub', '81000000-0000-4000-8000-000000000002', true);
do $$
declare
  visible_rows integer;
  affected integer;
begin
  insert into public.clients (id, display_name, journey_state)
  values (
    '82000000-0000-4000-8000-000000000002',
    '[SYNTHETIC TEST] Operations client', 'CREATED_BY_OPERATIONS'
  );

  update public.clients set journey_state = 'UPDATED_BY_OPERATIONS'
  where id = '82000000-0000-4000-8000-000000000002';
  get diagnostics affected = row_count;
  if affected <> 1 then raise exception 'Operations nao atualizou cliente'; end if;

  delete from public.clients
  where id = '82000000-0000-4000-8000-000000000002';
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'Operations excluiu cliente'; end if;

  update public.offers set selected_at = now()
  where id = '84000000-0000-4000-8000-000000000002';
  get diagnostics affected = row_count;
  if affected <> 1 then raise exception 'Operations nao marcou selecao permitida'; end if;

  begin
    update public.offers set lender_name = '[SYNTHETIC TEST] Alterado'
    where id = '84000000-0000-4000-8000-000000000002';
    raise exception 'Snapshot de oferta foi alterado';
  exception when raise_exception then
    if sqlerrm <> 'Snapshot de oferta e imutavel; crie uma nova oferta' then
      raise;
    end if;
  end;

  begin
    perform count(*) from app_private.client_sensitive_data;
    raise exception 'Operations leu diretamente schema privado';
  exception when insufficient_privilege then null;
  end;

  select count(*) into visible_rows
  from app_private.get_client_sensitive_summary(
    '82000000-0000-4000-8000-000000000001', 'OPERATIONS_TEST'
  );
  if visible_rows <> 1 then raise exception 'Operations nao recebeu resumo permitido'; end if;
end $$;
reset role;

-- admin: administracao operacional/perfis; ainda sem acesso direto ao privado.
set local role authenticated;
select set_config('request.jwt.claim.sub', '81000000-0000-4000-8000-000000000001', true);
do $$
declare
  visible_rows integer;
  affected integer;
begin
  insert into public.clients (id, display_name, journey_state)
  values (
    '82000000-0000-4000-8000-000000000003',
    '[SYNTHETIC TEST] Admin client', 'CREATED_BY_ADMIN'
  );

  update public.clients set journey_state = 'UPDATED_BY_ADMIN'
  where id = '82000000-0000-4000-8000-000000000003';
  get diagnostics affected = row_count;
  if affected <> 1 then raise exception 'Admin nao atualizou cliente'; end if;

  delete from public.clients
  where id = '82000000-0000-4000-8000-000000000003';
  get diagnostics affected = row_count;
  if affected <> 1 then raise exception 'Admin nao excluiu cliente isolado'; end if;

  update public.user_profiles set display_name = '[SYNTHETIC TEST] Support reviewed'
  where user_id = '81000000-0000-4000-8000-000000000003';
  get diagnostics affected = row_count;
  if affected <> 1 then raise exception 'Admin nao administrou perfil'; end if;

  begin
    perform count(*) from app_private.client_sensitive_data;
    raise exception 'Admin leu diretamente schema privado';
  exception when insufficient_privilege then null;
  end;

  select count(*) into visible_rows
  from app_private.get_client_sensitive_summary(
    '82000000-0000-4000-8000-000000000001', 'ADMIN_TEST'
  );
  if visible_rows <> 1 then raise exception 'Admin nao recebeu resumo permitido'; end if;
end $$;
reset role;

-- Auditoria permanece append-only ate para o owner do teste.
do $$
declare
  event_id bigint;
begin
  insert into audit.events (
    origin, event_type, entity_type, entity_id, metadata
  ) values ('system', 'synthetic_test', 'test', 'synthetic', '{}')
  returning id into event_id;

  begin
    update audit.events set event_type = 'changed' where id = event_id;
    raise exception 'Evento de auditoria foi alterado';
  exception when raise_exception then
    if sqlerrm <> 'audit.events e append-only' then raise; end if;
  end;

  begin
    delete from audit.events where id = event_id;
    raise exception 'Evento de auditoria foi excluido';
  exception when raise_exception then
    if sqlerrm <> 'audit.events e append-only' then raise; end if;
  end;
end $$;

reset role;
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claim.role', '', true);
select set_config('app.change_origin', '', true);

rollback;

select 'BKL-016 database and RLS checks passed' as result;
