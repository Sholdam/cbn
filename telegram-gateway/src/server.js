import { createServer } from 'node:http';
import { timingSafeEqual } from 'node:crypto';
import { getGatewayConfig } from './config.js';
import { TelegramAdapter } from './telegram-adapter.js';
import { runCltFlow } from './clt-flow.js';
import { deliverCallback } from './callback.js';
import { OperationQueue } from './operation-queue.js';
import {
  normalizeBrazilianPhone,
  normalizeCpf,
  validateConversationId,
  validateOperationId,
} from './validation.js';

const config = getGatewayConfig();
const adapter = new TelegramAdapter(config);

function safeEqual(left, right) {
  const leftBuffer = Buffer.from(String(left ?? ''));
  const rightBuffer = Buffer.from(String(right ?? ''));
  return leftBuffer.length === rightBuffer.length && timingSafeEqual(leftBuffer, rightBuffer);
}

function authorized(request) {
  return safeEqual(request.headers['x-gateway-key'], config.apiKey);
}

function json(response, status, body) {
  response.writeHead(status, { 'content-type': 'application/json; charset=utf-8' });
  response.end(JSON.stringify(body));
}

async function readJson(request) {
  const chunks = [];
  let size = 0;
  for await (const chunk of request) {
    size += chunk.length;
    if (size > 16_384) throw new Error('BODY_TOO_LARGE');
    chunks.push(chunk);
  }
  return JSON.parse(Buffer.concat(chunks).toString('utf8'));
}

const queue = new OperationQueue({
  execute: (operation) =>
    runCltFlow({
      adapter,
      operationId: operation.operationId,
      cpf: operation.cpf,
      phone: operation.phone,
    }),
  onComplete: (operation, result) =>
    deliverCallback(config, {
      operation_id: operation.operationId,
      conversation_id: operation.conversationId,
      product: 'CLT',
      status: 'COMPLETED',
      visibility: 'private',
      result_text: result.resultText,
      phone_requested: result.phoneSent,
    }),
  onFailure: (operation, error) =>
    deliverCallback(config, {
      operation_id: operation.operationId,
      conversation_id: operation.conversationId,
      product: 'CLT',
      status: error?.name === 'HumanReviewError' ? 'HUMAN_REVIEW' : 'FAILED_FINAL',
      visibility: 'private',
      error_code: error?.code || error?.message || 'UNKNOWN_ERROR',
      result_text:
        'A consulta CLT não foi concluída automaticamente. Encaminhar para revisão humana.',
    }),
});

const server = createServer(async (request, response) => {
  const url = new URL(request.url || '/', 'http://gateway.internal');

  if (request.method === 'GET' && url.pathname === '/health') {
    return json(response, 200, { status: 'ok', ...queue.health });
  }

  if (!authorized(request)) {
    return json(response, 401, { error: 'UNAUTHORIZED' });
  }

  if (request.method === 'POST' && url.pathname === '/v1/clt/simulations') {
    try {
      const body = await readJson(request);
      const operation = {
        operationId: validateOperationId(body.operation_id),
        conversationId: validateConversationId(body.conversation_id),
        cpf: normalizeCpf(body.cpf),
        phone: normalizeBrazilianPhone(body.phone),
      };
      const result = queue.enqueue(operation);
      return json(response, result.accepted ? 202 : 200, {
        operation_id: operation.operationId,
        accepted: result.accepted,
        status: result.status,
      });
    } catch (error) {
      return json(response, 400, { error: error?.message || 'INVALID_REQUEST' });
    }
  }

  const operationMatch = url.pathname.match(/^\/v1\/operations\/([^/]+)$/);
  if (request.method === 'GET' && operationMatch) {
    try {
      const operationId = validateOperationId(decodeURIComponent(operationMatch[1]));
      const operation = queue.get(operationId);
      return operation
        ? json(response, 200, { operation_id: operationId, ...operation })
        : json(response, 404, { error: 'OPERATION_NOT_FOUND' });
    } catch (error) {
      return json(response, 400, { error: error?.message || 'INVALID_REQUEST' });
    }
  }

  return json(response, 404, { error: 'NOT_FOUND' });
});

async function shutdown(signal) {
  console.log(`Gateway encerrando por ${signal}.`);
  server.close();
  try {
    await adapter.disconnect();
  } finally {
    process.exit(0);
  }
}

process.once('SIGTERM', () => void shutdown('SIGTERM'));
process.once('SIGINT', () => void shutdown('SIGINT'));

try {
  await adapter.connect();
  server.listen(config.port, '0.0.0.0', () => {
    console.log(`Gateway CLT iniciado na porta ${config.port}.`);
  });
} catch (error) {
  console.error(`Falha ao iniciar Gateway CLT: ${error?.message || 'UNKNOWN_ERROR'}`);
  process.exitCode = 1;
  await adapter.disconnect().catch(() => {});
}
