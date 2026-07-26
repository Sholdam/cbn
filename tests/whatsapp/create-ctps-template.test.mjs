import assert from 'node:assert/strict';
import test from 'node:test';
import {
  DEFAULT_IMAGE_PATH,
  TEMPLATE_BODY,
  TEMPLATE_BUTTONS,
  TEMPLATE_CATEGORY,
  TEMPLATE_FOOTER,
  TEMPLATE_LANGUAGE,
  TEMPLATE_NAME,
  buildTemplatePayload,
  compareTemplate,
  createCtpsTemplate,
  validateHeaderImage,
  validateTemplateCopy,
  validateTemplateLanguage,
  validateTemplateName,
} from '../../scripts/whatsapp/create-ctps-template.mjs';
import { checkTemplateStatus } from '../../scripts/whatsapp/check-template-status.mjs';
import {
  BRAZIL_MARKETING_RATE_USD,
  estimateCtpsTemplateCost,
} from '../../scripts/whatsapp/estimate-ctps-template-cost.mjs';
import { createMetaWhatsappClient } from '../../scripts/whatsapp/lib/meta-whatsapp-client.mjs';

function clone(value) {
  return structuredClone(value);
}

function fakeClient({ templates = [], status = 'PENDING' } = {}) {
  const calls = [];
  return {
    calls,
    async listMessageTemplates() {
      calls.push(['listMessageTemplates']);
      return templates;
    },
    async startResumableUpload(image) {
      calls.push(['startResumableUpload', image.fileName, image.fileLength, image.fileType]);
      return { id: 'upload:synthetic-session' };
    },
    async uploadFileBytes(sessionId, bytes) {
      calls.push(['uploadFileBytes', sessionId, bytes.length]);
      return { h: 'synthetic-header-handle' };
    },
    async createMessageTemplate(payload) {
      calls.push(['createMessageTemplate', payload]);
      return { id: 'synthetic-template-id', status };
    },
  };
}

test('valida o nome técnico oficial', () => {
  assert.equal(validateTemplateName(TEMPLATE_NAME), TEMPLATE_NAME);
  assert.throws(() => validateTemplateName('CBN CTPS'), /Nome técnico inválido/);
  assert.throws(() => validateTemplateName('cbn-ctps'), /Nome técnico inválido/);
});

test('valida exclusivamente o idioma pt_BR', () => {
  assert.equal(validateTemplateLanguage(TEMPLATE_LANGUAGE), 'pt_BR');
  assert.throws(() => validateTemplateLanguage('pt'), /pt_BR/);
});

test('payload usa categoria MARKETING e cabeçalho IMAGE', () => {
  const payload = buildTemplatePayload('synthetic-handle');
  assert.equal(payload.category, TEMPLATE_CATEGORY);
  assert.deepEqual(payload.components[0], {
    type: 'HEADER',
    format: 'IMAGE',
    example: { header_handle: ['synthetic-handle'] },
  });
});

test('corpo, variável de exemplo e rodapé são exatos', () => {
  const payload = buildTemplatePayload();
  const body = payload.components.find(({ type }) => type === 'BODY');
  const footer = payload.components.find(({ type }) => type === 'FOOTER');
  assert.equal(body.text, TEMPLATE_BODY);
  assert.deepEqual(body.example, { body_text: [['Maria']] });
  assert.equal(footer.text, TEMPLATE_FOOTER);
});

test('payload contém três botões de resposta rápida na ordem definida', () => {
  const buttons = buildTemplatePayload().components.find(
    ({ type }) => type === 'BUTTONS',
  ).buttons;
  assert.deepEqual(
    buttons,
    TEMPLATE_BUTTONS.map((text) => ({ type: 'QUICK_REPLY', text })),
  );
});

test('texto não contém promessa, CPF, valor, taxa ou FGTS', () => {
  assert.equal(validateTemplateCopy(buildTemplatePayload()), true);
  assert.doesNotMatch(TEMPLATE_BODY, /aprovad|CPF|FGTS|R\$|\d+[,.]\d{2}\s*%/i);
});

