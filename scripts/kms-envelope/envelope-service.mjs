import {
  createCipheriv, createDecipheriv, createHash, randomBytes, timingSafeEqual
} from 'node:crypto'
import {
  KmsAdapterError, assertKeyReference, assertKmsAdapter
} from './kms-adapter.mjs'

export const CONTENT_ALGORITHM = 'AES-256-GCM'
export const ENVELOPE_VERSION = 1
export const AAD_VERSION = 1
const KEY_BYTES = 32
const NONCE_BYTES = 12
const TAG_BYTES = 16
const UUID_PATTERN = /^[a-f0-9]{8}-[a-f0-9]{4}-[1-5][a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/
const CODE_PATTERN = /^[A-Z0-9_:-]{1,80}$/
const BUCKET_PATTERN = /^cbn-(?:documents|raw-payloads|evidence|temporary)-private$/
const OBJECT_PATTERN = /^[a-f0-9-]{16,200}(?:\/[a-f0-9-]{16,200})*$/
const ENVELOPE_KEYS = [
  'aadSha256', 'aadVersion', 'algorithm', 'ciphertext', 'envelopeVersion',
  'keyReference', 'nonce', 'tag', 'wrappedDek'
].sort().join(',')

export class EnvelopeError extends Error {
  constructor(category) {
    super(category)
    this.name = 'EnvelopeError'
    this.category = category
  }
}

function fail(category) {
  throw new EnvelopeError(category)
}

function copyEnvelope(envelope, overrides = {}) {
  return {
    envelopeVersion: envelope.envelopeVersion,
    algorithm: envelope.algorithm,
    ciphertext: Buffer.from(envelope.ciphertext),
    wrappedDek: Buffer.from(envelope.wrappedDek),
    nonce: Buffer.from(envelope.nonce),
    tag: Buffer.from(envelope.tag),
    keyReference: Object.freeze({ ...envelope.keyReference }),
    aadVersion: envelope.aadVersion,
    aadSha256: envelope.aadSha256,
    ...overrides
  }
}

function assertUuid(value, category) {
  if (value !== undefined && !UUID_PATTERN.test(value)) fail(category)
}

export function canonicalizeAadContext(context) {
  if (!context || typeof context !== 'object' || Array.isArray(context)) {
    fail('aad_context_invalid')
  }
  const allowedKeys = new Set([
    'payloadType', 'clientId', 'operationId', 'proposalId', 'bucketName', 'objectName'
  ])
  if (Object.keys(context).some((key) => !allowedKeys.has(key)) ||
      !CODE_PATTERN.test(context.payloadType)) {
    fail('aad_context_invalid')
  }
  assertUuid(context.clientId, 'aad_client_invalid')
  assertUuid(context.operationId, 'aad_operation_invalid')
  assertUuid(context.proposalId, 'aad_proposal_invalid')
  const hasFileField = context.bucketName !== undefined || context.objectName !== undefined
  if (hasFileField && (!BUCKET_PATTERN.test(context.bucketName) ||
      !OBJECT_PATTERN.test(context.objectName))) {
    fail('aad_file_context_invalid')
  }
  if (!context.clientId && !context.operationId && !context.proposalId && !hasFileField) {
    fail('aad_owner_missing')
  }
  return Buffer.from(JSON.stringify({
    aadVersion: AAD_VERSION,
    envelopeVersion: ENVELOPE_VERSION,
    payloadType: context.payloadType,
    clientId: context.clientId ?? null,
    operationId: context.operationId ?? null,
    proposalId: context.proposalId ?? null,
    bucketName: context.bucketName ?? null,
    objectName: context.objectName ?? null
  }), 'utf8')
}

function sha256Hex(value) {
  return createHash('sha256').update(value).digest('hex')
}

function assertEnvelope(envelope) {
  if (!envelope || typeof envelope !== 'object' || Array.isArray(envelope) ||
      Object.keys(envelope).sort().join(',') !== ENVELOPE_KEYS) {
    fail('envelope_incomplete')
  }
  if (envelope.envelopeVersion !== ENVELOPE_VERSION) fail('envelope_version_unknown')
  if (envelope.algorithm !== CONTENT_ALGORITHM) fail('envelope_algorithm_invalid')
  if (envelope.aadVersion !== AAD_VERSION || !/^[a-f0-9]{64}$/.test(envelope.aadSha256)) {
    fail('envelope_aad_metadata_invalid')
  }
  if (!Buffer.isBuffer(envelope.ciphertext) || envelope.ciphertext.length < 1 ||
      !Buffer.isBuffer(envelope.wrappedDek) || envelope.wrappedDek.length < 32 ||
      !Buffer.isBuffer(envelope.nonce) || envelope.nonce.length !== NONCE_BYTES ||
      !Buffer.isBuffer(envelope.tag) || envelope.tag.length !== TAG_BYTES) {
    fail('envelope_binary_metadata_invalid')
  }
  assertKeyReference(envelope.keyReference)
  return envelope
}

function assertContextMatches(envelope, aad) {
  const actual = Buffer.from(sha256Hex(aad), 'hex')
  const expected = Buffer.from(envelope.aadSha256, 'hex')
  if (actual.length !== expected.length || !timingSafeEqual(actual, expected)) {
    fail('aad_context_mismatch')
  }
}

export class EnvelopeEncryptionService {
  #kms
  #auditSink

  constructor({ kmsAdapter, auditSink = () => {} } = {}) {
    this.#kms = assertKmsAdapter(kmsAdapter)
    if (typeof auditSink !== 'function') fail('audit_sink_invalid')
    this.#auditSink = auditSink
  }

  #audit(eventType, envelope, extra = {}) {
    this.#auditSink(Object.freeze({
      eventType,
      algorithm: envelope.algorithm,
      envelopeVersion: envelope.envelopeVersion,
      keyAlias: envelope.keyReference.alias,
      keyVersion: envelope.keyReference.version,
      ...extra
    }))
  }

  async healthCheck() {
    return this.#kms.healthCheck()
  }

  async encrypt(plaintext, context) {
    if (!Buffer.isBuffer(plaintext) || plaintext.length === 0) fail('plaintext_empty')
    const aad = canonicalizeAadContext(context)
    const aadSha256 = sha256Hex(aad)
    const dek = randomBytes(KEY_BYTES)
    const nonce = randomBytes(NONCE_BYTES)
    let ciphertext
    let tag
    try {
      const cipher = createCipheriv('aes-256-gcm', dek, nonce, { authTagLength: TAG_BYTES })
      cipher.setAAD(aad)
      ciphertext = Buffer.concat([cipher.update(plaintext), cipher.final()])
      tag = cipher.getAuthTag()
      const keyReference = await this.#kms.getKeyReference()
      const wrapped = await this.#kms.wrapKey(dek, { keyReference, aadSha256 })
      const envelope = {
        envelopeVersion: ENVELOPE_VERSION,
        algorithm: CONTENT_ALGORITHM,
        ciphertext: Buffer.from(ciphertext),
        wrappedDek: Buffer.from(wrapped.wrappedKey),
        nonce: Buffer.from(nonce),
        tag: Buffer.from(tag),
        keyReference: Object.freeze({ ...wrapped.keyReference }),
        aadVersion: AAD_VERSION,
        aadSha256
      }
      assertEnvelope(envelope)
      this.#audit('envelope_encrypted', envelope)
      return envelope
    } finally {
      dek.fill(0)
      aad.fill(0)
      nonce.fill(0)
      ciphertext?.fill(0)
      tag?.fill(0)
    }
  }

  async decrypt(envelope, context) {
    assertEnvelope(envelope)
    const aad = canonicalizeAadContext(context)
    assertContextMatches(envelope, aad)
    let dek
    try {
      dek = await this.#kms.unwrapKey(envelope.wrappedDek, {
        keyReference: envelope.keyReference,
        aadSha256: envelope.aadSha256
      })
      const decipher = createDecipheriv('aes-256-gcm', dek, envelope.nonce, {
        authTagLength: TAG_BYTES
      })
      decipher.setAAD(aad)
      decipher.setAuthTag(envelope.tag)
      const plaintext = Buffer.concat([
        decipher.update(envelope.ciphertext), decipher.final()
      ])
      this.#audit('envelope_decrypted', envelope)
      return plaintext
    } catch (error) {
      if (error instanceof EnvelopeError || error instanceof KmsAdapterError) throw error
      fail('envelope_authentication_failed')
    } finally {
      dek?.fill(0)
      aad.fill(0)
    }
  }

  async rotateKek(envelope, context, targetKeyReference) {
    assertEnvelope(envelope)
    const aad = canonicalizeAadContext(context)
    assertContextMatches(envelope, aad)
    assertKeyReference(targetKeyReference)
    try {
      const rewrapped = await this.#kms.rewrapDataKey(envelope.wrappedDek, {
        fromKeyReference: envelope.keyReference,
        toKeyReference: targetKeyReference,
        aadSha256: envelope.aadSha256
      })
      const rotated = copyEnvelope(envelope, {
        wrappedDek: Buffer.from(rewrapped.wrappedKey),
        keyReference: Object.freeze({ ...rewrapped.keyReference })
      })
      assertEnvelope(rotated)
      this.#audit('kek_rewrapped', rotated, {
        previousKeyVersion: envelope.keyReference.version
      })
      return rotated
    } finally {
      aad.fill(0)
    }
  }

  async rotateDek(envelope, context) {
    assertEnvelope(envelope)
    const plaintext = await this.decrypt(envelope, context)
    try {
      const rotated = await this.encrypt(plaintext, context)
      this.#audit('dek_rotated', rotated, {
        previousKeyVersion: envelope.keyReference.version
      })
      return rotated
    } finally {
      plaintext.fill(0)
    }
  }
}
