import assert from 'node:assert/strict'
import test from 'node:test'
import { randomUUID } from 'node:crypto'
import { EnvelopeEncryptionService, EnvelopeError } from './envelope-service.mjs'
import { KmsAdapterError } from './kms-adapter.mjs'
import { LocalTestKmsAdapter } from './local-test-kms-adapter.mjs'

const SYNTHETIC_PLAINTEXT = Buffer.from('BKL016_SYNTHETIC_ENVELOPE_PAYLOAD', 'utf8')

function makeContext(overrides = {}) {
  return {
    payloadType: 'SYNTHETIC_KMS_TEST',
    clientId: '10000000-0000-4000-8000-000000000001',
    operationId: '20000000-0000-4000-8000-000000000001',
    proposalId: '60000000-0000-4000-8000-000000000001',
    ...overrides
  }
}

function createFixture() {
  const auditEvents = []
  const kms = new LocalTestKmsAdapter({ environment: 'test', allowLocalTestKms: true })
  const service = new EnvelopeEncryptionService({
    kmsAdapter: kms,
    auditSink: (event) => auditEvents.push(event)
  })
  return { kms, service, auditEvents }
}

function mutate(buffer) {
  const copy = Buffer.from(buffer)
  copy[0] ^= 0xff
  return copy
}

