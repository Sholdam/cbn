import { execFileSync } from 'node:child_process'
import { randomBytes, randomUUID } from 'node:crypto'
import { fileURLToPath } from 'node:url'
import { createClient } from '@supabase/supabase-js'

export const EXPECTED_BRANCH = 'codex/bkl-016-retention-legal-hold'
export const CONFIRMATION = 'synthetic-local-explicit-ids'
export const BUCKET = 'cbn-temporary-private'
export const MAX_BATCH = 10
const DB_CONTAINER = 'supabase_db_cbn'
const TABLES = [
  'public.user_profiles', 'public.clients', 'public.technical_operations',
  'public.consultations', 'public.offers', 'public.proposals',
  'public.interactions', 'public.pending_items',
  'app_private.client_sensitive_data', 'app_private.proposal_sensitive_data',
  'app_private.protected_payloads', 'app_private.protected_file_refs',
  'app_private.retention_policies', 'app_private.retention_controls',
  'audit.events'
]

export class RetentionRuntimeError extends Error {
  constructor(category) {
    super(category)
    this.name = 'RetentionRuntimeError'
    this.category = category
  }
}

function fail(category) {
  throw new RetentionRuntimeError(category)
}

export function validateDeleteGate({ confirmation, branch, localUrl, ids, preexistingStack, protectedDiff }) {
  if (confirmation !== CONFIRMATION) fail('human_confirmation_required')
  if (branch !== EXPECTED_BRANCH) fail('branch_rejected')
  if (preexistingStack) fail('preexisting_local_stack_rejected')
  if (protectedDiff) fail('protected_path_modified')
  if (!Array.isArray(ids) || ids.length === 0 || ids.length > MAX_BATCH || new Set(ids).size !== ids.length) {
    fail('explicit_id_batch_rejected')
  }
  if (ids.some((id) => !/^[a-f0-9-]{36}$/.test(id) || !id.startsWith('a'))) fail('synthetic_id_rejected')
  let url
  try { url = new URL(localUrl) } catch { fail('local_url_rejected') }
  if (!['localhost', '127.0.0.1'].includes(url.hostname) || url.port !== '54321') fail('non_local_target_rejected')
  return true
}

function run(command, args, { input, allowFailure = false } = {}) {
  try {
    return execFileSync(command, args, {
      cwd: process.cwd(), input, encoding: 'utf8', windowsHide: true,
      stdio: ['pipe', 'pipe', 'pipe'], maxBuffer: 64 * 1024 * 1024,
      env: { ...process.env, SUPABASE_TELEMETRY_DISABLED: '1' }
    })
  } catch {
    if (allowFailure) return null
    fail(`command_failed_${command.replace(/[^a-z0-9]/gi, '_').toLowerCase()}`)
  }
}

function psql(sql, { allowFailure = false } = {}) {
  return run('docker', [
    'exec', '-i', DB_CONTAINER, 'psql', '-X', '-U', 'supabase_admin', '-d',
    'postgres', '-v', 'ON_ERROR_STOP=1', '--no-psqlrc', '--tuples-only', '--quiet'
  ], { input: sql, allowFailure })
}

function parseStatus() {
  let status
  try { status = JSON.parse(run('supabase', ['status', '--output', 'json'])) } catch { fail('local_status_invalid') }
  const url = status.API_URL ?? status.api_url
  const key = status.SERVICE_ROLE_KEY ?? status.service_role_key
  if (!url || !key) fail('local_status_incomplete')
  return { url, key }
}

function sqlText(value) {
  if (!/^[A-Za-z0-9._:/-]{1,200}$/.test(value)) fail('sql_value_rejected')
  return `'${value}'`
}

function exactObject(entries, objectName) {
  return (entries ?? []).filter((entry) => entry?.name === objectName)
}

async function objectExists(bucketClient, objectName) {
  const result = await bucketClient.list('', { search: objectName, limit: 100 })
  if (result.error) fail('storage_list_failed')
  return exactObject(result.data, objectName).length === 1
}

