import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const directory = path.dirname(fileURLToPath(import.meta.url));
const workflowPath = path.join(directory, 'CBN_META_03_PUBLICADOR_META_V2_PRODUCAO.json');
const workflowText = fs.readFileSync(workflowPath, 'utf8');
const workflow = JSON.parse(workflowText);
const node = (name) => workflow.nodes.find((candidate) => candidate.name === name);
const tests = [];
const test = (name, callback) => tests.push({ name, callback });

const executeCode = async (nodeName, globals) => {
  const jsCode = node(nodeName)?.parameters?.jsCode;
  assert.ok(jsCode, `Code node ausente: ${nodeName}`);
  const context = vm.createContext({
    console,
    Date,
    Intl,
    JSON,
    Map,
    Set,
    String,
    Number,
    Boolean,
    Object,
    Array,
    RegExp,
    ...globals,
  });
  return vm.runInContext(`(async () => { ${jsCode}\n })()`, context, { timeout: 1000 });
};

const config = {
  META_GRAPH_VERSION: 'v26.0',
  IG_USER_ID: '100',
  FB_PAGE_ID: '200',
  MAX_ATTEMPTS_CANAL: 3,
  RETRY_1_MINUTES: 10,
  RETRY_2_MINUTES: 30,
  TIMEZONE: 'America/Sao_Paulo',
  WORKFLOW: workflow.name,
  MAX_POSTS_PER_EXECUTION: 1,
};

const baseRow = (overrides = {}) => ({
  post_id: 'synthetic-post-001',
  Data: '01/01/2020',
  Horário: '09:00',
  Formato: 'Post estático',
  'Legenda / roteiro-base': 'Conteúdo sintético aprovado.',
  'Arquivo / URL da mídia': 'https://example.com/synthetic.png',
  Instagram: 'SIM',
  Facebook: 'SIM',
  Aprovação: 'Aprovado',
  Status: 'APROVADO_PUBLICAR',
  publish_key: 'synthetic-key-001',
  instagram_status: 'PENDENTE',
  facebook_status: 'PENDENTE',
  instagram_attempts: '0',
  facebook_attempts: '0',
  row_version: '0',
  ...overrides,
});

const select = (row, logs = []) => executeCode('Selecionar 1 post estático seguro1', {
  $items: () => [{ json: row }],
  $input: { all: () => logs.map((json) => ({ json })) },
  $: () => ({ first: () => ({ json: config }) }),
});

const consolidate = (post, logs) => executeCode('Consolidar resultado final1', {
  $execution: { id: 'exec-synthetic' },
  $input: { all: () => logs.map((json) => ({ json })) },
  $: () => ({ first: () => ({ json: post }) }),
});

const finalLog = (channel, status, overrides = {}) => ({
  Execução: 'exec-synthetic',
  'Post ID': 'synthetic-post-001',
  'Publish Key': 'synthetic-key-001',
  Canal: channel,
  Status: status,
  'Media ID': status === 'PUBLICADO' ? `id-${channel}` : '',
  URL: status === 'PUBLICADO' ? `https://example.com/${channel}` : '',
  Erro: status === 'ERRO' ? `erro-${channel}` : '',
});

test('1. Instagram e Facebook pendentes selecionam os dois canais', async () => {
  const result = await select(baseRow());
  assert.deepEqual(Array.from(result[0].json.channels), ['instagram', 'facebook']);
});

test('2. Instagram publicado seleciona somente Facebook', async () => {
  const result = await select(baseRow({ instagram_status: 'PUBLICADO', 'ID Instagram': 'ig-existing' }));
  assert.deepEqual(Array.from(result[0].json.channels), ['facebook']);
});

test('3. Facebook publicado seleciona somente Instagram', async () => {
  const result = await select(baseRow({ facebook_status: 'PUBLICADO', 'ID Facebook': 'fb-existing' }));
  assert.deepEqual(Array.from(result[0].json.channels), ['instagram']);
});

