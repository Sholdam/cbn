import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, mkdir, readFile, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { randomUUID } from 'node:crypto';
import { Crm } from '../src/crm.mjs';
import { CrmHttp, MAX_BYTES, limitedBytes } from '../src/http.mjs';
import { prepareSchema } from '../src/schemas.mjs';
import { loadConfig } from '../src/config.mjs';

const json = data => new Response(JSON.stringify(data), { headers: { 'content-type': 'application/json' } });
async function fixture(t, opts = {}) {
  const root = await mkdtemp(path.join(tmpdir(), 'cbn-crm-test-'));
  t.after(() => rm(root, { recursive: true, force: true }));
  const config = { baseUrl: 'https://crm.example', accountId: 1, token: 'synthetic-secret', stateDir: root, uploadRoot: path.join(root, 'input'), writesEnabled: true, mediaOrigins: ['https://crm.example'] };
  let latest = 101, recipient = 20, posts = [], calls = [];
  const fetchImpl = async (url, req = {}) => {
    const u = new URL(url); calls.push({ url: u, req });
    if (req.method && req.method !== 'GET') {
      posts.push({ url: u, req });
      if (opts.failWrite) throw new Error('synthetic-secret should never escape');
      return json({ id: 202, status: 'sent' });
    }
    if (u.pathname.endsWith('/messages')) return json({ payload: [{ id: latest, content: 'Mensagem sintética', message_type: 0, attachments: [{ id: 51, message_id: latest, file_type: 'audio', extension: 'ogg', data_url: 'https://crm.example/media/signed-secret' }] }] });
    if (u.pathname.endsWith('/profile')) return json({ id: 1, name: 'Operador teste', access_token: 'synthetic-secret', accounts: [{ id: 1, role: 'administrator' }] });
    if (u.pathname.endsWith('/automation_rules/4')) return json({ id: 4, active: false, actions: [] });
    if (u.pathname.endsWith('/scheduled_messages')) return json([{ id: 80, content: 'Agendamento sintético', scheduled_at: '2026-10-20T14:00:00-03:00', status: 'pending' }]);
    return json({ id: 10, inbox_id: 5, meta: { sender: { id: recipient, name: 'Cliente sintético', phone_number: '+5500000000000' } } });
  };
  return { root, config, crm: new Crm(config, fetchImpl), fetchImpl, posts, calls, setLatest: x => latest = x, setRecipient: x => recipient = x };
}
const prepareMessage = (crm, operation_id = randomUUID()) => crm.prepare({ operation_id, action: { kind: 'send_message', conversation_id: 10, content: 'Resposta sintética' } });
const execute = (crm, action_id) => crm.execute({ action_id, approval_reference: 'Usuário autorizou atendimento sintético.' });