test('validador rejeita promessa e CPF introduzidos no corpo', () => {
  for (const forbidden of ['Crédito aprovado', 'Informe seu CPF']) {
    const payload = buildTemplatePayload();
    payload.components.find(({ type }) => type === 'BODY').text += `\n${forbidden}`;
    assert.throws(() => validateTemplateCopy(payload), /Modelo inválido/);
  }
});

test('falha claramente quando a imagem está ausente', async () => {
  await assert.rejects(
    validateHeaderImage('Z:\\fixture-sintetica-inexistente.png'),
    /Imagem de cabeçalho não encontrada/,
  );
});

test('PNG final possui 800x418 e fica abaixo de 300 KB', async () => {
  const image = await validateHeaderImage(DEFAULT_IMAGE_PATH);
  assert.equal(image.width, 800);
  assert.equal(image.height, 418);
  assert.equal(image.fileType, 'image/png');
  assert.equal(image.optimized, true);
});

test('upload e criação simulados submetem o modelo sem enviar mensagem', async () => {
  const client = fakeClient();
  const result = await createCtpsTemplate({ client });
  assert.equal(result.outcome, 'TEMPLATE_SUBMITTED');
  assert.deepEqual(
    client.calls.map(([name]) => name),
    [
      'listMessageTemplates',
      'startResumableUpload',
      'uploadFileBytes',
      'createMessageTemplate',
    ],
  );
  assert.ok(client.calls.every(([name]) => name !== 'sendMessage'));
});

test('execução repetida retorna no-op para modelo PENDING correto', async () => {
  const expected = buildTemplatePayload('existing-handle');
  const client = fakeClient({
    templates: [{ ...expected, id: '1', status: 'PENDING' }],
  });
  const result = await createCtpsTemplate({ client });
  assert.equal(result.outcome, 'NO_OP_TEMPLATE_ALREADY_EXISTS');
  assert.deepEqual(client.calls, [['listMessageTemplates']]);
});

test('execução repetida retorna no-op para modelo APPROVED correto', async () => {
  const expected = buildTemplatePayload('existing-handle');
  const client = fakeClient({
    templates: [{ ...expected, id: '1', status: 'APPROVED' }],
  });
  const result = await createCtpsTemplate({ client });
  assert.equal(result.status, 'APPROVED');
  assert.deepEqual(client.calls, [['listMessageTemplates']]);
});

test('modelo rejeitado não é apagado e exige nova versão', async () => {
  const expected = buildTemplatePayload('existing-handle');
  const client = fakeClient({
    templates: [{ ...expected, id: '1', status: 'REJECTED' }],
  });
  await assert.rejects(createCtpsTemplate({ client }), /TEMPLATE_REJECTED.*_v2/);
  assert.deepEqual(client.calls, [['listMessageTemplates']]);
});

test('modelo divergente informa diff e exige nova versão', async () => {
  const existing = buildTemplatePayload('existing-handle');
  existing.category = 'UTILITY';
  const client = fakeClient({
    templates: [{ ...existing, id: '1', status: 'PENDING' }],
  });
  await assert.rejects(
    createCtpsTemplate({ client }),
    /TEMPLATE_DIVERGENT: category.*novo nome versionado/,
  );
});

test('comparação ignora somente o handle efêmero do cabeçalho', () => {
  const existing = buildTemplatePayload('handle-a');
  delete existing.components.find(({ type }) => type === 'BODY').example;
  const expected = buildTemplatePayload('handle-b');
  assert.deepEqual(compareTemplate(existing, expected), []);
  existing.components.find(({ type }) => type === 'BODY').text += ' divergente';
  assert.deepEqual(compareTemplate(existing, expected), ['components']);
});

test('falha clara sem variáveis obrigatórias e não imprime token', () => {
  assert.throws(
    () =>
      createMetaWhatsappClient({
        graphVersion: 'v23.0',
        appId: '',
        wabaId: '',
        accessToken: '',
      }),
    /META_APP_ID/,
  );
});

