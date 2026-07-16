import test from 'node:test'
import assert from 'node:assert/strict'
import { CONFIRMATION, EXPECTED_BRANCH, RetentionRuntimeError, validateDeleteGate } from './retention-runtime.mjs'

const valid = {
  confirmation: CONFIRMATION,
  branch: EXPECTED_BRANCH,
  localUrl: 'http://127.0.0.1:54321',
  ids: ['a9000000-0000-4000-8000-000000000001'],
  preexistingStack: false,
  protectedDiff: false
}

test('gate aceita somente contexto sintetico local explicito', () => {
  assert.equal(validateDeleteGate(valid), true)
})

for (const [name, patch, category] of [
  ['confirmacao ausente', { confirmation: '' }, 'human_confirmation_required'],
  ['branch incorreta', { branch: 'main' }, 'branch_rejected'],
  ['stack preexistente', { preexistingStack: true }, 'preexisting_local_stack_rejected'],
  ['arquivo protegido alterado', { protectedDiff: true }, 'protected_path_modified'],
  ['alvo remoto', { localUrl: 'https://example.invalid' }, 'non_local_target_rejected'],
  ['lista vazia', { ids: [] }, 'explicit_id_batch_rejected'],
  ['lote grande', { ids: Array.from({ length: 11 }, (_, i) => `a9000000-0000-4000-8000-${String(i).padStart(12, '0')}`) }, 'explicit_id_batch_rejected'],
  ['ID nao sintetico', { ids: ['90000000-0000-4000-8000-000000000001'] }, 'synthetic_id_rejected']
]) {
  test(name, () => {
    assert.throws(() => validateDeleteGate({ ...valid, ...patch }), (error) => {
      assert.ok(error instanceof RetentionRuntimeError)
      assert.equal(error.category, category)
      return true
    })
  })
}
