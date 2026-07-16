import { execFileSync } from 'node:child_process'
import { createHash, randomBytes, randomUUID } from 'node:crypto'
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { performance } from 'node:perf_hooks'
import { createClient } from '@supabase/supabase-js'
import {
  SYNTHETIC_CONTEXT, SYNTHETIC_PLAINTEXT, assertBackupArtifactSafe,
  cloneEnvelope, createEphemeralRecoveryFixture, deserializeEnvelope,
  serializeEnvelope, sha256
} from './backup-recovery.mjs'

const EXPECTED_BRANCH = 'codex/bkl-016-backup-restore'
const LOCAL_DB_CONTAINER = 'supabase_db_cbn'
const BUCKET = 'cbn-temporary-private'
const PAYLOAD_ID = '50000000-0000-4000-8000-000000000001'
const TABLES = [
  'public.user_profiles', 'public.clients', 'public.technical_operations',
  'public.consultations', 'public.offers', 'public.proposals',
  'public.interactions', 'public.pending_items',
  'app_private.client_sensitive_data', 'app_private.proposal_sensitive_data',
  'app_private.protected_payloads', 'app_private.protected_file_refs',
  'audit.events'
]

function fail(category) {
  const error = new Error(category)
  error.name = 'BackupRestoreRuntimeError'
  error.category = category
  throw error
}

function run(command, args, { input, allowFailure = false } = {}) {
  try {
    return execFileSync(command, args, {
      cwd: process.cwd(), input, encoding: 'utf8', windowsHide: true,
      stdio: ['pipe', 'pipe', 'pipe'], maxBuffer: 64 * 1024 * 1024,
      env: { ...process.env, SUPABASE_TELEMETRY_DISABLED: '1' }
    })
  } catch (error) {
    if (allowFailure) return null
    const stderr = String(error?.stderr ?? '')
    const safeClass = [
      ['foreign_key', /foreign key|violates foreign/i],
      ['duplicate', /duplicate key|unique constraint/i],
      ['permission', /permission denied|must be owner|superuser/i],
      ['syntax', /syntax error/i],
      ['missing_relation', /relation .* does not exist/i],
      ['constraint', /check constraint|not-null constraint|null value/i],
      ['connection', /connection.*(?:failed|closed|refused)/i]
    ].find(([, pattern]) => pattern.test(stderr))?.[0] ?? 'unclassified'
    fail(`command_failed_${command.replace(/[^a-z0-9]/gi, '_').toLowerCase()}_${safeClass}`)
  }
}

function assertLocalOnly() {
  if (process.env.CBN_BACKUP_RESTORE_CONFIRMED !== 'synthetic-local-only') {
    fail('synthetic_local_confirmation_missing')
  }
  if (run('git', ['branch', '--show-current']).trim() !== EXPECTED_BRANCH) {
    fail('branch_rejected')
  }
  const protectedDiff = run('git', [
    'diff', '--name-only', '--', 'telegram-gateway', '.env.example'
  ]).trim()
  if (protectedDiff) fail('protected_path_modified')
  const stagedProtectedDiff = run('git', [
    'diff', '--cached', '--name-only', '--', 'telegram-gateway', '.env.example'
  ]).trim()
  if (stagedProtectedDiff) fail('protected_path_modified')
  const existingDb = run('docker', ['ps', '--filter', `name=${LOCAL_DB_CONTAINER}`, '--format', '{{.Names}}'])
  if (existingDb.trim()) fail('preexisting_local_stack_rejected')
}

function psql(sql, { allowFailure = false } = {}) {
  return run('docker', [
    'exec', '-i', LOCAL_DB_CONTAINER, 'psql', '-X', '-U', 'supabase_admin', '-d',
    'postgres', '-v', 'ON_ERROR_STOP=1', '--no-psqlrc', '--tuples-only', '--quiet'
  ], { input: sql, allowFailure })
}

