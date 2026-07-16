import { execFileSync, spawnSync } from 'node:child_process'
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { resolve } from 'node:path'

export const EXPECTED_BRANCH = 'codex/bkl-016-backend-identity'
export const CONFIRMATION = 'synthetic-local-role-test'
export const LOCAL_URL = 'http://127.0.0.1:54321'
const DB_CONTAINER = 'supabase_db_cbn'
const REPO_ROOT = fileURLToPath(new URL('../../', import.meta.url))
let runtimeStage = 'initial'
const SQL_SUITES = [
  'supabase/tests/bkl016_secure_storage_test.sql',
  'supabase/tests/bkl016_envelope_constraints_test.sql',
  'supabase/tests/bkl016_retention_legal_hold_test.sql',
  'supabase/tests/bkl016_retention_repairs_test.sql',
  'supabase/tests/bkl016_backend_identity_test.sql'
]

export class BackendIdentityRuntimeError extends Error {
  constructor(category) {
    super(category)
    this.name = 'BackendIdentityRuntimeError'
    this.category = category
  }
}

function fail(category) {
  throw new BackendIdentityRuntimeError(category)
}

export function validateBackendIdentityGate({
  confirmation, branch, localUrl, preexistingStack, protectedDiff, remoteEnvironment
}) {
  if (confirmation !== CONFIRMATION) fail('human_confirmation_required')
  if (branch !== EXPECTED_BRANCH) fail('branch_rejected')
  if (preexistingStack) fail('preexisting_local_stack_rejected')
  if (protectedDiff) fail('protected_path_modified')
  if (remoteEnvironment) fail('remote_environment_rejected')
  let url
  try { url = new URL(localUrl) } catch { fail('local_url_rejected') }
  if (!['localhost', '127.0.0.1'].includes(url.hostname) || url.port !== '54321') {
    fail('non_local_target_rejected')
  }
  return true
}

function run(command, args, { input, allowFailure = false } = {}) {
  const result = spawnSync(command, args, {
    cwd: REPO_ROOT, input, encoding: 'utf8', windowsHide: true,
    maxBuffer: 64 * 1024 * 1024,
    env: { ...process.env, SUPABASE_TELEMETRY_DISABLED: '1' }
  })
  if (result.status !== 0 && !allowFailure) {
    const safeClass = [
      ['permission', /permission denied|must be owner|superuser/i],
      ['constraint', /constraint|violates|not-null/i],
      ['connection', /connection.*(?:failed|closed|refused)/i],
      ['syntax', /syntax error/i]
    ].find(([, pattern]) => pattern.test(String(result.stderr)))?.[0] ?? 'unclassified'
    fail(`command_failed_${command.replace(/[^a-z0-9]/gi, '_').toLowerCase()}_${runtimeStage}_${safeClass}`)
  }
  return result
}

function output(command, args) {
  return execFileSync(command, args, {
    cwd: REPO_ROOT, encoding: 'utf8', windowsHide: true,
    env: { ...process.env, SUPABASE_TELEMETRY_DISABLED: '1' }
  })
}

function psqlText(sql, { allowFailure = false } = {}) {
  return run('docker', [
    'exec', '-i', DB_CONTAINER, 'psql', '-X', '-U', 'supabase_admin', '-d',
    'postgres', '-v', 'ON_ERROR_STOP=1', '--no-psqlrc'
  ], { input: sql, allowFailure })
}

function psqlFile(path, options) {
  return psqlText(readFileSync(resolve(REPO_ROOT, path), 'utf8'), options)
}

function hasRemoteEnvironment() {
  return Object.entries(process.env).some(([name, value]) =>
    /(?:PROJECT_REF|DATABASE_URL|SUPABASE_DB_URL|SUPABASE_ACCESS_TOKEN)/i.test(name)
      && typeof value === 'string' && value.trim() !== ''
  ) || Object.values(process.env).some((value) =>
    typeof value === 'string' && /(?:\.supabase\.co|pooler\.supabase\.com)/i.test(value)
  )
}

