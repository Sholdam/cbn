import { createCipheriv, createDecipheriv, randomBytes } from 'node:crypto'
import { KmsAdapterError, assertKeyReference } from './kms-adapter.mjs'

const ALGORITHM = 'aes-256-gcm'
const WRAP_FORMAT_VERSION = 1
const KEY_BYTES = 32
const NONCE_BYTES = 12
const TAG_BYTES = 16
const ALLOWED_FAILURES = new Set(['wrap', 'unwrap', 'rewrap'])

function fail(category) {
  throw new KmsAdapterError(category)
}

function decodeCanonicalBase64(value, expectedBytes, category) {
  if (typeof value !== 'string' || !/^[A-Za-z0-9+/]+={0,2}$/.test(value)) fail(category)
  const decoded = Buffer.from(value, 'base64')
  if (decoded.length !== expectedBytes || decoded.toString('base64') !== value) fail(category)
  return decoded
}

function wrapAad(reference, aadSha256) {
  if (!/^[a-f0-9]{64}$/.test(aadSha256)) fail('wrap_aad_hash_invalid')
  return Buffer.from(JSON.stringify({
    formatVersion: WRAP_FORMAT_VERSION,
    purpose: 'BKL016_LOCAL_TEST_DEK_WRAP',
    provider: reference.provider,
    keyAlias: reference.alias,
    keyVersion: reference.version,
    aadSha256
  }), 'utf8')
}

function parseWrappedKey(wrappedKey) {
  if (!Buffer.isBuffer(wrappedKey) || wrappedKey.length < 120 || wrappedKey.length > 4096) {
    fail('wrapped_key_invalid')
  }
  let parsed
  try {
    parsed = JSON.parse(wrappedKey.toString('utf8'))
  } catch {
    fail('wrapped_key_invalid')
  }
  const keys = Object.keys(parsed ?? {}).sort().join(',')
  if (keys !== 'aadSha256,algorithm,ciphertext,formatVersion,keyAlias,keyVersion,nonce,provider,tag' ||
      parsed.formatVersion !== WRAP_FORMAT_VERSION || parsed.algorithm !== 'AES-256-GCM' ||
      parsed.provider !== 'local-test-only' || !/^[a-f0-9]{64}$/.test(parsed.aadSha256)) {
    fail('wrapped_key_invalid')
  }
  const reference = assertKeyReference({
    provider: parsed.provider,
    alias: parsed.keyAlias,
    version: parsed.keyVersion
  })
  return {
    reference,
    aadSha256: parsed.aadSha256,
    nonce: decodeCanonicalBase64(parsed.nonce, NONCE_BYTES, 'wrapped_key_invalid'),
    ciphertext: decodeCanonicalBase64(parsed.ciphertext, KEY_BYTES, 'wrapped_key_invalid'),
    tag: decodeCanonicalBase64(parsed.tag, TAG_BYTES, 'wrapped_key_invalid')
  }
}

export class LocalTestKmsAdapter {
  #alias
  #currentVersion
  #masterKeys = new Map()
  #failureMode = null
  #destroyed = false

  constructor({ environment, allowLocalTestKms, alias = 'local-test-bkl016-kek' } = {}) {
    if (environment !== 'test' || allowLocalTestKms !== true) fail('local_test_kms_not_allowed')
    if (!/^local-test-[a-z0-9-]{3,80}$/.test(alias)) fail('local_test_alias_invalid')
    this.#alias = alias
    this.#currentVersion = '1'
    this.#masterKeys.set(this.#currentVersion, randomBytes(KEY_BYTES))
  }

  #assertAvailable() {
    if (this.#destroyed) fail('local_test_kms_destroyed')
  }

  #masterKey(reference) {
    this.#assertAvailable()
    assertKeyReference(reference)
    if (reference.provider !== 'local-test-only') fail('key_provider_unavailable')
    if (reference.alias !== this.#alias) fail('key_alias_unavailable')
    const masterKey = this.#masterKeys.get(reference.version)
    if (!masterKey) fail('key_version_unavailable')
    return masterKey
  }