function pgDump(args) {
  return run('docker', [
    'exec', LOCAL_DB_CONTAINER, 'pg_dump', '-U', 'postgres', '-d', 'postgres',
    '--no-owner', '--no-privileges', ...args
  ])
}

function sqlBytea(buffer) {
  return `decode('${buffer.toString('hex')}', 'hex')`
}

function sqlLiteral(value) {
  if (!/^[A-Za-z0-9._:/-]{1,255}$/.test(value)) fail('sql_literal_rejected')
  return `'${value}'`
}

function statusValue(status, ...keys) {
  for (const key of keys) {
    if (typeof status?.[key] === 'string' && status[key]) return status[key]
  }
  return null
}

function parseLocalStatus() {
  const raw = run('supabase', ['status', '--output', 'json'])
  let status
  try {
    status = JSON.parse(raw)
  } catch {
    fail('local_status_invalid')
  }
  const url = statusValue(status, 'API_URL', 'api_url')
  const key = statusValue(status, 'SERVICE_ROLE_KEY', 'service_role_key')
  if (!url || !key) fail('local_status_incomplete')
  const parsed = new URL(url)
  if (!['127.0.0.1', 'localhost'].includes(parsed.hostname) || parsed.port !== '54321') {
    fail('non_local_supabase_rejected')
  }
  return { url, key }
}

function envelopeUpdateSql(envelope) {
  return `
update app_private.protected_payloads
set ciphertext = ${sqlBytea(envelope.ciphertext)},
    encryption_key_ref = ${sqlLiteral(envelope.keyReference.alias)},
    encryption_version = ${sqlLiteral(envelope.keyReference.version)},
    envelope_algorithm = 'AES-256-GCM',
    envelope_version = 1,
    wrapped_dek = ${sqlBytea(envelope.wrappedDek)},
    content_nonce = ${sqlBytea(envelope.nonce)},
    authentication_tag = ${sqlBytea(envelope.tag)},
    aad_version = 1,
    aad_sha256 = '${envelope.aadSha256}'
where id = '${PAYLOAD_ID}'::uuid;
do $$ begin
  if not exists (
    select 1 from app_private.protected_payloads
    where id = '${PAYLOAD_ID}'::uuid and envelope_version = 1
  ) then raise exception 'synthetic envelope fixture missing'; end if;
end $$;
`
}

function restoredEnvelopeFromDatabase() {
  const result = psql(`
select json_build_object(
  'envelopeVersion', envelope_version,
  'algorithm', envelope_algorithm,
  'ciphertext', replace(encode(ciphertext, 'base64'), E'\\n', ''),
  'wrappedDek', replace(encode(wrapped_dek, 'base64'), E'\\n', ''),
  'nonce', replace(encode(content_nonce, 'base64'), E'\\n', ''),
  'tag', replace(encode(authentication_tag, 'base64'), E'\\n', ''),
  'keyReference', json_build_object(
    'provider', 'local-test-only',
    'alias', encryption_key_ref,
    'version', encryption_version
  ),
  'aadVersion', aad_version,
  'aadSha256', aad_sha256
)::text
from app_private.protected_payloads
where id = '${PAYLOAD_ID}'::uuid;
`).trim()
  if (!result) fail('restored_envelope_missing')
  return deserializeEnvelope(result)
}

function assertSchemaBackup(schemaSql) {
  const required = [
    'CREATE TABLE public.clients',
    'CREATE TABLE public.proposals',
    'CREATE TABLE app_private.protected_payloads',
    'CREATE TABLE app_private.protected_file_refs',
    'CREATE TABLE audit.events',
    'wrapped_dek', 'authentication_tag', 'aad_sha256'
  ]
  if (required.some((marker) => !schemaSql.includes(marker))) fail('schema_backup_incomplete')
}

async function removeStorageObject(client, objectName) {
  if (!client || !objectName) return
  await client.storage.from(BUCKET).remove([objectName])
}

