const repeatedDigits = /^(\d)\1{10}$/;

export function digitsOnly(value) {
  return String(value ?? '').replace(/\D/g, '');
}

export function normalizeCpf(value) {
  const cpf = digitsOnly(value);
  if (cpf.length !== 11 || repeatedDigits.test(cpf)) {
    throw new Error('CPF_INVALID');
  }

  const calculateDigit = (length) => {
    let sum = 0;
    for (let index = 0; index < length; index += 1) {
      sum += Number(cpf[index]) * (length + 1 - index);
    }
    const remainder = (sum * 10) % 11;
    return remainder === 10 ? 0 : remainder;
  };

  if (calculateDigit(9) !== Number(cpf[9]) || calculateDigit(10) !== Number(cpf[10])) {
    throw new Error('CPF_INVALID');
  }

  return cpf;
}

export function normalizeBrazilianPhone(value) {
  let phone = digitsOnly(value);
  if (phone.startsWith('55') && (phone.length === 12 || phone.length === 13)) {
    phone = phone.slice(2);
  }

  if (!/^\d{10,11}$/.test(phone)) {
    throw new Error('PHONE_INVALID');
  }

  const ddd = Number(phone.slice(0, 2));
  if (ddd < 11 || ddd > 99) {
    throw new Error('PHONE_INVALID');
  }

  return phone;
}

export function sanitizeTelegramText(text, { cpf, phone } = {}) {
  let safe = String(text ?? '');
  for (const sensitive of [cpf, phone].filter(Boolean)) {
    const digits = digitsOnly(sensitive);
    const pattern = digits
      .split('')
      .map((digit) => `${digit}`)
      .join('[^0-9]{0,3}');
    safe = safe.replace(
      new RegExp(`(?<![0-9])(?:\\(|\\[)?${pattern}(?:\\)|\\])?(?![0-9])`, 'g'),
      '[DADO_PROTEGIDO]'
    );
  }
  return safe;
}

export function validateOperationId(value) {
  const operationId = String(value ?? '').trim();
  if (!/^[A-Za-z0-9][A-Za-z0-9._:-]{7,127}$/.test(operationId)) {
    throw new Error('OPERATION_ID_INVALID');
  }
  return operationId;
}

export function validateConversationId(value) {
  const conversationId = Number(value);
  if (!Number.isSafeInteger(conversationId) || conversationId <= 0) {
    throw new Error('CONVERSATION_ID_INVALID');
  }
  return conversationId;
}
