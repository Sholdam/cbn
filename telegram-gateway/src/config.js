import 'dotenv/config';

function requireEnv(name) {
  const value = process.env[name]?.trim();
  if (!value) {
    throw new Error(`Variável obrigatória ausente: ${name}`);
  }
  return value;
}

export function getBaseConfig({ requireSession = false } = {}) {
  const apiIdRaw = requireEnv('TELEGRAM_API_ID');
  const apiId = Number(apiIdRaw);
  if (!Number.isInteger(apiId) || apiId <= 0) {
    throw new Error('TELEGRAM_API_ID deve ser um número inteiro positivo.');
  }

  const config = {
    apiId,
    apiHash: requireEnv('TELEGRAM_API_HASH'),
    phone: process.env.TELEGRAM_PHONE?.trim() || '',
    password: process.env.TELEGRAM_2FA_PASSWORD || '',
    session: process.env.TELEGRAM_SESSION?.trim() || '',
  };

  if (requireSession && !config.session) {
    throw new Error('TELEGRAM_SESSION ausente. Execute primeiro: npm run auth');
  }

  return config;
}

export function getCheckConfig() {
  const base = getBaseConfig({ requireSession: true });
  const timeoutRaw = Number(process.env.RESPONSE_TIMEOUT_MS || 30000);

  return {
    ...base,
    target: requireEnv('TARGET_USERNAME'),
    message: process.env.TEST_MESSAGE?.trim() || 'menu',
    timeoutMs: Number.isFinite(timeoutRaw) && timeoutRaw >= 5000 ? timeoutRaw : 30000,
  };
}

function positiveInteger(name, fallback, minimum = 1) {
  const value = Number(process.env[name] || fallback);
  if (!Number.isSafeInteger(value) || value < minimum) {
    throw new Error(`${name} deve ser um número inteiro maior ou igual a ${minimum}.`);
  }
  return value;
}

function requireSecret(name) {
  const value = requireEnv(name);
  if (value.length < 32) {
    throw new Error(`${name} deve possuir pelo menos 32 caracteres.`);
  }
  return value;
}

export function getGatewayConfig() {
  const base = getBaseConfig({ requireSession: true });
  const callbackUrl = new URL(requireEnv('N8N_CALLBACK_URL'));
  if (callbackUrl.protocol !== 'https:') {
    throw new Error('N8N_CALLBACK_URL deve usar HTTPS.');
  }

  return {
    ...base,
    target: requireEnv('TARGET_USERNAME'),
    port: positiveInteger('PORT', 3000),
    apiKey: requireSecret('GATEWAY_API_KEY'),
    callbackUrl: callbackUrl.toString(),
    callbackToken: requireSecret('N8N_CALLBACK_TOKEN'),
    responseTimeoutMs: positiveInteger('CLT_RESPONSE_TIMEOUT_MS', 360000, 30000),
    pollIntervalMs: positiveInteger('CLT_POLL_INTERVAL_MS', 1500, 250),
    callbackTimeoutMs: positiveInteger('CALLBACK_TIMEOUT_MS', 15000, 1000),
    callbackMaxAttempts: positiveInteger('CALLBACK_MAX_ATTEMPTS', 5, 1),
  };
}
