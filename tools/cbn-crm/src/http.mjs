export const MAX_BYTES = 20 * 1024 * 1024;
export class CrmError extends Error {
  constructor(message, status, uncertain = false) { super(message); this.status = status; this.uncertain = uncertain; }
}
export async function limitedBytes(response, limit = MAX_BYTES) {
  if (Number(response.headers.get('content-length')) > limit) {
    await response.body?.cancel(); throw new Error('Arquivo/resposta excede o limite de 20 MiB.');
  }
  const reader = response.body?.getReader();
  if (!reader) return Buffer.alloc(0);
  const chunks = []; let size = 0;
  try {
    for (;;) {
      const { done, value } = await reader.read(); if (done) break;
      size += value.length;
      if (size > limit) throw new Error('Arquivo/resposta excede o limite de 20 MiB.');
      chunks.push(value);
    }
  } catch (e) { await reader.cancel().catch(() => {}); throw e; }
  finally { reader.releaseLock(); }
  return Buffer.concat(chunks);
}
export class CrmHttp {
  constructor(config, fetchImpl = fetch) { this.config = config; this.fetch = fetchImpl; }
  async request(route, { method = 'GET', query = {}, body } = {}) {
    const { config } = this;
    if (!config.token) throw new CrmError('CRM não autenticado. Configure a credencial local; não cole tokens no chat.', 401);
    if (!route.startsWith('/') || route.startsWith('//')) throw new Error('Rota inválida.');
    const url = new URL(route, config.baseUrl);
    if (url.origin !== config.baseUrl) throw new Error('Origem não autorizada.');
    for (const [key, value] of Object.entries(query)) if (value !== undefined) url.searchParams.set(key, String(value));
    const multipart = body instanceof FormData;
    let response;
    try {
      response = await this.fetch(url, { method, redirect: 'manual', signal: AbortSignal.timeout(30_000),
        // Hyphens survive nginx's default underscore-header filtering; Rack normalizes both to HTTP_API_ACCESS_TOKEN.
        headers: { 'api-access-token': config.token, Accept: 'application/json', ...(body && !multipart ? { 'Content-Type': 'application/json' } : {}) },
        body: body === undefined ? undefined : multipart ? body : JSON.stringify(body) });
    } catch { throw new CrmError('Falha de rede/timeout. Confira o CRM antes de repetir qualquer envio.', null, method !== 'GET'); }
    if (!response.ok) {
      await response.body?.cancel();
      throw new CrmError(`CRM respondeu HTTP ${response.status}.`, response.status, method !== 'GET');
    }
    try {
      const bytes = await limitedBytes(response);
      return bytes.length ? JSON.parse(bytes.toString('utf8')) : {};
    } catch { throw new CrmError('Resposta CRM inválida. Confira a operação antes de repetir.', response.status, method !== 'GET'); }
  }
  async media(source) {
    let url = new URL(source);
    for (let redirects = 0; redirects <= 4; redirects++) {
      if (url.protocol !== 'https:' || url.username || url.password || !this.config.mediaOrigins.includes(url.origin)) throw new Error('Origem de mídia não autorizada; revise mediaOrigins.');
      // Active Storage uses signed URLs. Never forward the CRM token to media/CDN endpoints.
      const response = await this.fetch(url, { redirect: 'manual', signal: AbortSignal.timeout(30_000) });
      if ([301, 302, 303, 307, 308].includes(response.status)) {
        const location = response.headers.get('location'); await response.body?.cancel();
        if (!location) throw new Error('Redirecionamento de mídia inválido.');
        url = new URL(location, url); continue;
      }
      if (!response.ok) { await response.body?.cancel(); throw new Error(`Mídia indisponível: HTTP ${response.status}.`); }
      const mimeType = (response.headers.get('content-type') || 'application/octet-stream').split(';')[0].trim();
      return { bytes: await limitedBytes(response), mimeType };
    }
    throw new Error('Limite de redirecionamentos de mídia excedido.');
  }
}
