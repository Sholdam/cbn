-- BKL-016 — dados exclusivamente sinteticos para desenvolvimento local.
-- NAO aplicar este seed em ambiente compartilhado ou de producao.

select set_config('app.change_origin', 'system', true);

insert into public.clients (
  id, display_name, phone_masked, cpf_masked, lead_source,
  journey_state, consultation_consent_at, consultation_consent_source,
  retention_until
) values (
  '10000000-0000-4000-8000-000000000001',
  '[SYNTHETIC TEST] Cliente Exemplo',
  '+55 ** *****-0000',
  '***.***.***-00',
  'synthetic_local_seed',
  'CONSENT_RECORDED',
  '2026-07-15T12:00:00Z',
  'synthetic_test_fixture',
  '2026-08-14T12:00:00Z'
) on conflict (id) do nothing;

insert into public.technical_operations (
  operation_id, correlation_id, client_id, product, action,
  session_alias, state, attempt_count, gateway_version,
  started_at, finished_at, retention_until
) values (
  '20000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000002',
  '10000000-0000-4000-8000-000000000001',
  'FGTS',
  'CONSULTAR',
  'synthetic-fgts-session-alias',
  'COMPLETED',
  1,
  'synthetic-test-version',
  '2026-07-15T12:00:00Z',
  '2026-07-15T12:00:01Z',
  '2026-08-14T12:00:00Z'
) on conflict (operation_id) do nothing;

insert into public.consultations (
  id, client_id, product, operation_id, status_raw,
  status_normalized, response_code, session_alias,
  requested_at, completed_at, retention_until
) values (
  '30000000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000001',
  'FGTS',
  '20000000-0000-4000-8000-000000000001',
  'SYNTHETIC_SUCCESS',
  'COMPLETED',
  'SYNTHETIC_OK',
  'synthetic-fgts-session-alias',
  '2026-07-15T12:00:00Z',
  '2026-07-15T12:00:01Z',
  '2026-08-14T12:00:00Z'
) on conflict (id) do nothing;

insert into public.offers (
  id, consultation_id, client_id, product, operation_id,
  lender_code, lender_name, plan_code, term_count,
  installment_amount, released_amount, snapshot_hash, valid_until
) values (
  '40000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000001',
  'FGTS',
  '20000000-0000-4000-8000-000000000001',
  'SYNTHETIC_BANK',
  '[SYNTHETIC TEST] Banco Exemplo',
  'SYNTHETIC_PLAN',
  12,
  10.00,
  100.00,
  '0000000000000000000000000000000000000000000000000000000000000000',
  '2026-07-16T12:00:00Z'
) on conflict (id) do nothing;

-- O seed nao inclui CPF/RG/endereco/conta completos, ciphertext ficticio,
-- usuarios Auth, propostas, links, sessoes Telegram, tokens ou payload bruto.
