import { createHash } from 'node:crypto';
import { mkdir, readFile, writeFile, rm } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { TelegramClient, Api } from 'telegram';
import { StringSession } from 'telegram/sessions/index.js';
import { getCheckConfig } from './config.js';

const mode = (process.argv[2] || '').toLowerCase();
const config = getCheckConfig();
const operationId = process.env.IDEMPOTENCY_OPERATION_ID?.trim() || 'CBN-IDEMPOTENCIA-MENU-001';
const statePath = resolve('data', 'idempotency-state.json');

function randomIdFromOperationId(value) {
  const hash = createHash('sha256').update(value, 'utf8').digest();
  let randomId = hash.readBigInt64BE(0);
  if (randomId === 0n) randomId = 1n;
  return randomId;
}

async function loadState() {
  try {
    return JSON.parse(await readFile(statePath, 'utf8'));
  } catch (error) {
    if (error?.code === 'ENOENT') return null;
    throw error;
  }
}

async function saveState(state) {
  await mkdir(dirname(statePath), { recursive: true });
  await writeFile(statePath, JSON.stringify(state, null, 2), 'utf8');
}

async function getLatestMessageId(client, entity) {
  const messages = await client.getMessages(entity, { limit: 20 });
  return messages.reduce((max, message) => Math.max(max, Number(message.id) || 0), 0);
}

async function countMatchingOutgoing(client, entity, baselineMessageId) {
  const messages = await client.getMessages(entity, { limit: 50 });
  return messages.filter(
    (message) =>
      Boolean(message.out) &&
      Number(message.id) > Number(baselineMessageId) &&
      (message.message || '').trim() === config.message
  );
}

const client = new TelegramClient(
  new StringSession(config.session),
  config.apiId,
  config.apiHash,
  { connectionRetries: 5 }
);

async function phaseOne() {
  const existing = await loadState();
  if (existing) {
    throw new Error(
      `Já existe um teste salvo em ${statePath}. Rode primeiro: node src/idempotency-test.js reset`
    );
  }

  await client.connect();
  if (!(await client.checkAuthorization())) {
    throw new Error('Sessão não autorizada.');
  }

  const entity = await client.getInputEntity(config.target);
  const baselineMessageId = await getLatestMessageId(client, entity);
  const randomId = randomIdFromOperationId(operationId);

  await saveState({
    operationId,
    randomId: randomId.toString(),
    baselineMessageId,
    message: config.message,
    target: config.target,
    phase: 'PREPARED_BEFORE_SEND',
    createdAt: new Date().toISOString()
  });

  await client.invoke(
    new Api.messages.SendMessage({
      peer: entity,
      message: config.message,
      randomId,
      noWebpage: true
    })
  );

  console.log('\nFASE 1 APROVADA');
  console.log(`Operation ID: ${operationId}`);
  console.log(`Mensagem enviada uma vez: ${config.message}`);
  console.log('O programa não salvou o ID retornado pelo Telegram, simulando uma queda logo após o envio.');
  console.log('\nAgora feche esta janela do PowerShell, abra outra e rode:');
  console.log('node src/idempotency-test.js retry');
}

async function retryPhase() {
  const state = await loadState();
  if (!state) {
    throw new Error('Nenhum teste preparado. Rode primeiro: node src/idempotency-test.js first');
  }

  if (state.operationId !== operationId) {
    throw new Error('O operation_id atual é diferente do teste salvo.');
  }

  await client.connect();
  if (!(await client.checkAuthorization())) {
    throw new Error('Sessão não autorizada.');
  }

  const entity = await client.getInputEntity(config.target);
  const randomId = BigInt(state.randomId);
  let telegramBlockedDuplicate = false;

  try {
    await client.invoke(
      new Api.messages.SendMessage({
        peer: entity,
        message: state.message,
        randomId,
        noWebpage: true
      })
    );
  } catch (error) {
    const text = `${error?.errorMessage || ''} ${error?.message || ''}`;
    if (/RANDOM_ID_DUPLICATE/i.test(text)) {
      telegramBlockedDuplicate = true;
    } else {
      throw error;
    }
  }

  await new Promise((resolvePromise) => setTimeout(resolvePromise, 2500));
  const matching = await countMatchingOutgoing(client, entity, state.baselineMessageId);

  if (matching.length !== 1) {
    await saveState({
      ...state,
      phase: 'FAILED',
      checkedAt: new Date().toISOString(),
      matchingOutgoingMessages: matching.map((message) => Number(message.id)),
      telegramBlockedDuplicate
    });
    throw new Error(
      `TESTE REPROVADO: foram encontradas ${matching.length} mensagens "${state.message}" após o início. O esperado era exatamente 1.`
    );
  }

  await saveState({
    ...state,
    phase: 'IDEMPOTENCY_CONFIRMED',
    checkedAt: new Date().toISOString(),
    telegramMessageId: Number(matching[0].id),
    telegramBlockedDuplicate
  });

  console.log('\nTESTE DE IDEMPOTÊNCIA APROVADO');
  console.log(`Operation ID reutilizado: ${state.operationId}`);
  console.log('Mensagens realmente enviadas ao bot: 1');
  console.log(
    telegramBlockedDuplicate
      ? 'O Telegram bloqueou o reenvio pelo mesmo random_id.'
      : 'O histórico confirmou que não apareceu uma segunda mensagem.'
  );
  console.log('Resultado: um retry com o mesmo operation_id não duplicou o comando.');
}

async function resetTest() {
  await rm(statePath, { force: true });
  console.log(`Teste apagado: ${statePath}`);
}

try {
  if (mode === 'first') {
    await phaseOne();
  } else if (mode === 'retry') {
    await retryPhase();
  } else if (mode === 'reset') {
    await resetTest();
  } else {
    console.log('Uso:');
    console.log('  node src/idempotency-test.js first');
    console.log('  node src/idempotency-test.js retry');
    console.log('  node src/idempotency-test.js reset');
    process.exitCode = 1;
  }
} catch (error) {
  console.error('\nERRO');
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
} finally {
  try {
    await client.disconnect();
  } catch {
    // Ignora quando o cliente não chegou a conectar.
  }
}
