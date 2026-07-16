import assert from 'node:assert/strict'
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import test from 'node:test'
import {
  SYNTHETIC_CONTEXT, SYNTHETIC_PLAINTEXT, assertBackupArtifactSafe,
  cloneEnvelope, createEphemeralRecoveryFixture, deserializeEnvelope,
  serializeEnvelope, sha256
} from './backup-recovery.mjs'

async function expectCategory(category, callback) {
  await assert.rejects(callback, (error) => error?.category === category)
}

test('backup serializado recupera envelope com KEK efemera ainda disponivel', async (t) => {
  const { kms, service } = createEphemeralRecoveryFixture()
  t.after(() => kms.destroy())
  await kms.rotateTestKek()
  const envelope = await service.encrypt(SYNTHETIC_PLAINTEXT, SYNTHETIC_CONTEXT)
  assert.equal(envelope.keyReference.version, '2')
  const serialized = serializeEnvelope(envelope)
  assert.doesNotMatch(serialized, /BKL016_SYNTHETIC_BACKUP_RECOVERY_PAYLOAD/)
  assertBackupArtifactSafe(serialized)
  const restored = deserializeEnvelope(serialized)
  const recovered = await service.decrypt(restored, SYNTHETIC_CONTEXT)
  assert.equal(sha256(recovered), sha256(SYNTHETIC_PLAINTEXT))
  recovered.fill(0)
})

test('ausencia da versao da KEK falha fechada', async (t) => {
  const source = createEphemeralRecoveryFixture()
  const missing = createEphemeralRecoveryFixture()
  t.after(() => source.kms.destroy())
  t.after(() => missing.kms.destroy())
  await source.kms.rotateTestKek()
  const envelope = await source.service.encrypt(SYNTHETIC_PLAINTEXT, SYNTHETIC_CONTEXT)
  await expectCategory('key_version_unavailable', () =>
    missing.service.decrypt(deserializeEnvelope(serializeEnvelope(envelope)), SYNTHETIC_CONTEXT)
  )
})

test('ciphertext adulterado falha sem devolver plaintext', async (t) => {
  const { kms, service } = createEphemeralRecoveryFixture()
  t.after(() => kms.destroy())
  const envelope = await service.encrypt(SYNTHETIC_PLAINTEXT, SYNTHETIC_CONTEXT)
  const ciphertext = Buffer.from(envelope.ciphertext)
  ciphertext[0] ^= 0xff
  await expectCategory('envelope_authentication_failed', () =>
    service.decrypt(cloneEnvelope(envelope, { ciphertext }), SYNTHETIC_CONTEXT)
  )
})

test('scanner rejeita PII, URL assinada, JWT, autorizacao e plaintext', () => {
  const unsafe = [
    'BKL016_SYNTHETIC_BACKUP_RECOVERY_PAYLOAD',
    'https://local.invalid/storage/v1/object/sign/private/item?token=x',
    'Authorization=secret',
    'eyJaaaaaaaaaaa.bbbbbbbbbbb.ccccccccccc',
    `${['123', '456', '789'].join('.')}-${['0', '0'].join('')}`
  ]
  for (const value of unsafe) {
    assert.throws(() => assertBackupArtifactSafe(value), { message: 'backup_artifact_sensitive_content' })
  }
})

test('scanner aceita UUID e nome de coluna de autorizacao do schema', () => {
  assert.equal(assertBackupArtifactSafe(
    'operation_id=20000000-0000-4000-8000-000000000003\n' +
    'final_authorization_evidence_payload_ref = payload_id\n'
  ), true)
})

test('artefato temporario e removido integralmente', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'cbn-bkl016-recovery-'))
  const artifact = join(directory, 'synthetic-envelope.json')
  try {
    const { kms, service } = createEphemeralRecoveryFixture()
    try {
      const envelope = await service.encrypt(SYNTHETIC_PLAINTEXT, SYNTHETIC_CONTEXT)
      await writeFile(artifact, serializeEnvelope(envelope), { encoding: 'utf8', flag: 'wx' })
      assertBackupArtifactSafe(await readFile(artifact))
    } finally {
      kms.destroy()
    }
  } finally {
    await rm(directory, { recursive: true, force: true })
  }
  await assert.rejects(readFile(artifact), { code: 'ENOENT' })
})
