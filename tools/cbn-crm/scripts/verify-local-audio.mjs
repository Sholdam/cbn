// Pass only an explicitly generated synthetic WAV; never uses live CRM data.
import { readFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import assert from 'node:assert/strict';
import { loadConfig } from '../src/config.mjs';
import { Crm } from '../src/crm.mjs';
const wav = await readFile(process.argv[2]);
const root = await mkdtemp(path.join(tmpdir(), 'cbn-audio-verify-'));
try {
  const localConfig = await loadConfig();
  const crm = new Crm({ ...localConfig, token: 'synthetic-only', stateDir: root, baseUrl: 'https://crm.example', mediaOrigins: ['https://crm.example'] }, async url => {
    if (new URL(url).pathname === '/audio') return new Response(wav, { headers: { 'content-type': 'audio/wav' } });
    return new Response(JSON.stringify({ payload: [{ id: 10, attachments: [{ id: 20, message_id: 10, extension: 'wav', file_type: 'audio', data_url: 'https://crm.example/audio' }] }] }));
  });
  const result = await crm.attachment({ conversation_id: 1, message_id: 10, attachment_id: 20, format: 'transcribe' });
  assert.match(result.transcription.text, /CRM/i);
  const inline = await crm.attachment({ conversation_id: 1, message_id: 10, attachment_id: 20, format: 'inline' });
  assert.equal(inline.content[1].type, 'audio'); assert.equal(inline.content[1].mimeType, 'audio/wav');
  console.log(JSON.stringify({ synthetic_audio: true, plugin_transcription: 'passed', inline_audio: 'passed', transcript: result.transcription.text }));
} finally { await rm(root, { recursive: true, force: true }); }
