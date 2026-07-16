import { createHash } from 'node:crypto'
import { EnvelopeEncryptionService } from '../kms-envelope/envelope-service.mjs'
import { LocalTestKmsAdapter } from '../kms-envelope/local-test-kms-adapter.mjs'

const BINARY_FIELDS = ['ciphertext', 'wrappedDek', 'nonce', 'tag']
const REQUIRED_KEYS = [
  'aadSha256', 'aadVersion', 'algorithm', 'ciphertext', 'envelopeVersion',
  'keyReference', 'nonce', 'tag', 'wrappedDek'
].sort().join(',')

export const SYNTHETIC_CONTEXT = Object.freeze({
  payloadType: 'SYNTHETIC_BACKUP_RECOVERY',
  clientId: '10000000-0000-4000-8000-000000000001',
  operationId: '20000000-0000-4000-8000-000000000003',
  proposalId: '60000000-0000-4000-8000-000000000001'
})

export const SYNTHETIC_PLAINTEXT = Buffer.from(
  'BKL016_SYNTHETIC_BACKUP_RECOVERY_PAYLOAD', 'utf8'
)

function fail(category) {
  const error = new Error(category)
  error.name = 'BackupRecoveryError'
  error.category = category
  throw error
}

function canonicalBase64(value, category) {
  if (typeof value !== 'string' || !/^[A-Za-z0-9+/]+={0,2}$/.test(value)) fail(category)
  const decoded = Buffer.from(value, 'base64')
  if (decoded.length === 0 || decoded.toString('base64') !== value) fail(category)
  return decoded
}

export function serializeEnvelope(envelope) {
  const serialized = {
    envelopeVersion: envelope.envelopeVersion,
    algorithm: envelope.algorithm,
    ciphertext: envelope.ciphertext.toString('base64'),
    wrappedDek: envelope.wrappedDek.toString('base64'),
    nonce: envelope.nonce.toString('base64'),
    tag: envelope.tag.toString('base64'),
    keyReference: { ...envelope.keyReference },
    aadVersion: envelope.aadVersion,
    aadSha256: envelope.aadSha256
  }
  return `${JSON.stringify(serialized)}\n`
}

export function deserializeEnvelope(serialized) {
  let parsed
  try {
    parsed = JSON.parse(serialized)
  } catch {
    fail('backup_envelope_json_invalid')
  }
  if (!parsed || Object.keys(parsed).sort().join(',') !== REQUIRED_KEYS) {
    fail('backup_envelope_incomplete')
  }
  const restored = { ...parsed, keyReference: Object.freeze({ ...parsed.keyReference }) }
  for (const field of BINARY_FIELDS) {
    restored[field] = canonicalBase64(parsed[field], 'backup_envelope_binary_invalid')
  }
  return restored
}

export function sha256(value) {
  return createHash('sha256').update(value).digest('hex')
}

export function assertBackupArtifactSafe(content) {
  const text = Buffer.isBuffer(content) ? content.toString('utf8') : String(content)
  const forbidden = [
    /BKL016_SYNTHETIC_BACKUP_RECOVERY_PAYLOAD/,
    /https?:\/\/[^\s"']+\/storage\/v1\/object\/sign/i,
    /(?:^|[\r\n])\s*(?:service[_ -]?role|authorization)\s*[:=]/i,
    /eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}/,
    /\d{3}\.\d{3}\.\d{3}-\d{2}/,
    /(?<![A-Fa-f0-9-])\d{11}(?![A-Fa-f0-9-])/
  ]
  if (forbidden.some((pattern) => pattern.test(text))) fail('backup_artifact_sensitive_content')
  return true
}

export function createEphemeralRecoveryFixture() {
  const auditEvents = []
  const kms = new LocalTestKmsAdapter({
    environment: 'test', allowLocalTestKms: true, alias: 'local-test-bkl016-backup-kek'
  })
  const service = new EnvelopeEncryptionService({
    kmsAdapter: kms,
    auditSink: (event) => auditEvents.push(event)
  })
  return { kms, service, auditEvents }
}

export function cloneEnvelope(envelope, overrides = {}) {
  return {
    envelopeVersion: envelope.envelopeVersion,
    algorithm: envelope.algorithm,
    ciphertext: Buffer.from(envelope.ciphertext),
    wrappedDek: Buffer.from(envelope.wrappedDek),
    nonce: Buffer.from(envelope.nonce),
    tag: Buffer.from(envelope.tag),
    keyReference: { ...envelope.keyReference },
    aadVersion: envelope.aadVersion,
    aadSha256: envelope.aadSha256,
    ...overrides
  }
}
