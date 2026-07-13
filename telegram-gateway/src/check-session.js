import { TelegramClient } from 'telegram';
import { StringSession } from 'telegram/sessions/index.js';
import { getCheckConfig } from './config.js';

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const config = getCheckConfig();

const client = new TelegramClient(
  new StringSession(config.session),
  config.apiId,
  config.apiHash,
  { connectionRetries: 5 }
);

async function waitForIncomingReply(entity, sentMessageId) {
  const deadline = Date.now() + config.timeoutMs;

  while (Date.now() < deadline) {
    const messages = await client.getMessages(entity, { limit: 20 });
    const reply = messages.find(
      (message) => !message.out && Number(message.id) > Number(sentMessageId)
    );

    if (reply) return reply;
    await sleep(1500);
  }

  throw new Error(`Nenhuma resposta recebida em ${config.timeoutMs} ms.`);
}

try {
  await client.connect();

  const authorized = await client.checkAuthorization();
  if (!authorized) {
    throw new Error('Sessão não autorizada. Gere novamente com: npm run auth');
  }

  const me = await client.getMe();
  const entity = await client.getEntity(config.target);

  console.log(`Sessão válida para: ${me.username ? `@${me.username}` : me.firstName || me.id}`);
  console.log(`Enviando mensagem segura para: ${config.target}`);

  const sent = await client.sendMessage(entity, { message: config.message });
  const reply = await waitForIncomingReply(entity, sent.id);

  console.log('\nTESTE APROVADO');
  console.log(`Mensagem enviada: ${config.message}`);
  console.log(`Resposta recebida: ${reply.message || '[mensagem sem texto]'}`);
  console.log('\nAgora reinicie o serviço/container e execute novamente: npm run check');
  console.log('Se funcionar sem pedir novo código, a persistência da sessão foi comprovada.');
} catch (error) {
  console.error('\nTESTE REPROVADO');
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
} finally {
  await client.disconnect();
}
