export const FGTS_AD_PHRASES = [
  'quero simular meu fgts',
  'quero simular minha antecipacao do fgts',
];

export const BOT_STAGES = Object.freeze({
  AWAITING_CPF: 'awaiting_cpf',
  HANDED_OFF: 'handed_off',
});

export const BOT_MESSAGES = Object.freeze({
  ASK_CPF:
    'Olá! 👋 Sou a assistente virtual da CBN Crédito.\n\n' +
    'Para verificarmos as opções disponíveis para você, envie seu CPF com os 11 números, por favor.',
  INVALID_CPF: 'CPF inválido, pode enviar novamente?',
  AUTHORIZE_FGTS:
    'CPF recebido ✅\n\n' +
    'Agora preciso que você autorize a consulta do seu FGTS.\n\n' +
    'Abra o aplicativo FGTS ou a Carteira de Trabalho Digital e autorize a instituição:\n\n' +
    'GIRO SOCIEDADE DE CRÉDITO\n\n' +
    'Quando concluir, responda PRONTO.',
});

function normalizeForMatch(value) {
  return String(value ?? '')
    .normalize('NFD')
    .replace(/\p{Diacritic}/gu, '')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();
}

export function isFgtsAdMessage(content) {
  const normalized = normalizeForMatch(content);
  return FGTS_AD_PHRASES.some((phrase) => normalized.includes(phrase));
}

export function normalizeCpf(value) {
  const raw = String(value ?? '').trim();
  if (!raw || /[a-z]/i.test(raw) || /[^\d.\-\s]/.test(raw)) return null;
  return raw.replace(/\D/g, '');
}

export function isValidCpf(value) {
  const cpf = normalizeCpf(value);
  if (!cpf || cpf.length !== 11 || /^(\d)\1{10}$/.test(cpf)) return false;

  const calculateDigit = (length) => {
    let sum = 0;
    for (let index = 0; index < length; index += 1) {
      sum += Number(cpf[index]) * (length + 1 - index);
    }
    const remainder = (sum * 10) % 11;
    return remainder === 10 ? 0 : remainder;
  };

  return calculateDigit(9) === Number(cpf[9]) &&
    calculateDigit(10) === Number(cpf[10]);
}

export function decideFgtsTriage({
  event,
  messageType,
  inboxId,
  expectedInboxId,
  content,
  stage,
  messageId,
  lastMessageId,
}) {
  if (
    event !== 'message_created' ||
    messageType !== 'incoming' ||
    String(inboxId) !== String(expectedInboxId) ||
    !messageId ||
    String(messageId) === String(lastMessageId ?? '')
  ) {
    return { action: 'ignore' };
  }

  if (!stage) {
    if (!isFgtsAdMessage(content)) {
      return { action: 'handoff', handoff: true };
    }
    return {
      action: 'reply',
      message: BOT_MESSAGES.ASK_CPF,
      nextStage: BOT_STAGES.AWAITING_CPF,
      lastMessageId: String(messageId),
      handoff: false,
    };
  }

  if (stage === BOT_STAGES.AWAITING_CPF) {
    if (!isValidCpf(content)) {
      return {
        action: 'reply',
        message: BOT_MESSAGES.INVALID_CPF,
        nextStage: BOT_STAGES.AWAITING_CPF,
        lastMessageId: String(messageId),
        handoff: false,
      };
    }

    return {
      action: 'reply',
      message: BOT_MESSAGES.AUTHORIZE_FGTS,
      nextStage: BOT_STAGES.HANDED_OFF,
      lastMessageId: String(messageId),
      handoff: true,
    };
  }

  return { action: 'handoff', handoff: true };
}
