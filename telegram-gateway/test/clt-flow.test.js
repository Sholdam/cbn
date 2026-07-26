import test from 'node:test';
import assert from 'node:assert/strict';
import { HumanReviewError, runCltFlow } from '../src/clt-flow.js';

class FakeAdapter {
  constructor(latest, replies) {
    this.latest = latest;
    this.replies = [...replies];
    this.sent = [];
    this.nextId = 100;
  }

  async peekLatest() {
    return { id: 1, text: this.latest };
  }

  async send(operationId, step, text) {
    this.sent.push({ operationId, step, text });
    this.nextId += 1;
    return { id: this.nextId };
  }

  async waitAfter() {
    const reply = this.replies.shift();
    if (!reply) throw new Error('TEST_NO_REPLY');
    this.nextId += 1;
    return { id: this.nextId, text: reply };
  }
}

const cpf = '12345678909';
const phone = '11900000000';

test('parte do menu CLT, envia CPF e coleta resultado até o menu terminal', async () => {
  const adapter = new FakeAdapter('📋 Menu Principal - CLT', [
    'Informe o CPF do cliente:',
    '⏳ Consultando bancos, esse processo pode levar até 5 minutos.',
    '📊 Perfil do cliente\nMargem disponível: R$ 80,00',
    '✅ Banco de teste disponível',
    'Informe outro CPF ou escolha uma opção:\n1 - Nova simulação',
  ]);

  const result = await runCltFlow({
    adapter,
    operationId: 'CBN-CLT-TESTE-0001',
    cpf,
    phone,
  });

  assert.deepEqual(
    adapter.sent.map(({ step, text }) => [step, text]),
    [
      ['navigate-0', '1'],
      ['cpf', cpf],
    ]
  );
  assert.match(result.resultText, /Margem disponível/);
  assert.match(result.resultText, /Nova simulação/);
  assert.doesNotMatch(result.resultText, /Consultando bancos/);
  assert.equal(result.phoneSent, false);
});

test('usa automaticamente o telefone normalizado quando o bot solicitar', async () => {
  const adapter = new FakeAdapter('Informe o CPF do cliente:', [
    'Qual é o seu celular com DDD? (somente números)',
    '⏳ Consultando bancos, esse processo pode levar até 5 minutos.',
    '❌ Nenhum banco disponível no momento',
    'Informe outro CPF ou escolha uma opção:',
  ]);

  const result = await runCltFlow({
    adapter,
    operationId: 'CBN-CLT-TESTE-0002',
    cpf,
    phone,
  });

  assert.equal(adapter.sent.at(-1).text, phone);
  assert.equal(result.phoneSent, true);
});

test('falha fechado se encontrar fluxo de autorização do C6', async () => {
  const adapter = new FakeAdapter(
    'Link de autorização: https://example.invalid\nCliente autorizou — simular agora',
    []
  );

  await assert.rejects(
    runCltFlow({
      adapter,
      operationId: 'CBN-CLT-TESTE-0003',
      cpf,
      phone,
    }),
    (error) =>
      error instanceof HumanReviewError && error.code === 'UNEXPECTED_C6_FLOW'
  );
  assert.equal(adapter.sent.length, 0);
});

test('não envia comando quando uma consulta anterior ainda está processando', async () => {
  const adapter = new FakeAdapter(
    '⏳ Consultando bancos, esse processo pode levar até 5 minutos.',
    []
  );

  await assert.rejects(
    runCltFlow({
      adapter,
      operationId: 'CBN-CLT-TESTE-0004',
      cpf,
      phone,
    }),
    (error) =>
      error instanceof HumanReviewError &&
      error.code === 'PREVIOUS_OPERATION_STILL_PROCESSING'
  );
  assert.equal(adapter.sent.length, 0);
});
