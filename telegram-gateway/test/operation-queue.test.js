import test from 'node:test';
import assert from 'node:assert/strict';
import { setTimeout as delay } from 'node:timers/promises';
import { OperationQueue } from '../src/operation-queue.js';

async function waitUntil(predicate) {
  for (let attempt = 0; attempt < 50; attempt += 1) {
    if (predicate()) return;
    await delay(5);
  }
  throw new Error('TEST_TIMEOUT');
}

test('serializa operações e não aceita operation_id duplicado', async () => {
  const active = [];
  let maxActive = 0;
  const completed = [];
  const queue = new OperationQueue({
    execute: async (operation) => {
      active.push(operation.operationId);
      maxActive = Math.max(maxActive, active.length);
      await delay(10);
      active.pop();
      return { resultText: 'resultado sintético' };
    },
    onComplete: async (operation) => completed.push(operation.operationId),
    onFailure: async () => {},
  });

  const first = queue.enqueue({
    operationId: 'CBN-CLT-TESTE-FILA-01',
    conversationId: 1,
  });
  const duplicate = queue.enqueue({
    operationId: 'CBN-CLT-TESTE-FILA-01',
    conversationId: 1,
  });
  queue.enqueue({
    operationId: 'CBN-CLT-TESTE-FILA-02',
    conversationId: 2,
  });

  await waitUntil(() => completed.length === 2);
  assert.equal(first.accepted, true);
  assert.equal(duplicate.accepted, false);
  assert.equal(maxActive, 1);
  assert.deepEqual(completed, ['CBN-CLT-TESTE-FILA-01', 'CBN-CLT-TESTE-FILA-02']);
});

test('marca revisão humana sem vazar dados no estado consultável', async () => {
  const error = new Error('falha sintética');
  error.name = 'HumanReviewError';
  error.code = 'TEST_REVIEW';
  const queue = new OperationQueue({
    execute: async () => {
      throw error;
    },
    onComplete: async () => {},
    onFailure: async () => {},
  });

  queue.enqueue({
    operationId: 'CBN-CLT-TESTE-REVISAO',
    conversationId: 9,
    cpf: 'não deve persistir',
    phone: 'não deve persistir',
  });

  await waitUntil(
    () => queue.get('CBN-CLT-TESTE-REVISAO')?.status === 'HUMAN_REVIEW'
  );
  const state = queue.get('CBN-CLT-TESTE-REVISAO');
  assert.equal(state.errorCode, 'TEST_REVIEW');
  assert.equal('cpf' in state, false);
  assert.equal('phone' in state, false);
});