function cloneEnvelope(envelope, overrides = {}) {
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

async function expectCategory(category, callback) {
  await assert.rejects(callback, (error) =>
    (error instanceof EnvelopeError || error instanceof KmsAdapterError) &&
    error.category === category
  )
}

test('round-trip positivo e health check local', async (t) => {
  const { kms, service } = createFixture()
  t.after(() => kms.destroy())
  assert.deepEqual(await service.healthCheck(), { ok: true, provider: 'local-test-only' })
  const envelope = await service.encrypt(SYNTHETIC_PLAINTEXT, makeContext())
  const plaintext = await service.decrypt(envelope, makeContext())
  assert.deepEqual(plaintext, SYNTHETIC_PLAINTEXT)
  plaintext.fill(0)
})

test('rejeita plaintext vazio', async (t) => {
  const { kms, service } = createFixture()
  t.after(() => kms.destroy())
  await expectCategory('plaintext_empty', () => service.encrypt(Buffer.alloc(0), makeContext()))
})

test('mesmo plaintext usa DEK, nonce e ciphertext diferentes', async (t) => {
  const { kms, service } = createFixture()
  t.after(() => kms.destroy())
  const first = await service.encrypt(SYNTHETIC_PLAINTEXT, makeContext())
  const second = await service.encrypt(SYNTHETIC_PLAINTEXT, makeContext())
  assert.notDeepEqual(first.nonce, second.nonce)
  assert.notDeepEqual(first.ciphertext, second.ciphertext)
  const firstDek = await kms.unwrapKey(first.wrappedDek, {
    keyReference: first.keyReference, aadSha256: first.aadSha256
  })
  const secondDek = await kms.unwrapKey(second.wrappedDek, {
    keyReference: second.keyReference, aadSha256: second.aadSha256
  })
  assert.notDeepEqual(firstDek, secondDek)
  firstDek.fill(0)
  secondDek.fill(0)
})

test('AAD correto aceita e cliente, operacao e proposta divergentes rejeitam', async (t) => {
  const { kms, service } = createFixture()
  t.after(() => kms.destroy())
  const envelope = await service.encrypt(SYNTHETIC_PLAINTEXT, makeContext())
  const ok = await service.decrypt(envelope, makeContext())
  ok.fill(0)
  await expectCategory('aad_context_mismatch', () => service.decrypt(envelope, makeContext({
    clientId: randomUUID()
  })))
  await expectCategory('aad_context_mismatch', () => service.decrypt(envelope, makeContext({
    operationId: randomUUID()
  })))
  await expectCategory('aad_context_mismatch', () => service.decrypt(envelope, makeContext({
    proposalId: randomUUID()
  })))
})

test('AAD de arquivo vincula bucket e object name', async (t) => {
  const { kms, service } = createFixture()
  t.after(() => kms.destroy())
  const fileContext = {
    payloadType: 'SYNTHETIC_FILE',
    clientId: '10000000-0000-4000-8000-000000000001',
    bucketName: 'cbn-documents-private',
    objectName: `${randomUUID()}/${randomUUID()}`
  }
  const envelope = await service.encrypt(SYNTHETIC_PLAINTEXT, fileContext)
  await expectCategory('aad_context_mismatch', () => service.decrypt(envelope, {
    ...fileContext, bucketName: 'cbn-evidence-private'
  }))
})

test('recusa tag, ciphertext, nonce e wrapped DEK adulterados', async (t) => {
  const { kms, service } = createFixture()
  t.after(() => kms.destroy())
  const envelope = await service.encrypt(SYNTHETIC_PLAINTEXT, makeContext())
  await expectCategory('envelope_authentication_failed', () => service.decrypt(
    cloneEnvelope(envelope, { tag: mutate(envelope.tag) }), makeContext()
  ))
  await expectCategory('envelope_authentication_failed', () => service.decrypt(
    cloneEnvelope(envelope, { ciphertext: mutate(envelope.ciphertext) }), makeContext()
  ))
  await expectCategory('envelope_authentication_failed', () => service.decrypt(
    cloneEnvelope(envelope, { nonce: mutate(envelope.nonce) }), makeContext()
  ))
  await expectCategory('wrapped_key_invalid', () => service.decrypt(
    cloneEnvelope(envelope, { wrappedDek: mutate(envelope.wrappedDek) }), makeContext()
  ))
})

test('recusa key version incorreta, envelope desconhecido e envelope incompleto', async (t) => {
  const { kms, service } = createFixture()
  t.after(() => kms.destroy())
  const envelope = await service.encrypt(SYNTHETIC_PLAINTEXT, makeContext())
  await expectCategory('key_version_unavailable', () => service.decrypt(cloneEnvelope(envelope, {
    keyReference: { ...envelope.keyReference, version: '999' }
  }), makeContext()))
  await expectCategory('envelope_version_unknown', () => service.decrypt(cloneEnvelope(envelope, {
    envelopeVersion: 2
  }), makeContext()))
  const incomplete = cloneEnvelope(envelope)
  delete incomplete.tag
  await expectCategory('envelope_incomplete', () => service.decrypt(incomplete, makeContext()))
})

test('rotacao de KEK preserva plaintext sem alterar ciphertext', async (t) => {
  const { kms, service, auditEvents } = createFixture()
  t.after(() => kms.destroy())
  const original = await service.encrypt(SYNTHETIC_PLAINTEXT, makeContext())
  const target = await kms.rotateTestKek()
  const rotated = await service.rotateKek(original, makeContext(), target)
  assert.deepEqual(rotated.ciphertext, original.ciphertext)
  assert.deepEqual(rotated.nonce, original.nonce)
  assert.deepEqual(rotated.tag, original.tag)
  assert.notDeepEqual(rotated.wrappedDek, original.wrappedDek)
  assert.notEqual(rotated.keyReference.version, original.keyReference.version)
  const plaintext = await service.decrypt(rotated, makeContext())
  assert.deepEqual(plaintext, SYNTHETIC_PLAINTEXT)
  plaintext.fill(0)
  assert(auditEvents.some((event) => event.eventType === 'kek_rewrapped'))
  const rollbackPlaintext = await service.decrypt(original, makeContext())
  assert.deepEqual(rollbackPlaintext, SYNTHETIC_PLAINTEXT)
  rollbackPlaintext.fill(0)
})

test('rotacao de DEK preserva plaintext e muda envelope criptografico', async (t) => {
  const { kms, service, auditEvents } = createFixture()
  t.after(() => kms.destroy())
  const original = await service.encrypt(SYNTHETIC_PLAINTEXT, makeContext())
  const rotated = await service.rotateDek(original, makeContext())
  assert.notDeepEqual(rotated.ciphertext, original.ciphertext)
  assert.notDeepEqual(rotated.nonce, original.nonce)
  assert.notDeepEqual(rotated.wrappedDek, original.wrappedDek)
  const plaintext = await service.decrypt(rotated, makeContext())
  assert.deepEqual(plaintext, SYNTHETIC_PLAINTEXT)
  plaintext.fill(0)
  assert(auditEvents.some((event) => event.eventType === 'dek_rotated'))
})

test('falha de rotacao nao altera nem destrói envelope anterior', async (t) => {
  const { kms, service } = createFixture()
  t.after(() => kms.destroy())
  const original = await service.encrypt(SYNTHETIC_PLAINTEXT, makeContext())
  const snapshot = cloneEnvelope(original)
  kms.setTestFailureMode('wrap')
  await expectCategory('synthetic_wrap_failure', () => service.rotateDek(original, makeContext()))
  kms.setTestFailureMode(null)
  assert.deepEqual(original, snapshot)
  const plaintext = await service.decrypt(original, makeContext())
  assert.deepEqual(plaintext, SYNTHETIC_PLAINTEXT)
  plaintext.fill(0)
})

test('adaptador local falha fechado fora do ambiente de teste', () => {
  assert.throws(
    () => new LocalTestKmsAdapter({ environment: 'development', allowLocalTestKms: true }),
    (error) => error instanceof KmsAdapterError && error.category === 'local_test_kms_not_allowed'
  )
  assert.throws(
    () => new LocalTestKmsAdapter({ environment: 'test', allowLocalTestKms: false }),
    (error) => error instanceof KmsAdapterError && error.category === 'local_test_kms_not_allowed'
  )
})

test('auditoria e erros nao expõem plaintext ou material criptografico completo', async (t) => {
  const { kms, service, auditEvents } = createFixture()
  t.after(() => kms.destroy())
  const envelope = await service.encrypt(SYNTHETIC_PLAINTEXT, makeContext())
  let failure
  try {
    await service.decrypt(cloneEnvelope(envelope, { tag: mutate(envelope.tag) }), makeContext())
  } catch (error) {
    failure = error
  }
  const safeOutput = JSON.stringify({ auditEvents, error: failure?.category })
  const forbidden = [
    SYNTHETIC_PLAINTEXT.toString('utf8'),
    envelope.ciphertext.toString('base64'),
    envelope.wrappedDek.toString('base64'),
    envelope.nonce.toString('hex'),
    envelope.tag.toString('hex')
  ]
  assert(forbidden.every((value) => !safeOutput.includes(value)))
  assert(!/password|authorization|token|secret/i.test(safeOutput))
})
