import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Client } from '@modelcontextprotocol/client';
import { StdioClientTransport } from '@modelcontextprotocol/client/stdio';

test('real stdio initialize, tool schemas and call work with no credentials or stdout pollution', async t => {
  const root = await mkdtemp(path.join(tmpdir(), 'cbn-mcp-'));
  t.after(() => rm(root, { recursive: true, force: true }));
  const configPath = path.join(root, 'config.json');
  await writeFile(configPath, JSON.stringify({ stateDir: path.join(root, 'state') }));
  const env = Object.fromEntries(Object.entries(process.env).filter(([k, v]) => typeof v === 'string' && !k.startsWith('CBN_CRM_')));
  const transport = new StdioClientTransport({ command: process.execPath, args: [fileURLToPath(new URL('../src/server.mjs', import.meta.url))], env: { ...env, CBN_CRM_CONFIG: configPath }, stderr: 'pipe' });
  const client = new Client({ name: 'cbn-synthetic-test', version: '1.0.0' });
  t.after(() => client.close());
  await client.connect(transport);
  const { tools } = await client.listTools();
  assert.equal(tools.length, 13);
  const execute = tools.find(t => t.name === 'crm_execute_action'); assert.equal(execute.annotations.destructiveHint, true);
  const result = await client.callTool({ name: 'crm_status', arguments: {} });
  assert.equal(result.isError, undefined); assert.equal(JSON.parse(result.content[0].text).authenticated, false);
  const bad = await client.callTool({ name: 'crm_get_messages', arguments: { conversation_id: -1 } });
  assert.equal(bad.isError, true);
});
