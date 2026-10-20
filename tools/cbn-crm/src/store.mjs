import { createHash, randomUUID } from 'node:crypto';
import { mkdir, readFile, writeFile, rename, open, appendFile, unlink } from 'node:fs/promises';
import path from 'node:path';

export const digest = data => createHash('sha256').update(typeof data === 'string' || Buffer.isBuffer(data) ? data : JSON.stringify(data)).digest('hex');
export function uuid(value) {
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value || '')) throw new Error('Identificador UUID inválido.');
  return value;
}
export class ActionStore {
  constructor(root) { this.root = root; }
  file(id) { return path.join(this.root, `${uuid(id)}.json`); }
  async init() { await mkdir(this.root, { recursive: true, mode: 0o700 }); }
  async save(row) {
    await this.init(); const target = this.file(row.id), tmp = `${target}.${randomUUID()}.tmp`;
    await writeFile(tmp, JSON.stringify(row), { mode: 0o600 }); await rename(tmp, target);
  }
  async read(id) {
    try { return JSON.parse(await readFile(this.file(id), 'utf8')); }
    catch (e) { if (e.code === 'ENOENT') throw new Error('Ação não encontrada.'); throw e; }
  }
  async lock(id, fn) {
    await this.init(); const lockPath = `${this.file(id)}.lock`; let handle;
    try { handle = await open(lockPath, 'wx', 0o600); }
    catch (e) { if (e.code === 'EEXIST') throw new Error('Ação em execução ou interrompida. Confira o CRM antes de reconciliar; não recrie o envio.'); throw e; }
    try { return await fn(); }
    finally { await handle.close(); await unlink(lockPath); }
  }
  async audit(row, event) {
    await appendFile(path.join(this.root, 'audit.jsonl'), JSON.stringify({ at: new Date().toISOString(), id: row.id, kind: row.action.kind, event, account_id: row.accountId, actor_id: row.actor_id, approval_ref_hash: row.approval_ref_hash, conversation_id: row.action.conversation_id, result_id: row.result?.id }) + '\n', { mode: 0o600 });
  }
}