  async healthCheck() {
    this.#assertAvailable()
    return Object.freeze({ ok: true, provider: 'local-test-only' })
  }

  async getKeyReference(version = this.#currentVersion) {
    const reference = Object.freeze({
      provider: 'local-test-only', alias: this.#alias, version: String(version)
    })
    this.#masterKey(reference)
    return reference
  }

  async wrapKey(dataKey, { keyReference, aadSha256 } = {}) {
    this.#assertAvailable()
    if (this.#failureMode === 'wrap') fail('synthetic_wrap_failure')
    if (!Buffer.isBuffer(dataKey) || dataKey.length !== KEY_BYTES) fail('data_key_invalid')
    const reference = keyReference ?? await this.getKeyReference()
    const masterKey = this.#masterKey(reference)
    const nonce = randomBytes(NONCE_BYTES)
    const cipher = createCipheriv(ALGORITHM, masterKey, nonce, { authTagLength: TAG_BYTES })
    cipher.setAAD(wrapAad(reference, aadSha256))
    const ciphertext = Buffer.concat([cipher.update(dataKey), cipher.final()])
    const tag = cipher.getAuthTag()
    const wrapped = Buffer.from(JSON.stringify({
      formatVersion: WRAP_FORMAT_VERSION,
      algorithm: 'AES-256-GCM',
      provider: reference.provider,
      keyAlias: reference.alias,
      keyVersion: reference.version,
      aadSha256,
      nonce: nonce.toString('base64'),
      ciphertext: ciphertext.toString('base64'),
      tag: tag.toString('base64')
    }), 'utf8')
    nonce.fill(0)
    ciphertext.fill(0)
    tag.fill(0)
    return { wrappedKey: wrapped, keyReference: Object.freeze({ ...reference }) }
  }

  async unwrapKey(wrappedKey, { keyReference, aadSha256 } = {}) {
    this.#assertAvailable()
    if (this.#failureMode === 'unwrap') fail('synthetic_unwrap_failure')
    assertKeyReference(keyReference)
    const masterKey = this.#masterKey(keyReference)
    const parsed = parseWrappedKey(wrappedKey)
    try {
      if (parsed.reference.alias !== keyReference.alias ||
          parsed.reference.version !== keyReference.version ||
          parsed.aadSha256 !== aadSha256) {
        fail('wrapped_key_context_mismatch')
      }
      const decipher = createDecipheriv(ALGORITHM, masterKey, parsed.nonce, {
        authTagLength: TAG_BYTES
      })
      decipher.setAAD(wrapAad(keyReference, aadSha256))
      decipher.setAuthTag(parsed.tag)
      return Buffer.concat([decipher.update(parsed.ciphertext), decipher.final()])
    } catch {
      fail('wrapped_key_authentication_failed')
    } finally {
      parsed.nonce.fill(0)
      parsed.ciphertext.fill(0)
      parsed.tag.fill(0)
    }
  }

  async rewrapDataKey(wrappedKey, {
    fromKeyReference, toKeyReference, aadSha256
  } = {}) {
    this.#assertAvailable()
    if (this.#failureMode === 'rewrap') fail('synthetic_rewrap_failure')
    const dataKey = await this.unwrapKey(wrappedKey, {
      keyReference: fromKeyReference, aadSha256
    })
    try {
      return await this.wrapKey(dataKey, { keyReference: toKeyReference, aadSha256 })
    } finally {
      dataKey.fill(0)
    }
  }

  async rotateTestKek() {
    this.#assertAvailable()
    const nextVersion = String(Number(this.#currentVersion) + 1)
    this.#masterKeys.set(nextVersion, randomBytes(KEY_BYTES))
    this.#currentVersion = nextVersion
    return this.getKeyReference(nextVersion)
  }

  setTestFailureMode(mode = null) {
    this.#assertAvailable()
    if (mode !== null && !ALLOWED_FAILURES.has(mode)) fail('failure_mode_invalid')
    this.#failureMode = mode
  }

  destroy() {
    for (const key of this.#masterKeys.values()) key.fill(0)
    this.#masterKeys.clear()
    this.#failureMode = null
    this.#destroyed = true
  }
}
