import { createHash, randomBytes, randomUUID } from 'node:crypto'
import { execFileSync, spawnSync } from 'node:child_process'
import { readdir, readFile, stat } from 'node:fs/promises'
import { dirname, join, relative, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { createClient } from '@supabase/supabase-js'

export const STORAGE_RUNTIME_BRANCH = 'codex/bkl-016-storage-runtime'
export const STORAGE_RUNTIME_BUCKET = 'cbn-temporary-private'
export const STORAGE_RUNTIME_MARKER = 'BKL016_STORAGE_SYNTHETIC_ONLY'
export const DEFAULT_SIGNED_URL_TTL_SECONDS = 30
export const DEFAULT_EXPIRY_MARGIN_SECONDS = 5
export const MAX_EXPIRY_TOLERANCE_SECONDS = 15

const OBJECT_NAME_PATTERN = /^[a-f0-9]{8}-[a-f0-9]{4}-[1-5][a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/
const PROJECT_REF_PATTERN = /^[a-z0-9]{20}$/
const SAFE_HASH_PATTERN = /^[a-f0-9]{64}$/
const FINAL_MARKERS = new Set([
  'BKL-016 Storage backend preflight passed',
  'BKL-016 Storage upload passed',
  'BKL-016 anonymous access denied',
  'BKL-016 signed URL pre-expiry download passed',
  'BKL-016 signed URL expiration passed',
  'BKL-016 Storage local leak scan passed',
  'BKL-016 Storage cleanup passed'
])
const SAFE_DETAIL_KEYS = new Set([
  'bucket', 'bytes', 'sha256', 'nominalTtlSeconds',
  'observedExpirationSeconds', 'statusClass'
])
const TEXT_EXTENSIONS = new Set([
  '.md', '.txt', '.ps1', '.mjs', '.js', '.json', '.sql', '.toml',
  '.yaml', '.yml', '.example', '.gitignore'
])

export class StorageRuntimeError extends Error {
  constructor(category) {
    super(category)
    this.name = 'StorageRuntimeError'
    this.category = category
  }
}

function fail(category) {
  throw new StorageRuntimeError(category)
}

function parseInteger(value, fallback, minimum, maximum, category) {
  const parsed = value === undefined || value === '' ? fallback : Number(value)
  if (!Number.isInteger(parsed) || parsed < minimum || parsed > maximum) fail(category)
  return parsed
}

export function assertSafeObjectName(objectName) {
  if (typeof objectName !== 'string' || !OBJECT_NAME_PATTERN.test(objectName) || /[0-9]{11}/.test(objectName)) {
    fail('object_name_rejected')
  }
  return objectName
}

export function assertNoExistingObject(entries, objectName) {
  if (!Array.isArray(entries)) fail('object_listing_invalid')
  if (entries.some((entry) => entry?.name === objectName)) fail('overwrite_rejected')
}

export function validateRuntimeConfiguration(input) {
  const {
    environment, runtimeConfirmed, bucket, projectUrl, projectRef,
    backendKey, branch, gitClean, signedUrlTtlSeconds,
    expiryMarginSeconds
  } = input

  if (environment !== 'development') fail('environment_rejected')
  if (runtimeConfirmed !== 'true') fail('synthetic_confirmation_missing')
  if (bucket !== STORAGE_RUNTIME_BUCKET) fail('bucket_rejected')
  if (branch !== STORAGE_RUNTIME_BRANCH) fail('branch_rejected')
  if (gitClean !== true) fail('dirty_tree_rejected')
  if (typeof projectRef !== 'string' || !PROJECT_REF_PATTERN.test(projectRef)) fail('project_ref_rejected')
  if (typeof backendKey !== 'string' || backendKey.length < 20 || /\s/.test(backendKey)) fail('backend_credential_missing')

  let url
  try {
    url = new URL(projectUrl)
  } catch {
    fail('project_url_rejected')
  }
  if (url.protocol !== 'https:' || url.username || url.password || url.port ||
      url.pathname !== '/' || url.search || url.hash ||
      url.hostname !== `${projectRef}.supabase.co`) {
    fail('project_url_target_mismatch')
  }

  const ttl = parseInteger(
    signedUrlTtlSeconds,
    DEFAULT_SIGNED_URL_TTL_SECONDS,
    30,
    60,
    'signed_url_ttl_rejected'
  )
  const margin = parseInteger(
    expiryMarginSeconds,
    DEFAULT_EXPIRY_MARGIN_SECONDS,
    3,
    MAX_EXPIRY_TOLERANCE_SECONDS,
    'expiry_margin_rejected'
  )

  return { projectUrl: url.toString(), ttl, margin }
}

function assertSafeDetails(details) {
  if (details === undefined) return
  if (!details || typeof details !== 'object' || Array.isArray(details)) fail('unsafe_output_rejected')
  for (const [key, value] of Object.entries(details)) {
    if (!SAFE_DETAIL_KEYS.has(key)) fail('unsafe_output_rejected')
    if (key === 'bucket' && value !== STORAGE_RUNTIME_BUCKET) fail('unsafe_output_rejected')
    if (key === 'sha256' && !SAFE_HASH_PATTERN.test(value)) fail('unsafe_output_rejected')
    if (key === 'statusClass' && !/^[1-5]xx$/.test(value)) fail('unsafe_output_rejected')
    if (!['bucket', 'sha256', 'statusClass'].includes(key) && (!Number.isFinite(value) || value < 0)) {
      fail('unsafe_output_rejected')
    }
  }
}

export function createSafeReporter({ sensitiveValues = [], writeLine = console.log } = {}) {
  const forbidden = sensitiveValues.filter((value) => typeof value === 'string' && value.length > 0)
  const emittedLines = []
  const assertSafeLine = (line) => {
    if (/https?:\/\//i.test(line) || /authorization\s*:/i.test(line) || /[?&](?:token|signature)=/i.test(line) ||
        /\beyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{16,}\b/.test(line) ||
        forbidden.some((value) => line.includes(value))) {
      fail('unsafe_output_rejected')
    }
  }
  return {
    emittedLines,
    emit(marker, details) {
      if (!FINAL_MARKERS.has(marker)) fail('unsafe_output_rejected')
      assertSafeDetails(details)
      const suffix = details && Object.keys(details).length > 0 ? ` ${JSON.stringify(details)}` : ''
      const line = `${marker}${suffix}`
      assertSafeLine(line)
      emittedLines.push(line)
      writeLine(line)
    },
    emitFailure(category) {
      if (!/^[a-z0-9_]{3,80}$/.test(category)) category = 'runtime_failed'
      const line = `BKL-016 Storage runtime failed category=${category}`
      assertSafeLine(line)
      emittedLines.push(line)
      writeLine(line)
    }
  }
}

function sha256(buffer) {
  return createHash('sha256').update(buffer).digest('hex')
}

function statusClass(status) {
  return `${Math.floor(status / 100)}xx`
}

function sleep(milliseconds) {
  return new Promise((resolvePromise) => setTimeout(resolvePromise, milliseconds))
}

async function listExactObject(bucketClient, objectName) {
  const { data, error } = await bucketClient.list('', {
    limit: 100,
    offset: 0,
    search: objectName,
    sortBy: { column: 'name', order: 'asc' }
  })
  if (error) fail('storage_list_failed')
  return (data ?? []).filter((entry) => entry?.name === objectName)
}

async function scanRelevantFiles(root, exactForbiddenValues) {
  const findings = []
  async function walk(directory) {
    for (const entry of await readdir(directory, { withFileTypes: true })) {
      if (entry.name === '.git' || entry.name === 'node_modules') continue
      const fullPath = join(directory, entry.name)
      if (entry.isDirectory()) {
        await walk(fullPath)
        continue
      }
      if (!entry.isFile()) continue
      const extension = entry.name.startsWith('.') ? entry.name : entry.name.slice(entry.name.lastIndexOf('.'))
      if (!TEXT_EXTENSIONS.has(extension)) continue
      const fileStats = await stat(fullPath)
      if (fileStats.size > 2_000_000) continue
      const content = await readFile(fullPath, 'utf8')
      if (exactForbiddenValues.some((value) => value && content.includes(value))) {
        findings.push(relative(root, fullPath).replaceAll('\\', '/'))
      }
    }
  }
  await walk(root)
  if (findings.length > 0) fail('local_sensitive_value_persisted')
}

function scanGitHistory(root, exactForbiddenValues) {
  const commits = execFileSync('git', ['rev-list', '--all'], { cwd: root, encoding: 'utf8' })
    .split(/\r?\n/)
    .filter(Boolean)
  for (const commit of commits) {
    for (const value of exactForbiddenValues) {
      if (!value) continue
      const result = spawnSync(
        'git',
        ['grep', '-q', '-I', '-F', '-f', '-', commit, '--'],
        { cwd: root, input: `${value}\n`, encoding: 'utf8', stdio: ['pipe', 'ignore', 'ignore'] }
      )
      if (result.status === 0) fail('git_history_sensitive_value_persisted')
      if (result.status !== 1) fail('git_history_scan_failed')
    }
  }
}

function readGitContext(root) {
  const branch = execFileSync('git', ['branch', '--show-current'], { cwd: root, encoding: 'utf8' }).trim()
  const statusOutput = execFileSync(
    'git', ['status', '--porcelain', '--untracked-files=all'], { cwd: root, encoding: 'utf8' }
  ).trim()
  return { branch, gitClean: statusOutput.length === 0 }
}

async function readProjectRef(root) {
  const markerPath = join(root, 'supabase', '.temp', 'project-ref')
  try {
    return (await readFile(markerPath, 'utf8')).trim()
  } catch {
    fail('linked_project_marker_missing')
  }
}

export async function runStorageRuntime({ env = process.env, root, fetchImpl = globalThis.fetch } = {}) {
  const repoRoot = root ?? resolve(dirname(fileURLToPath(import.meta.url)), '..')
  const projectRef = await readProjectRef(repoRoot)
  const gitContext = readGitContext(repoRoot)
  let backendKey = env.CBN_SUPABASE_BACKEND_KEY
  let signedUrl = ''
  let publicUrl = ''
  let syntheticContent
  let objectName = ''
  let uploaded = false
  let cleanupConfirmed = false

  const configuration = validateRuntimeConfiguration({
    environment: env.CBN_ENVIRONMENT,
    runtimeConfirmed: env.CBN_STORAGE_RUNTIME_CONFIRMED,
    bucket: env.CBN_STORAGE_BUCKET ?? STORAGE_RUNTIME_BUCKET,
    projectUrl: env.CBN_SUPABASE_URL,
    projectRef,
    backendKey,
    branch: gitContext.branch,
    gitClean: gitContext.gitClean,
    signedUrlTtlSeconds: env.CBN_STORAGE_SIGNED_URL_TTL_SECONDS,
    expiryMarginSeconds: env.CBN_STORAGE_EXPIRY_MARGIN_SECONDS
  })

  const reporter = createSafeReporter({ sensitiveValues: [projectRef, backendKey] })
  const client = createClient(configuration.projectUrl, backendKey, {
    auth: { autoRefreshToken: false, persistSession: false, detectSessionInUrl: false },
    global: { fetch: fetchImpl }
  })
  const bucketClient = client.storage.from(STORAGE_RUNTIME_BUCKET)

  try {
    const { data: bucketMetadata, error: bucketError } = await client.storage.getBucket(STORAGE_RUNTIME_BUCKET)
    if (bucketError || !bucketMetadata || bucketMetadata.id !== STORAGE_RUNTIME_BUCKET || bucketMetadata.public !== false) {
      fail('private_bucket_preflight_failed')
    }
    reporter.emit('BKL-016 Storage backend preflight passed', { bucket: STORAGE_RUNTIME_BUCKET })

    objectName = assertSafeObjectName(randomUUID())
    syntheticContent = Buffer.from(`${STORAGE_RUNTIME_MARKER}:${randomBytes(32).toString('hex')}`, 'utf8')
    const contentHash = sha256(syntheticContent)

    const beforeUpload = await listExactObject(bucketClient, objectName)
    assertNoExistingObject(beforeUpload, objectName)

    const { error: uploadError } = await bucketClient.upload(objectName, syntheticContent, {
      contentType: 'text/plain; charset=utf-8',
      cacheControl: '0',
      upsert: false
    })
    if (uploadError) fail('storage_upload_failed')
    uploaded = true

    const uploadedEntries = await listExactObject(bucketClient, objectName)
    if (uploadedEntries.length !== 1) fail('storage_metadata_missing')
    const storedSize = Number(uploadedEntries[0]?.metadata?.size)
    if (!Number.isFinite(storedSize) || storedSize !== syntheticContent.byteLength) fail('storage_metadata_mismatch')
    reporter.emit('BKL-016 Storage upload passed', {
      bucket: STORAGE_RUNTIME_BUCKET,
      bytes: syntheticContent.byteLength,
      sha256: contentHash
    })

    const publicData = bucketClient.getPublicUrl(objectName)
    publicUrl = publicData?.data?.publicUrl ?? ''
    if (!publicUrl) fail('anonymous_url_prepare_failed')
    const anonymousResponse = await fetchImpl(publicUrl, { redirect: 'error', cache: 'no-store' })
    if (anonymousResponse.ok) fail('anonymous_access_unexpectedly_allowed')
    reporter.emit('BKL-016 anonymous access denied', { statusClass: statusClass(anonymousResponse.status) })

    const signedCreatedAt = Date.now()
    const { data: signedData, error: signedError } = await bucketClient.createSignedUrl(
      objectName,
      configuration.ttl,
      { download: true }
    )
    signedUrl = signedData?.signedUrl ?? ''
    if (signedError || !signedUrl) fail('signed_url_creation_failed')

    const signedResponse = await fetchImpl(signedUrl, { redirect: 'error', cache: 'no-store' })
    if (!signedResponse.ok) fail('signed_url_pre_expiry_download_failed')
    const signedBytes = Buffer.from(await signedResponse.arrayBuffer())
    if (sha256(signedBytes) !== contentHash) fail('signed_url_pre_expiry_hash_mismatch')
    reporter.emit('BKL-016 signed URL pre-expiry download passed', {
      bytes: signedBytes.byteLength,
      sha256: contentHash,
      nominalTtlSeconds: configuration.ttl
    })

    const nominalExpiryAt = signedCreatedAt + configuration.ttl * 1000
    await sleep(Math.max(0, nominalExpiryAt + configuration.margin * 1000 - Date.now()))
    const toleranceDeadline = nominalExpiryAt + MAX_EXPIRY_TOLERANCE_SECONDS * 1000
    let expiredResponse = await fetchImpl(signedUrl, { redirect: 'error', cache: 'no-store' })
    while (expiredResponse.ok && Date.now() < toleranceDeadline) {
      await sleep(2000)
      expiredResponse = await fetchImpl(signedUrl, { redirect: 'error', cache: 'no-store' })
    }
    if (expiredResponse.ok) fail('signed_url_expiration_not_enforced')
    const observedExpirationSeconds = Math.ceil((Date.now() - signedCreatedAt) / 1000)
    reporter.emit('BKL-016 signed URL expiration passed', {
      nominalTtlSeconds: configuration.ttl,
      observedExpirationSeconds,
      statusClass: statusClass(expiredResponse.status)
    })

    const signedToken = (() => {
      try {
        const parsed = new URL(signedUrl)
        return parsed.searchParams.get('token') ?? parsed.searchParams.get('signature') ?? ''
      } catch {
        return ''
      }
    })()
    const exactForbiddenValues = [backendKey, signedUrl, signedToken, syntheticContent.toString('utf8')].filter(Boolean)
    await scanRelevantFiles(repoRoot, exactForbiddenValues)
    scanGitHistory(repoRoot, exactForbiddenValues)
    if (reporter.emittedLines.some((line) => exactForbiddenValues.some((value) => line.includes(value)))) {
      fail('runtime_output_sensitive_value_persisted')
    }
    reporter.emit('BKL-016 Storage local leak scan passed')
  } finally {
    if (uploaded && objectName) {
      const { error: removeError } = await bucketClient.remove([objectName])
      if (!removeError) {
        const afterRemoval = await listExactObject(bucketClient, objectName)
        const { data: residualData, error: residualError } = await bucketClient.download(objectName)
        if (afterRemoval.length === 0 && residualError && !residualData) cleanupConfirmed = true
      }
    }
    signedUrl = ''
    publicUrl = ''
    backendKey = ''
    syntheticContent = undefined
    objectName = ''
  }

  if (!cleanupConfirmed) fail('storage_cleanup_failed')
  reporter.emit('BKL-016 Storage cleanup passed', { bucket: STORAGE_RUNTIME_BUCKET })
  return { ttlSeconds: configuration.ttl, emittedLines: [...reporter.emittedLines] }
}

async function main() {
  let reporter
  try {
    reporter = createSafeReporter()
    await runStorageRuntime()
  } catch (error) {
    const category = error instanceof StorageRuntimeError ? error.category : 'runtime_failed'
    reporter?.emitFailure(category)
    process.exitCode = 1
  }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  await main()
}