test('4. sucesso Instagram e erro Facebook resulta PARCIAL e retry só Facebook', async () => {
  const post = { ...baseRow(), channels: ['instagram', 'facebook'], attempts_by_channel: { instagram: 1, facebook: 1 }, max_attempts_channel: 3, retry_1_minutes: 10, retry_2_minutes: 30, row_version_before: 0 };
  const result = (await consolidate(post, [finalLog('instagram', 'PUBLICADO'), finalLog('facebook', 'ERRO')]))[0].json;
  assert.equal(result.Status, 'PARCIAL');
  assert.equal(result.instagram_next_retry_at, '');
  assert.ok(result.facebook_next_retry_at);
});

test('5. erro Instagram e sucesso Facebook resulta PARCIAL e retry só Instagram', async () => {
  const post = { ...baseRow(), channels: ['instagram', 'facebook'], attempts_by_channel: { instagram: 1, facebook: 1 }, max_attempts_channel: 3, retry_1_minutes: 10, retry_2_minutes: 30, row_version_before: 0 };
  const result = (await consolidate(post, [finalLog('instagram', 'ERRO'), finalLog('facebook', 'PUBLICADO')]))[0].json;
  assert.equal(result.Status, 'PARCIAL');
  assert.ok(result.instagram_next_retry_at);
  assert.equal(result.facebook_next_retry_at, '');
});

test('6. erro em ambos resulta ERRO', async () => {
  const post = { ...baseRow(), channels: ['instagram', 'facebook'], attempts_by_channel: { instagram: 1, facebook: 1 }, max_attempts_channel: 3, retry_1_minutes: 10, retry_2_minutes: 30, row_version_before: 0 };
  const result = (await consolidate(post, [finalLog('instagram', 'ERRO'), finalLog('facebook', 'ERRO')]))[0].json;
  assert.equal(result.Status, 'ERRO');
});

test('7. ambos publicados resultam em zero canais', async () => {
  const result = await select(baseRow({ instagram_status: 'PUBLICADO', facebook_status: 'PUBLICADO' }));
  assert.equal(result.length, 0);
});

test('8. data e horário futuros não são selecionados', async () => {
  const result = await select(baseRow({ Data: '01/01/2099' }));
  assert.equal(result.length, 0);
});

test('9. PAUSA_GERAL SIM segue somente para encerramento seguro', () => {
  const pauseIf = node('PAUSA_GERAL permite publicar?');
  assert.ok(pauseIf);
  const outputs = workflow.connections[pauseIf.name].main;
  assert.equal(outputs[1][0].node, 'Fim seguro — PAUSA_GERAL ativa');
  assert.equal(outputs[0][0].node, 'Validar configuracao e pausa antes da Meta');
});

test('10. configuração crítica ausente falha fechada', async () => {
  await assert.rejects(() => executeCode('Validar configuração fail-closed', {
    $input: { all: () => [{ json: { Chave: 'PAUSA_GERAL', Valor: 'NAO' } }] },
    $: () => ({ first: () => ({ json: {} }) }),
  }), /FAIL_CLOSED/);
});

test('11. último log ERRO permite retry quando o backoff venceu', async () => {
  const result = await select(baseRow({ instagram_attempts: '1', facebook_status: 'PUBLICADO' }), [
    { 'Publish Key': 'synthetic-key-001', Canal: 'INSTAGRAM', Status: 'RESERVADO' },
    { 'Publish Key': 'synthetic-key-001', Canal: 'INSTAGRAM', Status: 'ERRO' },
  ]);
  assert.deepEqual(Array.from(result[0].json.channels), ['instagram']);
});

test('12. último log PUBLICADO proíbe retry', async () => {
  const result = await select(baseRow({ Facebook: 'NAO' }), [
    { 'Publish Key': 'synthetic-key-001', Canal: 'INSTAGRAM', Status: 'ERRO' },
    { 'Publish Key': 'synthetic-key-001', Canal: 'INSTAGRAM', Status: 'PUBLICADO' },
  ]);
  assert.equal(result.length, 0);
});

test('13. último log RESERVADO bloqueia replay automático', async () => {
  const result = await select(baseRow({ Facebook: 'NAO' }), [
    { 'Publish Key': 'synthetic-key-001', Canal: 'INSTAGRAM', Status: 'RESERVADO' },
  ]);
  assert.equal(result.length, 0);
});

