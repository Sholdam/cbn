import test from 'node:test'
import assert from 'node:assert/strict'
import {
  BackendIdentityRuntimeError, CONFIRMATION, EXPECTED_BRANCH,
  LOCAL_URL, validateBackendIdentityGate
} from './backend-identity-runtime.mjs'

const valid = {
  confirmation: CONFIRMATION,
  branch: EXPECTED_BRANCH,
  localUrl: LOCAL_URL,
  preexistingStack: false,
  protectedDiff: false,
  remoteEnvironment: false
}

test('gate aceita somente teste sintetico local da identidade backend', () => {
  assert.equal(validateBackendIdentityGate(valid), true)
})

for (const [name, patch, category] of [
  ['confirmacao ausente', { confirmation: '' }, 'human_confirmation_required'],
  ['branch incorreta', { branch: 'main' }, 'branch_rejected'],
  ['stack preexistente', { preexistingStack: true }, 'preexisting_local_stack_rejected'],
  ['arquivo protegido alterado', { protectedDiff: true }, 'protected_path_modified'],
  ['ambiente remoto', { remoteEnvironment: true }, 'remote_environment_rejected'],
  ['alvo remoto', { localUrl: 'https://example.invalid' }, 'non_local_target_rejected'],
  ['porta incorreta', { localUrl: 'http://127.0.0.1:54322' }, 'non_local_target_rejected']
]) {
  test(name, () => {
    assert.throws(() => validateBackendIdentityGate({ ...valid, ...patch }), (error) => {
      assert.ok(error instanceof BackendIdentityRuntimeError)
      assert.equal(error.category, category)
      return true
    })
  })
}
