import { readFile, mkdir } from 'node:fs/promises';
import { homedir } from 'node:os';
import path from 'node:path';

export const defaultHome = () => path.join(process.env.LOCALAPPDATA || path.join(homedir(), '.local', 'share'), 'CBN', 'crm-plugin');
export async function loadConfig(env = process.env) {
  const configPath = env.CBN_CRM_CONFIG || path.join(defaultHome(), 'config.json');
  let file = {};
  try { file = JSON.parse((await readFile(configPath, 'utf8')).replace(/^\uFEFF/, '')); }
  catch (e) { if (e.code !== 'ENOENT') throw new Error('Configuração CBN inválida. Revise config.json.'); }
  const baseUrl = env.CBN_CRM_URL || file.baseUrl || 'https://crm.cbncredito.tech';
  const url = new URL(baseUrl);
  if (url.protocol !== 'https:' || url.username || url.password || url.search || url.hash || url.pathname !== '/') throw new Error('CRM exige origem HTTPS sem caminho ou credenciais.');
  const accountId = Number(env.CBN_CRM_ACCOUNT_ID || file.accountId || 1);
  if (!Number.isSafeInteger(accountId) || accountId < 1) throw new Error('Conta CRM inválida.');
  let token = env.CBN_CRM_TOKEN || '';
  const tokenFile = env.CBN_CRM_TOKEN_FILE || file.tokenFile;
  if (!token && tokenFile) {
    try { token = (await readFile(path.resolve(path.dirname(configPath), tokenFile), 'utf8')).trim(); }
    catch { throw new Error('Credencial CRM indisponível. Execute a configuração local.'); }
  }
  const stateDir = path.resolve(file.stateDir || path.join(defaultHome(), 'state'));
  await mkdir(stateDir, { recursive: true, mode: 0o700 });
  return {
    baseUrl: url.origin, accountId, token, stateDir,
    writesEnabled: file.writesEnabled === true,
    uploadRoot: path.resolve(file.uploadRoot || path.join(defaultHome(), 'uploads')),
    mediaOrigins: [url.origin, ...(file.mediaOrigins || [])].map(s => {
      const u = new URL(s);
      if (u.protocol !== 'https:' || u.username || u.password) throw new Error('Origem de mídia inválida.');
      return u.origin;
    }),
    transcription: file.transcription || null,
    configPath,
  };
}