test('erro HTTP não reproduz token ou corpo da Meta', async () => {
  const token = 'synthetic-secret-token-that-must-not-leak';
  const client = createMetaWhatsappClient({
    graphVersion: 'v23.0',
    appId: 'synthetic-app',
    wabaId: 'synthetic-waba',
    accessToken: token,
    fetchImpl: async () =>
      new Response(JSON.stringify({ error: { message: token } }), { status: 401 }),
  });
  await assert.rejects(client.listMessageTemplates(), (error) => {
    assert.match(error.message, /HTTP 401/);
    assert.doesNotMatch(error.message, new RegExp(token));
    return true;
  });
});

test('cliente usa somente endpoints de templates e upload no fluxo preparado', async () => {
  const urls = [];
  const client = createMetaWhatsappClient({
    graphVersion: 'v23.0',
    appId: 'synthetic-app',
    wabaId: 'synthetic-waba',
    accessToken: 'synthetic-token',
    fetchImpl: async (url, options) => {
      urls.push({ url: String(url), method: options.method });
      if (String(url).includes('/message_templates') && options.method === 'GET') {
        return new Response(JSON.stringify({ data: [] }), { status: 200 });
      }
      if (String(url).includes('/uploads')) {
        return new Response(JSON.stringify({ id: 'upload:synthetic' }), { status: 200 });
      }
      if (String(url).includes('/upload:synthetic')) {
        return new Response(JSON.stringify({ h: 'synthetic-handle' }), { status: 200 });
      }
      return new Response(
        JSON.stringify({ id: 'synthetic-template', status: 'PENDING' }),
        { status: 200 },
      );
    },
  });
  await createCtpsTemplate({ client });
  assert.ok(urls.some(({ url }) => url.includes('/message_templates')));
  assert.ok(urls.some(({ url }) => url.includes('/uploads')));
  assert.ok(urls.every(({ url }) => !/\/messages(?:\?|$)/.test(url)));
});

test('consulta de status retorna rejeição e qualidade quando disponíveis', async () => {
  const client = fakeClient({
    templates: [
      {
        name: TEMPLATE_NAME,
        language: TEMPLATE_LANGUAGE,
        category: 'MARKETING',
        status: 'REJECTED',
        rejected_reason: 'SYNTHETIC_REASON',
        quality_score: { score: 'GREEN' },
      },
    ],
  });
  const result = await checkTemplateStatus({
    client,
    now: () => new Date('2026-07-26T12:00:00.000Z'),
  });
  assert.equal(result.status, 'REJECTED');
  assert.equal(result.rejectedReason, 'SYNTHETIC_REASON');
  assert.deepEqual(result.quality, { score: 'GREEN' });
  assert.equal(result.checkedAt, '2026-07-26T12:00:00.000Z');
});

test('consulta de status informa NOT_FOUND sem criar ou apagar modelo', async () => {
  const client = fakeClient();
  const result = await checkTemplateStatus({ client });
  assert.equal(result.status, 'NOT_FOUND');
  assert.deepEqual(client.calls, [['listMessageTemplates']]);
});

test('custo de marketing usa US$ 0,0625 por mensagem entregue no Brasil', () => {
  const one = estimateCtpsTemplateCost({ deliveredMessages: 1, usdBrl: 5.0666 });
  assert.equal(one.rateUsdPerDeliveredMessage, BRAZIL_MARKETING_RATE_USD);
  assert.equal(one.estimatedUsd, 0.0625);
  assert.equal(one.estimatedBrl, 0.32);

  const thousand = estimateCtpsTemplateCost({
    deliveredMessages: 1000,
    usdBrl: 5.0666,
  });
  assert.equal(thousand.estimatedUsd, 62.5);
  assert.equal(thousand.estimatedBrl, 316.66);
});

test('estimador rejeita quantidade ou câmbio inválidos', () => {
  assert.throws(
    () => estimateCtpsTemplateCost({ deliveredMessages: -1 }),
    /não negativo/,
  );
  assert.throws(
    () => estimateCtpsTemplateCost({ deliveredMessages: 1, usdBrl: 'inválido' }),
    /não negativo/,
  );
});