test('prepare has no remote mutation; stable operation_id deduplicates and rejects altered intent', async t => {
  const f = await fixture(t), op = randomUUID();
  const a = await prepareMessage(f.crm, op), b = await prepareMessage(f.crm, op);
  assert.equal(a.action_id, b.action_id); assert.equal(f.posts.length, 0);
  await assert.rejects(() => f.crm.prepare({ operation_id: op, action: { ...a.action, content: 'Outra intenção' } }), /outra ação/);
});
test('completed actions survive restart without duplicate messages; audit has no content/token', async t => {
  const f = await fixture(t), p = await prepareMessage(f.crm);
  const result = await execute(f.crm, p.action_id);
  const replay = await execute(new Crm(f.config, f.fetchImpl), p.action_id);
  assert.equal(result.result.id, 202); assert.equal(replay.replay, true); assert.equal(f.posts.length, 1);
  const body = JSON.parse(f.posts[0].req.body); assert.equal(body.private, false); assert.equal(body.message_type, 'outgoing');
  const audit = await readFile(path.join(f.root, 'actions', 'audit.jsonl'), 'utf8');
  assert(!audit.includes('Resposta sintética')); assert(!audit.includes('synthetic-secret'));
});
test('timeout is persisted as unknown; restart never retries automatically', async t => {
  const f = await fixture(t, { failWrite: true }), p = await prepareMessage(f.crm);
  await assert.rejects(() => execute(f.crm, p.action_id), e => /incerto/.test(e.message) && !e.message.includes('synthetic-secret'));
  const other = new Crm(f.config, f.fetchImpl);
  assert.equal((await other.store.read(p.action_id)).state, 'unknown');
  await assert.rejects(() => execute(other, p.action_id), /incerto/); assert.equal(f.posts.length, 1);
});
test('concurrent execution dispatches once', async t => {
  const f = await fixture(t), p = await prepareMessage(f.crm);
  const results = await Promise.allSettled([execute(f.crm, p.action_id), execute(new Crm(f.config, f.fetchImpl), p.action_id)]);
  assert(results.some(x => x.status === 'fulfilled')); assert.equal(f.posts.length, 1);
});
test('new message or changed recipient blocks a stale reply before dispatch', async t => {
  const f = await fixture(t), p = await prepareMessage(f.crm);
  f.setLatest(102); await assert.rejects(() => execute(f.crm, p.action_id), /conversa mudou/);
  f.setLatest(101); f.setRecipient(21); await assert.rejects(() => execute(f.crm, p.action_id), /Destinatário/);
  assert.equal(f.posts.length, 0);
});
test('writes disabled, wrong account, absent approval and expired draft all fail closed', async t => {
  const f = await fixture(t), p = await prepareMessage(f.crm);
  await assert.rejects(() => execute(new Crm({ ...f.config, writesEnabled: false }, f.fetchImpl), p.action_id), /desabilitadas/);
  await assert.rejects(() => execute(new Crm({ ...f.config, accountId: 2 }, f.fetchImpl), p.action_id), /outro CRM/);
  await assert.rejects(() => f.crm.execute({ action_id: p.action_id, approval_reference: '' }));
  const row = await f.crm.store.read(p.action_id); row.created_at = '2020-01-01T00:00:00Z'; await f.crm.store.save(row);
  await assert.rejects(() => execute(f.crm, p.action_id), /expirada/); assert.equal(f.posts.length, 0);
});
test('profile token and signed media URLs are excluded from normal tool output', async t => {
  const f = await fixture(t), status = await f.crm.status(), messages = await f.crm.messages({ conversation_id: 10, after: 100 });
  assert.equal(status.authenticated, true); assert.equal(messages.next_after, 101);
  assert(!JSON.stringify(status).includes('synthetic-secret')); assert(!JSON.stringify(messages).includes('signed-secret'));
  assert.equal(f.calls.at(-1).url.searchParams.get('after'), '100');
});
test('API redirects never leak token; media external redirect rejected with no auth forwarded', async t => {
  const f = await fixture(t); let apiReq;
  const api = new CrmHttp(f.config, async (_, req) => { apiReq = req; return new Response('', { status: 302, headers: { location: 'https://evil.example' } }); });
  await assert.rejects(() => api.request('/api/v1/profile'), /302/); assert.equal(apiReq.redirect, 'manual');
  let mediaCalls = 0;
  const media = new CrmHttp(f.config, async (_, req) => { mediaCalls++; assert.equal(req.headers, undefined); return new Response('', { status: 302, headers: { location: 'http://127.0.0.1/admin' } }); });
  await assert.rejects(() => media.media('https://crm.example/rails/media'), /não autorizada/); assert.equal(mediaCalls, 1);
});
test('streaming media limit works without content-length', async () => {
  const response = new Response(new ReadableStream({ start(controller) { controller.enqueue(new Uint8Array(20)); controller.enqueue(new Uint8Array(20)); controller.close(); } }));
  await assert.rejects(() => limitedBytes(response, 30), /limite/);
});
test('media upload snapshots bytes, validates path, posts multipart and preserves privacy', async t => {
  const f = await fixture(t); await mkdir(f.config.uploadRoot);
  const outside = path.join(f.root, 'private.txt'); await writeFile(outside, 'private');
  await assert.rejects(() => f.crm.upload({ file_path: outside }), /pasta de uploads/);
  const filename = path.join(f.config.uploadRoot, 'sample.ogg'); await writeFile(filename, Buffer.from('OggSsynthetic'));
  const upload = await f.crm.upload({ file_path: filename });
  await writeFile(filename, 'changed source does not change approved snapshot');
  const p = await f.crm.prepare({ operation_id: randomUUID(), action: { kind: 'send_media', conversation_id: 10, upload_id: upload.upload_id, private: true } });
  await execute(f.crm, p.action_id);
  const form = f.posts[0].req.body; assert(form instanceof FormData); assert.equal(form.get('private'), 'true');
  assert.equal(await form.get('attachments[]').text(), 'OggSsynthetic');
  assert.equal(form.get('attachments[]').name, 'sample.ogg'); assert.equal(form.get('attachments[]').type, 'audio/ogg');
});
test('schedules use CBN native API and stable UUID; automation defaults to inactive', async t => {
  const f = await fixture(t), op = randomUUID();
  const p = await f.crm.prepare({ operation_id: op, action: { kind: 'schedule_create', conversation_id: 10, content: 'Olá sintético', scheduled_local: '2026-10-20T14:00' } });
  await execute(f.crm, p.action_id);
  assert.equal(f.posts[0].url.pathname, '/site/cbn-api/accounts/1/conversations/10/scheduled_messages');
  assert.equal(JSON.parse(f.posts[0].req.body).request_id, op);
  const parsed = prepareSchema.parse({ operation_id: randomUUID(), action: { kind: 'automation_create', rule: { name: 'Regra teste', event_name: 'message_created', conditions: [{ attribute_key: 'inbox_id', filter_operator: 'equal_to', values: [5] }], actions: [{ action_name: 'send_message', action_params: ['Sintético'] }] } } });
  assert.equal(parsed.action.rule.active, false);
});
test('strict action schemas reject arbitrary HTTP operations and config requires HTTPS', async t => {
  assert.equal(prepareSchema.safeParse({ operation_id: randomUUID(), action: { kind: 'http', route: '/admin' } }).success, false);
  const f = await fixture(t), filename = path.join(f.root, 'config.json');
  await writeFile(filename, JSON.stringify({ baseUrl: 'http://crm.example' }));
  await assert.rejects(() => loadConfig({ CBN_CRM_CONFIG: filename }), /HTTPS/);
  assert.equal(MAX_BYTES, 20971520);
});
test('cancel preview includes original schedule and rejects another conversation schedule id', async t => {
  const f = await fixture(t);
  const p = await f.crm.prepare({ operation_id: randomUUID(), action: { kind: 'schedule_cancel', conversation_id: 10, schedule_id: 80 } });
  assert.equal(p.previous_schedule.content, 'Agendamento sintético');
  await assert.rejects(() => f.crm.prepare({ operation_id: randomUUID(), action: { kind: 'schedule_cancel', conversation_id: 10, schedule_id: 81 } }), /não encontrado/);
  await execute(f.crm, p.action_id); assert.equal(f.posts[0].req.method, 'DELETE');
});
test('attachment lookup refuses an attachment from another message before downloading', async t => {
  const f = await fixture(t);
  await assert.rejects(() => f.crm.attachment({ conversation_id: 10, message_id: 500, attachment_id: 51, format: 'download' }), /não encontrado/);
  assert.equal(f.calls.length, 1); assert.equal(f.calls[0].url.pathname.endsWith('/messages'), true);
});
