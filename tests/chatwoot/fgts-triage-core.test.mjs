import assert from 'node:assert/strict';
import test from 'node:test';

import {
  BOT_MESSAGES,
  BOT_STAGES,
  decideFgtsTriage,
  isFgtsAdMessage,
  isValidCpf,
  normalizeCpf,
} from '../../scripts/chatwoot/fgts-triage-core.mjs';

const baseEvent = {
  event: 'message_created',
  messageType: 'incoming',
  inboxId: 2,
  expectedInboxId: 2,
  messageId: 101,
};

function makeSyntheticCpf(firstNineDigits = '246813579') {
  const calculateDigit = (value, length) => {
    let sum = 0;
    for (let index = 0; index < length; index += 1) {
      sum += Number(value[index]) * (length + 1 - index);
    }
    const remainder = (sum * 10) % 11;
    return remainder === 10 ? 0 : remainder;
  };

  const withFirstDigit = `${firstNineDigits}${calculateDigit(firstNineDigits, 9)}`;
  return `${withFirstDigit}${calculateDigit(withFirstDigit, 10)}`;
}

const syntheticCpf = makeSyntheticCpf();
const formattedSyntheticCpf =
  `${syntheticCpf.slice(0, 3)}.${syntheticCpf.slice(3, 6)}.` +
  `${syntheticCpf.slice(6, 9)}-${syntheticCpf.slice(9)}`;

test('reconhece as duas frases aprovadas de anúncio FGTS', () => {
  assert.equal(isFgtsAdMessage('Olá! Vim pelo anúncio e quero simular meu FGTS.'), true);
  assert.equal(
    isFgtsAdMessage(
      'Olá! Vim pelo anúncio e quero simular minha antecipação do FGTS.',
    ),
    true,
  );
  assert.equal(isFgtsAdMessage('Quero simular meu Crédito CLT.'), false);
});

test('normaliza pontuação, mas recusa letras e símbolos inesperados', () => {
  assert.equal(normalizeCpf(formattedSyntheticCpf), syntheticCpf);
  assert.equal(normalizeCpf(syntheticCpf.split('').join(' ')), syntheticCpf);
  assert.equal(normalizeCpf(`CPF ${syntheticCpf}`), null);
  assert.equal(normalizeCpf(`${syntheticCpf}@`), null);
});

test('valida dígitos verificadores e rejeita sequências repetidas', () => {
  assert.equal(isValidCpf(formattedSyntheticCpf), true);
  assert.equal(isValidCpf('1'.repeat(11)), false);
  assert.equal(isValidCpf('0'.repeat(11)), false);
  assert.equal(
    isValidCpf(`${syntheticCpf.slice(0, -1)}${syntheticCpf.endsWith('9') ? '8' : '9'}`),
    false,
  );
  assert.equal(isValidCpf('123'), false);
});

test('primeiro contato FGTS pede o CPF e registra somente estado técnico', () => {
  const result = decideFgtsTriage({
    ...baseEvent,
    content: 'Olá! Vim pelo anúncio e quero simular meu FGTS.',
  });

  assert.deepEqual(result, {
    action: 'reply',
    message: BOT_MESSAGES.ASK_CPF,
    nextStage: BOT_STAGES.AWAITING_CPF,
    lastMessageId: '101',
    handoff: false,
  });
  assert.equal(JSON.stringify(result).includes(syntheticCpf), false);
});

test('CPF inválido solicita nova tentativa sem avançar', () => {
  const result = decideFgtsTriage({
    ...baseEvent,
    content: '00000000000',
    stage: BOT_STAGES.AWAITING_CPF,
  });

  assert.equal(result.message, 'CPF inválido, pode enviar novamente?');
  assert.equal(result.nextStage, BOT_STAGES.AWAITING_CPF);
  assert.equal(result.handoff, false);
});

test('CPF válido envia autorização FGTS, não menciona CLT e libera o humano', () => {
  const result = decideFgtsTriage({
    ...baseEvent,
    content: formattedSyntheticCpf,
    stage: BOT_STAGES.AWAITING_CPF,
  });

  assert.equal(result.nextStage, BOT_STAGES.HANDED_OFF);
  assert.equal(result.handoff, true);
  assert.match(result.message, /GIRO SOCIEDADE DE CRÉDITO/);
  assert.doesNotMatch(result.message, /CLT|Crédito do Trabalhador/i);
  assert.equal(JSON.stringify(result).includes(syntheticCpf), false);
});

test('ignora saída, outra caixa e duplicata', () => {
  const cases = [
    { ...baseEvent, messageType: 'outgoing', content: 'quero simular meu fgts' },
    { ...baseEvent, inboxId: 9, content: 'quero simular meu fgts' },
    {
      ...baseEvent,
      content: 'quero simular meu fgts',
      lastMessageId: '101',
    },
  ];

  for (const input of cases) {
    assert.deepEqual(decideFgtsTriage(input), { action: 'ignore' });
  }
});

test('entrega outro produto ou conversa pós-handoff ao atendimento humano sem responder', () => {
  const cases = [
    { ...baseEvent, content: 'quero simular meu crédito clt' },
    {
      ...baseEvent,
      content: 'qualquer mensagem',
      stage: BOT_STAGES.HANDED_OFF,
    },
  ];

  for (const input of cases) {
    assert.deepEqual(decideFgtsTriage(input), {
      action: 'handoff',
      handoff: true,
    });
  }
});