test('14. Facebook usa message e não caption', () => {
  const facebook = node('Facebook — publicar foto1');
  const body = facebook.parameters.bodyParameters.parameters;
  assert.ok(body.some((field) => field.name === 'message'));
  assert.ok(!body.some((field) => field.name === 'caption'));
});

test('15. Instagram usa graph.facebook.com e expressão sem ==', () => {
  for (const name of ['Instagram — criar contêiner1', 'Instagram — publicar contêiner1']) {
    const url = node(name).parameters.url;
    assert.match(url, /graph\.facebook\.com/);
    assert.ok(url.startsWith('={{'));
    assert.ok(!url.startsWith('=={{'));
  }
});

test('16. APPEND não contém expressão literal quebrada', () => {
  for (const candidate of workflow.nodes.filter((item) => item.type === 'n8n-nodes-base.googleSheets' && item.parameters.operation === 'append')) {
    const text = JSON.stringify(candidate.parameters);
    assert.ok(!/"\{ \$json\[/.test(text));
    assert.ok(!/"\{\{/.test(text));
  }
});

test('17. todas as conexões apontam para nós existentes', () => {
  const names = new Set(workflow.nodes.map((item) => item.name));
  for (const [source, groups] of Object.entries(workflow.connections)) {
    assert.ok(names.has(source), `origem inexistente: ${source}`);
    for (const group of groups.main) for (const edge of group) assert.ok(names.has(edge.node), `destino inexistente: ${edge.node}`);
  }
});

test('18. workflow está inativo, com Manual, Schedule de 1 minuto e timezone correto', () => {
  assert.equal(workflow.active, false);
  assert.ok(node('Gatilho manual — teste controlado'));
  assert.equal(node('Agendamento — a cada 1 minuto').parameters.rule.interval[0].minutesInterval, 1);
  assert.equal(workflow.settings.timezone, 'America/Sao_Paulo');
});

test('19. chamadas Meta mantêm retry técnico 2 e normalização de erro', () => {
  for (const name of ['Instagram — criar contêiner1', 'Instagram — publicar contêiner1', 'Facebook — publicar foto1']) {
    const request = node(name);
    assert.equal(request.retryOnFail, true);
    assert.equal(request.maxTries, 2);
    assert.equal(request.onError, 'continueRegularOutput');
  }
});

test('20. schema V2 grava tentativas, erros e retries por canal', () => {
  const values = node('Atualizar resultado no calendário1').parameters.columns.value;
  for (const field of ['instagram_attempts', 'facebook_attempts', 'instagram_last_error_json', 'facebook_last_error_json', 'instagram_next_retry_at', 'facebook_next_retry_at']) assert.ok(field in values);
});

test('21. JSON não contém token Meta, segredo ou Header Auth materializado', () => {
  assert.ok(!/EA[A-Za-z0-9]{40,}/.test(workflowText));
  assert.ok(!/Bearer\s+[A-Za-z0-9._-]{20,}/i.test(workflowText));
  assert.ok(!/access_token\s*[=:]/i.test(workflowText));
});

test('22. todos os Code nodes possuem JavaScript sintaticamente válido', () => {
  for (const candidate of workflow.nodes.filter((item) => item.type === 'n8n-nodes-base.code')) {
    assert.doesNotThrow(
      () => new vm.Script(`(async () => { ${candidate.parameters.jsCode}\n })()`),
      `JavaScript inválido em ${candidate.name}`,
    );
  }
});

test('23. nomes de nós são únicos', () => {
  const names = workflow.nodes.map((item) => item.name);
  assert.equal(new Set(names).size, names.length);
});

test('24. seletor ignora publish keys literais do legado sem depender de caixa', () => {
  const selectorCode = node('Selecionar 1 post estático seguro1').parameters.jsCode;
  assert.match(selectorCode, /upper\(key\)\.includes\('\{ \$JSON'\)/);
});

let failures = 0;
for (const entry of tests) {
  try {
    await entry.callback();
    console.log(`PASS ${entry.name}`);
  } catch (error) {
    failures += 1;
    console.error(`FAIL ${entry.name}`);
    console.error(error.stack || error);
  }
}

console.log(`\nResultado: ${tests.length - failures}/${tests.length} testes aprovados.`);
if (failures) process.exitCode = 1;