export async function runBackendIdentityRuntime() {
  const branch = output('git', ['branch', '--show-current']).trim()
  const protectedDiff = [
    output('git', ['diff', '--name-only', '--', 'telegram-gateway', '.env.example']).trim(),
    output('git', ['diff', '--cached', '--name-only', '--', 'telegram-gateway', '.env.example']).trim()
  ].some(Boolean)
  const preexistingStack = Boolean(output(
    'docker', ['ps', '--filter', `name=${DB_CONTAINER}`, '--format', '{{.Names}}']
  ).trim())
  let stackStarted = false

  validateBackendIdentityGate({
    confirmation: process.env.CBN_BACKEND_IDENTITY_CONFIRMED,
    branch,
    localUrl: LOCAL_URL,
    preexistingStack,
    protectedDiff,
    remoteEnvironment: hasRemoteEnvironment()
  })

  try {
    runtimeStage = 'stack_start'
    run('supabase', [
      'start', '--ignore-health-check',
      '--exclude=analytics,vector,realtime,studio,edge-runtime,imgproxy,inbucket'
    ])
    stackStarted = true
    runtimeStage = 'database_reset'
    run('supabase', ['db', 'reset'])

    for (const suite of SQL_SUITES) {
      runtimeStage = `suite_${suite.split('/').at(-1).replace(/[^a-z0-9]/gi, '_').toLowerCase()}`
      psqlFile(suite)
    }

    // Estado novo torna o rollback destrutivo proibido.
    runtimeStage = 'rollback_guard_fixture'
    psqlText(`
insert into public.clients (id, display_name, journey_state)
values ('d1000000-0000-4000-8000-000000000001', '[SYNTHETIC TEST] Rollback Guard', 'NEW');
set role cbn_gateway_backend;
select app_private.gateway_create_operation(
  'd2000000-0000-4000-8000-000000000001',
  'd1000000-0000-4000-8000-000000000001', 'FGTS', 'CONSULTAR',
  'synthetic-rollback', 'identity-v1'
);
reset role;
`)
    runtimeStage = 'rollback_guard'
    const refused = psqlFile(
      'supabase/rollback/20260721_001_bkl016_backend_identity_audit_down.sql',
      { allowFailure: true }
    )
    if (refused.status === 0 || !/existe auditoria indispensavel/i.test(String(refused.stderr))) {
      fail('rollback_fail_closed_not_proven')
    }

    // Base limpa: rollback funciona e nao amplia PUBLIC/anon/authenticated.
    runtimeStage = 'clean_reset'
    run('supabase', ['db', 'reset'])
    runtimeStage = 'clean_audit_rollback'
    psqlFile('supabase/rollback/20260721_001_bkl016_backend_identity_audit_down.sql')
    runtimeStage = 'clean_identity_rollback'
    psqlFile('supabase/rollback/20260720_001_bkl016_backend_identity_down.sql')
    const cleanCheck = psqlText(`
do $$
begin
  if exists (select 1 from pg_roles where rolname like 'cbn_%') then
    raise exception 'rollback deixou papel tecnico';
  end if;
  if to_regprocedure('app_private.gateway_create_operation(uuid,uuid,public.credit_product,text,text,text)') is not null
     or to_regprocedure('app_private.retention_evaluate(uuid,text,text)') is not null then
    raise exception 'rollback deixou wrapper tecnico';
  end if;
  if has_table_privilege('anon', 'app_private.client_sensitive_data', 'SELECT')
     or has_table_privilege('authenticated', 'app_private.client_sensitive_data', 'SELECT') then
    raise exception 'rollback ampliou papel web';
  end if;
end
$$;
select 'BKL-016 backend identity clean rollback passed';
`)
    if (!/clean rollback passed/.test(cleanCheck.stdout)) fail('clean_rollback_not_proven')

    // Reaplicacao integral e repetibilidade.
    runtimeStage = 'reapply_reset'
    run('supabase', ['db', 'reset'])
    runtimeStage = 'reapply_suite'
    const reapplied = psqlFile('supabase/tests/bkl016_backend_identity_test.sql')
    if (!/backend identity and privilege checks passed/.test(reapplied.stdout)) {
      fail('reapplication_not_proven')
    }
    return true
  } finally {
    if (stackStarted) run('supabase', ['stop', '--no-backup'], { allowFailure: true })
  }
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  runBackendIdentityRuntime()
    .then(() => console.log('BKL-016 backend identity runtime passed'))
    .catch((error) => {
      console.error(`BKL-016 backend identity runtime failed category=${error?.category ?? 'runtime_failed'}`)
      process.exitCode = 1
    })
}
