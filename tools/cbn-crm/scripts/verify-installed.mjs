// Read-only verification of the installed plugin, using a real MCP stdio client.
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { homedir } from 'node:os';
import assert from 'node:assert/strict';
import { Client } from '@modelcontextprotocol/client';
import { StdioClientTransport } from '@modelcontextprotocol/client/stdio';

const filename = path.join(homedir(), '.codex', 'plugins', 'cache', 'cbn-local', 'cbn-crm', '0.1.0', 'mcp.json');
const spec = JSON.parse((await readFile(filename, 'utf8')).replace(/^\uFEFF/, '')).mcpServers.cbn_crm;
const client = new Client({ name: 'cbn-installed-readonly-check', version: '1.0.0' });
const env = Object.fromEntries(Object.entries(process.env).filter(([k, v]) => typeof v === 'string' && !k.startsWith('CBN_CRM_')));
const transport = new StdioClientTransport({ command: spec.command, args: spec.args, env: { ...env, ...spec.env }, stderr: 'pipe' });
try {
  await client.connect(transport);
  const { tools } = await client.listTools(); assert.equal(tools.length, 13);
  const statusResult = await client.callTool({ name: 'crm_status', arguments: {} });
  assert(!statusResult.isError); const status = JSON.parse(statusResult.content[0].text);
  assert.equal(status.authenticated, true); assert.equal(status.crm, 'https://crm.cbncredito.tech');
  const inboxResult = await client.callTool({ name: 'crm_list_inboxes', arguments: {} }); assert(!inboxResult.isError);
  const { inboxes } = JSON.parse(inboxResult.content[0].text); assert(inboxes.some(i => i.id === 5));
  const rulesResult = await client.callTool({ name: 'crm_list_automations', arguments: {} }); assert(!rulesResult.isError);
  const rules = JSON.parse(rulesResult.content[0].text);
  // Missing conversation: checks private route/authentication without reading a customer's history.
  for (const name of ['crm_get_messages', 'crm_list_schedules']) {
    const result = await client.callTool({ name, arguments: { conversation_id: 999999999 } });
    assert.equal(result.isError, true); assert.match(result.content[0].text, /404/);
  }
  console.log(JSON.stringify({ installed_plugin: 'cbn-crm@cbn-local', tools: tools.length, authenticated: status.authenticated,
    account_id: status.account_id, identity_user_id: status.identity.id, inboxes: inboxes.length,
    automations_api: 'read-only OK', automation_response_keys: Object.keys(rules),
    messages_and_schedules_private_routes: 'authenticated 404 for nonexistent conversation',
    transcription_configured: status.audio.transcription_configured, writes_executed: 0 }));
} finally { await client.close(); }