export async function runRetentionRuntime() {
  const branch = run('git', ['branch', '--show-current']).trim()
  const protectedDiff = [
    run('git', ['diff', '--name-only', '--', 'telegram-gateway', '.env.example']).trim(),
    run('git', ['diff', '--cached', '--name-only', '--', 'telegram-gateway', '.env.example']).trim()
  ].some(Boolean)
  const preexistingStack = Boolean(run('docker', ['ps', '--filter', `name=${DB_CONTAINER}`, '--format', '{{.Names}}']).trim())
  const ids = ['a9000000-0000-4000-8000-000000000001']
  let stackStarted = false
  let bucketClient
  let objectName
  try {
    if (preexistingStack) fail('preexisting_local_stack_rejected')
    run('supabase', ['start', '--ignore-health-check', '--exclude=analytics,vector,realtime,studio,edge-runtime,imgproxy,inbucket'])
    stackStarted = true
    run('supabase', ['db', 'reset'])
    const local = parseStatus()
    validateDeleteGate({
      confirmation: process.env.CBN_RETENTION_DELETE_CONFIRMED,
      branch, localUrl: local.url, ids, preexistingStack, protectedDiff
    })
    const client = createClient(local.url, local.key, {
      auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false }
    })
    bucketClient = client.storage.from(BUCKET)

    psql(`
insert into app_private.retention_policies (
  id, policy_code, data_category, purpose_code, retention_period, policy_status, review_required
) values (
  'a8000000-0000-4000-8000-000000000001', 'SYNTHETIC_RUNTIME_POLICY',
  'SYNTHETIC_CUSTOMER_DATA', 'SYNTHETIC_TEST', interval '1 day', 'ACTIVE', false
);
insert into public.clients (id, display_name, phone_masked, cpf_masked, journey_state)
values ('a8100000-0000-4000-8000-000000000001', '[SYNTHETIC TEST] Runtime Client',
  '+55 ** *****-0101', '***.***.***-01', 'NEW');
insert into app_private.client_sensitive_data (
  client_id, cpf_ciphertext, encryption_key_ref, encryption_version, retention_until
) values ('a8100000-0000-4000-8000-000000000001', decode('53594e544845544943', 'hex'),
  'local-test-only', 'local-v1', now() - interval '2 days');
insert into app_private.retention_controls (
  id, policy_id, entity_type, entity_id, client_id, purpose_code,
  retention_until, deletion_eligible_at, process_version, review_required
) values ('a8200000-0000-4000-8000-000000000001', 'a8000000-0000-4000-8000-000000000001',
  'CLIENT', 'a8100000-0000-4000-8000-000000000001', 'a8100000-0000-4000-8000-000000000001',
  'SYNTHETIC_TEST', now() - interval '2 days', now() - interval '1 day', 'runtime-v1', false);
select app_private.anonymize_clients(
  array['a8200000-0000-4000-8000-000000000001'::uuid], 'runtime-v1'
);
`)
    const dataArgs = ['exec', DB_CONTAINER, 'pg_dump', '-U', 'postgres', '-d', 'postgres', '--data-only', '--column-inserts', '--disable-triggers']
    for (const table of TABLES) dataArgs.push(`--table=${table}`)
    const postAnonymizationBackup = run('docker', dataArgs)
    if (postAnonymizationBackup.includes('[SYNTHETIC TEST] Runtime Client')) fail('post_anonymization_backup_contains_identifier')
    run('supabase', ['db', 'reset'])
    psql(`truncate table ${TABLES.join(', ')} cascade;`)
    psql(postAnonymizationBackup)
    const restored = psql(`
select count(*) from public.clients
where id = 'a8100000-0000-4000-8000-000000000001'
  and display_name = '[ANONYMIZED]' and phone_masked is null and cpf_masked is null
  and anonymized_at is not null
  and not exists (
    select 1 from app_private.client_sensitive_data
    where client_id = 'a8100000-0000-4000-8000-000000000001'
  );`).trim()
    if (restored !== '1') fail('post_anonymization_restore_revived_data')

    do { objectName = randomUUID() } while (/[0-9]{11}/.test(objectName))
    const upload = await bucketClient.upload(objectName, Buffer.concat([
      Buffer.from('BKL016_RETENTION_SYNTHETIC\n', 'utf8'), randomBytes(32)
    ]), { contentType: 'application/octet-stream', upsert: false })
    if (upload.error) fail('storage_upload_failed')
    psql(`
insert into public.technical_operations (
  operation_id, client_id, product, action, session_alias, state
) values ('a8300000-0000-4000-8000-000000000001',
  'a8100000-0000-4000-8000-000000000001', 'FGTS', 'CONSULTAR', 'synthetic-runtime', 'COMPLETED');
insert into app_private.protected_file_refs (
  id, client_id, operation_id, bucket_name, object_key,
  encryption_key_ref, encryption_version, retention_until
) values ('a8400000-0000-4000-8000-000000000001',
  'a8100000-0000-4000-8000-000000000001', 'a8300000-0000-4000-8000-000000000001',
  '${BUCKET}', ${sqlText(objectName)}, 'local-test-only', 'local-v1', now() - interval '2 days');
insert into app_private.retention_controls (
  id, policy_id, entity_type, entity_id, client_id, operation_id, purpose_code,
  retention_until, deletion_eligible_at, status, process_version, review_required
) values ('a9000000-0000-4000-8000-000000000001', 'a8000000-0000-4000-8000-000000000001',
  'PROTECTED_FILE', 'a8400000-0000-4000-8000-000000000001',
  'a8100000-0000-4000-8000-000000000001', 'a8300000-0000-4000-8000-000000000001',
  'SYNTHETIC_TEST', now() - interval '2 days', now() - interval '1 day', 'ELIGIBLE', 'runtime-v1', false);
select app_private.apply_legal_hold('a9000000-0000-4000-8000-000000000001',
  'SYNTHETIC_REVIEW', 'TECHNICAL_RUNTIME', 'runtime-v1');
`)
    const heldEvaluation = psql(`select app_private.evaluate_retention_action(
      'a9000000-0000-4000-8000-000000000001', 'DELETE', 'runtime-v1');`).trim()
    if (heldEvaluation !== 'f') fail('legal_hold_evaluation_incorrect')
    const heldPrepare = psql(`select * from app_private.prepare_retention_deletion(
      array['a9000000-0000-4000-8000-000000000001'::uuid],
      '${CONFIRMATION}', 'runtime-v1');`, { allowFailure: true })
    if (heldPrepare !== null) fail('legal_hold_did_not_block_storage_deletion')
    if (!(await objectExists(bucketClient, objectName))) fail('held_storage_object_missing')
    psql(`
select app_private.request_legal_hold_removal('a9000000-0000-4000-8000-000000000001',
  'TECHNICAL_RUNTIME', 'runtime-v1');
select app_private.remove_legal_hold('a9000000-0000-4000-8000-000000000001',
  'TECHNICAL_REVIEWER', 'runtime-v1');
select * from app_private.prepare_retention_deletion(
  array['a9000000-0000-4000-8000-000000000001'::uuid], '${CONFIRMATION}', 'runtime-v1');
`)
    const falseCompletion = psql(`select app_private.complete_retention_deletion(
      'a9000000-0000-4000-8000-000000000001', false, 'runtime-v1');`, { allowFailure: true })
    if (falseCompletion !== null) fail('storage_failure_marked_complete')
    const removeResult = await bucketClient.remove([objectName])
    if (removeResult.error || await objectExists(bucketClient, objectName)) fail('storage_absence_not_proven')
    psql(`select app_private.complete_retention_deletion(
      'a9000000-0000-4000-8000-000000000001', true, 'runtime-v1');`)
    const finalState = psql(`select count(*) from app_private.retention_controls c
      where c.id = 'a9000000-0000-4000-8000-000000000001' and c.status = 'DELETED'
      and c.deleted_at is not null
      and not exists (select 1 from app_private.protected_file_refs f where f.id = c.entity_id);`).trim()
    if (finalState !== '1') fail('database_deletion_not_completed')
    objectName = null
    return true
  } finally {
    if (bucketClient && objectName) await bucketClient.remove([objectName]).catch(() => undefined)
    if (stackStarted) run('supabase', ['stop', '--no-backup'], { allowFailure: true })
  }
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  runRetentionRuntime()
    .then(() => console.log('BKL-016 retention legal hold runtime passed'))
    .catch((error) => {
      console.error(`BKL-016 retention legal hold runtime failed category=${error?.category ?? 'runtime_failed'}`)
      process.exitCode = 1
    })
}