async function main() {
  assertLocalOnly()
  const repositoryRoot = run('git', ['rev-parse', '--show-toplevel']).trim()
  const fixture = createEphemeralRecoveryFixture()
  let client
  let objectName
  let temporaryDirectory
  let stackStarted = false
  let restoredObject = false
  const startedAt = performance.now()
  try {
    run('supabase', [
      'start', '--ignore-health-check',
      '--exclude=analytics,vector,realtime,studio,edge-runtime,imgproxy,inbucket'
    ])
    stackStarted = true
    run('supabase', ['db', 'reset'])
    const local = parseLocalStatus()
    client = createClient(local.url, local.key, {
      auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false }
    })

    await fixture.kms.rotateTestKek()
    const envelope = await fixture.service.encrypt(SYNTHETIC_PLAINTEXT, SYNTHETIC_CONTEXT)
    psql(envelopeUpdateSql(envelope))

    objectName = randomUUID()
    const storageContent = Buffer.concat([
      Buffer.from('BKL016_STORAGE_BACKUP_SYNTHETIC\n', 'utf8'), randomBytes(32)
    ])
    const upload = await client.storage.from(BUCKET).upload(objectName, storageContent, {
      contentType: 'application/octet-stream', upsert: false
    })
    if (upload.error) fail('local_storage_upload_failed')

    temporaryDirectory = await mkdtemp(join(tmpdir(), 'cbn-bkl016-backup-restore-'))
    const schemaPath = join(temporaryDirectory, 'schema.sql')
    const dataPath = join(temporaryDirectory, 'data.sql')
    const objectPath = join(temporaryDirectory, 'storage-object.bin')
    const manifestPath = join(temporaryDirectory, 'manifest.json')

    const schemaSql = pgDump(['--schema-only', '--schema=public', '--schema=app_private', '--schema=audit'])
    assertSchemaBackup(schemaSql)
    const dataArgs = ['--data-only', '--column-inserts', '--disable-triggers']
    for (const table of TABLES) dataArgs.push(`--table=${table}`)
    const dataSql = pgDump(dataArgs)
    const downloaded = await client.storage.from(BUCKET).download(objectName)
    if (downloaded.error) fail('local_storage_backup_download_failed')
    const backedUpObject = Buffer.from(await downloaded.data.arrayBuffer())
    const manifest = {
      marker: 'BKL016_SYNTHETIC_LOCAL_BACKUP',
      database: { schemaSha256: sha256(schemaSql), dataSha256: sha256(dataSql) },
      storage: { bucket: BUCKET, objectName, sha256: sha256(backedUpObject), bytes: backedUpObject.length },
      keyDependency: { provider: 'local-test-only', alias: envelope.keyReference.alias, version: envelope.keyReference.version },
      createdAt: new Date().toISOString()
    }
    await Promise.all([
      writeFile(schemaPath, schemaSql, { encoding: 'utf8', flag: 'wx' }),
      writeFile(dataPath, dataSql, { encoding: 'utf8', flag: 'wx' }),
      writeFile(objectPath, backedUpObject, { flag: 'wx' }),
      writeFile(manifestPath, `${JSON.stringify(manifest)}\n`, { encoding: 'utf8', flag: 'wx' })
    ])
    for (const path of [schemaPath, dataPath, objectPath, manifestPath]) {
      assertBackupArtifactSafe(await readFile(path))
    }

    await removeStorageObject(client, objectName)
    run('supabase', ['db', 'reset'])
    psql(`truncate table ${TABLES.join(', ')} cascade;`)
    psql(await readFile(dataPath, 'utf8'))

    const restoreUpload = await client.storage.from(BUCKET).upload(
      objectName, await readFile(objectPath), { contentType: 'application/octet-stream', upsert: false }
    )
    if (restoreUpload.error) fail('local_storage_restore_failed')
    restoredObject = true
    const restoredDownload = await client.storage.from(BUCKET).download(objectName)
    if (restoredDownload.error) fail('local_storage_restore_verify_failed')
    const restoredBytes = Buffer.from(await restoredDownload.data.arrayBuffer())
    if (sha256(restoredBytes) !== manifest.storage.sha256) fail('local_storage_hash_mismatch')

    const restoredEnvelope = restoredEnvelopeFromDatabase()
    const recovered = await fixture.service.decrypt(restoredEnvelope, SYNTHETIC_CONTEXT)
    if (sha256(recovered) !== sha256(SYNTHETIC_PLAINTEXT)) fail('envelope_recovery_hash_mismatch')
    recovered.fill(0)

    const missingFixture = createEphemeralRecoveryFixture()
    try {
      let missingFailedClosed = false
      try {
        await missingFixture.service.decrypt(restoredEnvelope, SYNTHETIC_CONTEXT)
      } catch (error) {
        missingFailedClosed = error?.category === 'key_version_unavailable'
      }
      if (!missingFailedClosed) fail('missing_kek_version_not_closed')
    } finally {
      missingFixture.kms.destroy()
    }

    const tampered = Buffer.from(restoredEnvelope.ciphertext)
    tampered[0] ^= 0xff
    let tamperFailedClosed = false
    try {
      await fixture.service.decrypt(cloneEnvelope(restoredEnvelope, { ciphertext: tampered }), SYNTHETIC_CONTEXT)
    } catch (error) {
      tamperFailedClosed = error?.category === 'envelope_authentication_failed'
    }
    if (!tamperFailedClosed) fail('tamper_not_closed')

    const databaseTests = psql(await readFile(
      join(repositoryRoot, 'supabase', 'tests', 'bkl016_secure_storage_test.sql'), 'utf8'
    ))
    if (!databaseTests.includes('BKL-016 database and RLS checks passed')) {
      fail('database_rls_suite_marker_missing')
    }
    const envelopeTests = psql(await readFile(
      join(repositoryRoot, 'supabase', 'tests', 'bkl016_envelope_constraints_test.sql'), 'utf8'
    ))
    if (!envelopeTests.includes('BKL-016 envelope database constraints passed')) {
      fail('envelope_constraint_suite_marker_missing')
    }

    const rollbackSql = await readFile(
      join(repositoryRoot, 'supabase', 'rollback', '20260717_001_bkl016_envelope_metadata_down.sql'),
      'utf8'
    )
    if (psql(rollbackSql, { allowFailure: true }) !== null) fail('unsafe_rollback_accepted')
    if (!restoredEnvelopeFromDatabase()) fail('rollback_did_not_preserve_envelope')

    const recoverySeconds = Number(((performance.now() - startedAt) / 1000).toFixed(2))
    console.log('BKL-016 synthetic schema backup passed')
    console.log('BKL-016 synthetic data restore passed')
    console.log('BKL-016 synthetic Storage restore passed')
    console.log('BKL-016 envelope recovery passed')
    console.log('BKL-016 missing KEK version failed closed')
    console.log('BKL-016 tamper detection passed')
    console.log('BKL-016 database and RLS checks passed')
    console.log('BKL-016 envelope database constraints passed')
    console.log('BKL-016 safe rollback refusal passed')
    console.log(`BKL-016 preliminary local RTO seconds: ${recoverySeconds}`)
    console.log('BKL-016 preliminary RPO: exact snapshot; operational RPO equals future backup cadence')
    console.log('BKL-016 backup and restore runtime passed')
  } finally {
    if (restoredObject || objectName) await removeStorageObject(client, objectName)
    fixture.kms.destroy()
    if (temporaryDirectory) await rm(temporaryDirectory, { recursive: true, force: true })
    if (stackStarted) run('supabase', ['stop', '--no-backup'], { allowFailure: true })
  }
}

await main()
