import assert from 'node:assert/strict'
import test from 'node:test'
import {
  STORAGE_RUNTIME_BRANCH,
  STORAGE_RUNTIME_BUCKET,
  StorageRuntimeError,
  assertNoExistingObject,
  assertSafeObjectName,
  createSafeReporter,
  validateRuntimeConfiguration
} from './supabase-storage-runtime-test.mjs'

const validInput = {
  environment: 'development',
  runtimeConfirmed: 'true',
  bucket: STORAGE_RUNTIME_BUCKET,
  projectUrl: 'https://abcdefghijklmnopqrst.supabase.co',
  projectRef: 'abcdefghijklmnopqrst',
  backendKey: 'synthetic-backend-key-for-local-negative-tests',
  branch: STORAGE_RUNTIME_BRANCH,
  gitClean: true,
  signedUrlTtlSeconds: '30',
  expiryMarginSeconds: '5'
}

function expectCategory(category, callback) {
  assert.throws(callback, (error) => error instanceof StorageRuntimeError && error.category === category)
}

test('aceita somente o bucket temporario permitido', () => {
  expectCategory('bucket_rejected', () => validateRuntimeConfiguration({ ...validInput, bucket: 'other-private' }))
})

test('rejeita nome de objeto fora do padrao UUID ou hash', () => {
  expectCategory('object_name_rejected', () => assertSafeObjectName('cliente-documento.txt'))
  assert.equal(assertSafeObjectName('8f7b65d2-c943-4a5e-a331-872930cb91b0'), '8f7b65d2-c943-4a5e-a331-872930cb91b0')
})

test('rejeita overwrite quando o objeto ja existe', () => {
  expectCategory('overwrite_rejected', () => assertNoExistingObject([{ name: 'same-object' }], 'same-object'))
})

test('rejeita URL de projeto divergente do alvo confirmado', () => {
  expectCategory('project_url_target_mismatch', () => validateRuntimeConfiguration({
    ...validInput,
    projectUrl: 'https://differentprojectref.supabase.co'
  }))
})

test('rejeita execucao na main', () => {
  expectCategory('branch_rejected', () => validateRuntimeConfiguration({ ...validInput, branch: 'main' }))
})

test('rejeita execucao sem confirmacao sintetica', () => {
  expectCategory('synthetic_confirmation_missing', () => validateRuntimeConfiguration({
    ...validInput,
    runtimeConfirmed: undefined
  }))
})

test('rejeita execucao sem credencial backend local', () => {
  expectCategory('backend_credential_missing', () => validateRuntimeConfiguration({
    ...validInput,
    backendKey: undefined
  }))
})

test('rejeita tentativa de imprimir ou persistir URL assinada', () => {
  const lines = []
  const reporter = createSafeReporter({ writeLine: (line) => lines.push(line) })
  expectCategory('unsafe_output_rejected', () => reporter.emit('BKL-016 Storage upload passed', {
    bucket: STORAGE_RUNTIME_BUCKET,
    signedUrl: 'https://example.invalid/storage/v1/object/sign/file?token=synthetic'
  }))
  assert.deepEqual(lines, [])
})

test('rejeita expiracao fora da janela curta permitida', () => {
  expectCategory('signed_url_ttl_rejected', () => validateRuntimeConfiguration({
    ...validInput,
    signedUrlTtlSeconds: '300'
  }))
})
