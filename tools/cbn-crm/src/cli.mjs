#!/usr/bin/env node
import { readFile } from 'node:fs/promises';
import { loadConfig } from './config.mjs';
import { Crm } from './crm.mjs';
import { toolDefinitions } from './tools.mjs';

async function main() {
  const [command, toolName, flag, input] = process.argv.slice(2);
  if (!command || ['help', '--help', '-h'].includes(command)) {
    console.log('CBN CRM\n  cbn-crm status\n  cbn-crm tools\n  cbn-crm call <tool> --json <JSON>\n  cbn-crm call <tool> --input <arquivo.json>\n  cbn-crm call <tool> --stdin\n  cbn-crm mcp\nCredenciais: configuração privada ou variáveis CBN_CRM_*. Nunca passe tokens como argumento.'); return;
  }
  if (command === 'mcp') { const { makeServer } = await import('./server.mjs'); const { StdioServerTransport } = await import('@modelcontextprotocol/server/stdio'); await makeServer(await loadConfig()).connect(new StdioServerTransport()); return; }
  const tools = toolDefinitions(new Crm(await loadConfig()));
  if (command === 'tools') { console.log(JSON.stringify(tools.map(t => ({ name: t.name, description: t.description })), null, 2)); return; }
  const tool = tools.find(t => t.name === (command === 'status' ? 'crm_status' : toolName));
  if (!tool || !['status', 'call'].includes(command)) throw new Error('Comando/ferramenta inválido. Use --help.');
  let args = {};
  if (command === 'call') {
    if (flag === '--json') args = JSON.parse(input);
    else if (flag === '--input') args = JSON.parse(await readFile(input, 'utf8'));
    else if (flag === '--stdin') { let data = ''; for await (const chunk of process.stdin) { data += chunk; if (data.length > 100_000) throw new Error('Entrada muito grande.'); } args = JSON.parse(data); }
    else if (flag) throw new Error('Use --json, --input ou --stdin.');
  }
  console.log(JSON.stringify(await tool.run(tool.schema.parse(args)), null, 2));
}
main().catch(e => { console.error(JSON.stringify({ error: e.name === 'ZodError' || e instanceof SyntaxError ? 'Argumentos inválidos.' : e.message })); process.exitCode = 1; });
