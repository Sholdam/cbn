// Operational script: uses the installed CBN CRM's private configuration.
// No credentials or customer records are written to the repository.
import { pathToFileURL } from 'node:url';
import path from 'node:path';
import { readFile, writeFile } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
const runtime = path.join(process.env.LOCALAPPDATA, 'CBN/crm-plugin/plugins/cbn-crm/src');
const { loadConfig } = await import(pathToFileURL(path.join(runtime, 'config.mjs')));
const { Crm } = await import(pathToFileURL(path.join(runtime, 'crm.mjs')));
const config = await loadConfig();
if (config.baseUrl !== 'https://crm.cbncredito.tech' || config.accountId !== 1 || !config.writesEnabled) throw Error('Wrong account or writes disabled');
const crm = new Crm(config);
const journalPath = path.join(config.stateDir, 'colatina-employment-20261019.json');
let journal;
try { journal = JSON.parse(await readFile(journalPath, 'utf8')); }
catch (e) { if (e.code !== 'ENOENT') throw e; journal = { operation_id: randomUUID() }; }
const save = () => writeFile(journalPath, JSON.stringify(journal, null, 2), { mode: 0o600 });
await save();
const name = 'CBN — Colatina: perguntar vínculo após matrícula';
const prompt = 'Obrigado! Qual é o seu vínculo com a Prefeitura de Colatina?\n\n1. Comissionado\n2. Efetivo\n3. Temporário\n\nResponda com o número da opção.';
const mode = process.argv[2];
if (mode === 'create') {
  const rows = (await crm.automations()).payload;
  const existing = rows.find(r => r.name === name);
  if (existing) {
    if (existing.actions[0]?.action_params?.[0] !== prompt) throw Error('Existing rule differs');
    journal.rule_id = existing.id;
  } else {
    const rule = { name, description: 'Após matrícula, registra vínculo autodeclarado. Opções 1/2/3 não são matrícula; encaminhamento humano para todas as opções. Sem histórico ou decisão de crédito.', event_name: 'conversation_updated', active: false,
      conditions: [
        { attribute_key: 'inbox_id', filter_operator: 'equal_to', query_operator: 'AND', custom_attribute_type: '', values: [5] },
        { attribute_key: 'cbn_coleta_etapa', filter_operator: 'equal_to', custom_attribute_type: 'conversation_attribute', values: ['matricula_recebida'] }
      ], actions: [{ action_name: 'send_message', action_params: [prompt] }] };
    const prepared = await crm.prepare({ operation_id: journal.operation_id, action: { kind: 'automation_create', rule } });
    journal.action_id = prepared.action_id; await save();
    await crm.execute({ action_id: prepared.action_id, approval_reference: 'Guilherme em 19/10/2026 neste chat pediu criar e aplicar mais uma automação no CRM perguntando vínculo, com opções numeradas 1 comissionado, 2 efetivo, 3 temporário.' });
    const result = (await crm.automations()).payload.find(r => r.name === name);
    if (!result) throw Error('Created rule not found');
    journal.rule_id = result.id;
  }
  await save(); console.log(JSON.stringify({ rule_id: journal.rule_id, created_inactive: true, prompt }));
} else if (mode === 'ad-trigger') {
  const route = crm.account('/automation_rules/8');
  const raw = await crm.http.request(route);
  const rule = raw.payload ?? raw;
  if (rule.name !== 'CBN — Colatina: solicitar CPF') throw Error('Rule identity changed');
  const condition = rule.conditions.find(c => c.attribute_key === 'content');
  if (!condition || condition.filter_operator !== 'contains' || !condition.values.includes('120248430438870710')) throw Error('Unexpected trigger');
  const values = [...new Set([...condition.values, '120248595202310710', 'Trabalho na prefeitura. Quais são os requisitos para ter um consignado?'])];
  if (values.length !== condition.values.length) {
    journal.previous_rule8 ??= rule; await save();
    const conditions = rule.conditions.map(c => c === condition ? { ...c, values } : c);
    await crm.http.request(route, { method: 'PATCH', body: { conditions } });
  }
  const verifyRaw = await crm.http.request(route);
  const verify = verifyRaw.payload ?? verifyRaw;
  if (!verify.conditions.find(c => c.attribute_key === 'content').values.includes('120248595202310710')) throw Error('Trigger verification failed');
  console.log(JSON.stringify({ rule8_updated: true, active: verify.active, values }));
} else if (mode === 'activate') {
  if (!journal.rule_id) throw Error('Create first');
  journal.activation_operation_id ??= randomUUID(); await save();
  const prepared = await crm.prepare({ operation_id: journal.activation_operation_id, action: { kind: 'automation_set_active', rule_id: journal.rule_id, active: true } });
  await crm.execute({ action_id: prepared.action_id, approval_reference: 'Guilherme autorizou neste chat acrescentar e aplicar a etapa de vínculo à automação Colatina, com opções numeradas; todas as respostas seguem para atendente, sem pedido extra de documento.' });
  const rule = (await crm.automations()).payload.find(r => r.id === journal.rule_id);
  console.log(JSON.stringify({ rule_id: rule.id, active: rule.active, conditions: rule.conditions, actions: rule.actions }));
} else throw Error('Use create, ad-trigger, or activate');
