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
