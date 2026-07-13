import input from 'input';
import { TelegramClient } from 'telegram';
import { StringSession } from 'telegram/sessions/index.js';
import { getBaseConfig } from './config.js';

const config = getBaseConfig();
const client = new TelegramClient(
  new StringSession(config.session),
  config.apiId,
  config.apiHash,
  { connectionRetries: 5 }
);

try {
  console.log('Iniciando autorização da conta Telegram...');

  await client.start({
    phoneNumber: async () => config.phone || input.text('Telefone com DDI: '),
    password: async () => config.password || input.text('Senha 2FA (se houver): '),
    phoneCode: async () => input.text('Código recebido no Telegram: '),
    onError: (error) => console.error('Erro de autenticação:', error.message),
  });

  const me = await client.getMe();
  const savedSession = client.session.save();

  console.log(`\nConta autorizada: ${me.username ? `@${me.username}` : me.firstName || me.id}`);
  console.log('\nCOPIE A LINHA ABAIXO DIRETAMENTE PARA O SECRET TELEGRAM_SESSION:');
  console.log(savedSession);
  console.log('\nNão envie essa string por WhatsApp, Telegram, e-mail, chat, print ou planilha.');
} finally {
  await client.disconnect();
}
