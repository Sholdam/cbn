import test from 'node:test';
import assert from 'node:assert/strict';
import { deliverCallback } from '../src/callback.js';

const config = {
  callbackUrl: 'https://n8n.example.invalid/webhook/callback',
  callbackToken: 'token-sintetico-com-mais-de-32-caracteres',
  callbackMaxAttempts: 2,
  callbackTimeoutMs: 1000,
};

test('callback usa destino fixo, bearer e chave idempotente', async () => {
  const calls = [];
  await deliverCallback(
    config,
    {
      operation_id: 'CBN-CLT-CALLBACK-0001',
      visibility: 'private',
      result_text: 'resultado sintético',
    },
    async (url, options) => {
      calls.push({ url, options });
      return { ok: true, status: 200 };
    }
  );

  assert.equal(calls.length, 1);
  assert.equal(calls[0].url, config.callbackUrl);
  assert.equal(calls[0].options.headers.authorization, `Bearer ${config.callbackToken}`);
  assert.equal(
    calls[0].options.headers['idempotency-key'],
    'CBN-CLT-CALLBACK-0001'
  );
  assert.equal(JSON.parse(calls[0].options.body).visibility, 'private');
});

test('callback repete falha transitória sem alterar o operation_id', async () => {
  let attempts = 0;
  await deliverCallback(
    config,
    { operation_id: 'CBN-CLT-CALLBACK-0002' },
    async () => {
      attempts += 1;
      return { ok: attempts === 2, status: attempts === 2 ? 200 : 503 };
    }
  );
  assert.equal(attempts, 2);
});
