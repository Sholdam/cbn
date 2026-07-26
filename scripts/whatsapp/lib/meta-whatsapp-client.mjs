export class MetaWhatsappApiError extends Error {
  constructor(message, { status, method, path } = {}) {
    super(message);
    this.name = 'MetaWhatsappApiError';
    this.status = status;
    this.method = method;
    this.path = path;
  }
}

function normalizeGraphVersion(graphVersion) {
  if (!/^v\d+\.\d+$/.test(graphVersion ?? '')) {
    throw new Error('META_GRAPH_API_VERSION deve seguir o formato vNN.N.');
  }
  return graphVersion;
}

function normalizeBaseUrl(baseUrl) {
  return (baseUrl ?? 'https://graph.facebook.com').replace(/\/+$/, '');
}

function required(value, name) {
  if (!value) throw new Error(`${name} é obrigatório para acessar a Meta.`);
  return value;
}

export function createMetaWhatsappClient({
  graphVersion,
  appId,
  wabaId,
  accessToken,
  fetchImpl = globalThis.fetch,
  baseUrl = 'https://graph.facebook.com',
}) {
  const version = normalizeGraphVersion(graphVersion);
  const app = required(appId, 'META_APP_ID');
  const waba = required(wabaId, 'META_WABA_ID');
  const token = required(accessToken, 'META_SYSTEM_USER_ACCESS_TOKEN');

  if (typeof fetchImpl !== 'function') {
    throw new Error('Esta execução requer Node.js com fetch nativo.');
  }

  const graphBase = `${normalizeBaseUrl(baseUrl)}/${version}`;

  async function request(method, path, { body, headers = {}, query } = {}) {
    const url = new URL(`${graphBase}/${path.replace(/^\/+/, '')}`);
    for (const [key, value] of Object.entries(query ?? {})) {
      if (value !== undefined && value !== null && value !== '') {
        url.searchParams.set(key, String(value));
      }
    }

    let response;
    try {
      response = await fetchImpl(url, {
        method,
        headers: {
          Authorization: `Bearer ${token}`,
          Accept: 'application/json',
          ...headers,
        },
        ...(body === undefined ? {} : { body }),
      });
    } catch (error) {
      throw new MetaWhatsappApiError(
        `Falha de rede ao acessar a Meta (${method} /${path}): ${error.message}`,
        { method, path: `/${path}` },
      );
    }

    const raw = await response.text();
    let parsed;
    if (raw) {
      try {
        parsed = JSON.parse(raw);
      } catch {
        parsed = undefined;
      }
    }

    if (!response.ok) {
      const permissionHint =
        response.status === 401 || response.status === 403
          ? ' Verifique o usuário do sistema, o token e as permissões do WhatsApp.'
          : '';
      throw new MetaWhatsappApiError(
        `Meta recusou ${method} /${path} com HTTP ${response.status}.${permissionHint}`,
        { status: response.status, method, path: `/${path}` },
      );
    }

    return parsed;
  }

  return {
    async listMessageTemplates({ limit = 100 } = {}) {
      const templates = [];
      let after;

      for (let page = 0; page < 100; page += 1) {
        const result = await request('GET', `${waba}/message_templates`, {
          query: {
            fields:
              'id,name,language,category,status,components,rejected_reason,quality_score',
            limit,
            after,
          },
        });
        templates.push(...(result?.data ?? []));
        after = result?.paging?.cursors?.after;
        if (!after) break;
      }

      return templates;
    },

    async startResumableUpload({ fileName, fileLength, fileType }) {
      return request('POST', `${app}/uploads`, {
        query: {
          file_name: fileName,
          file_length: fileLength,
          file_type: fileType,
        },
      });
    },

    async uploadFileBytes(uploadSessionId, bytes, { offset = 0 } = {}) {
      return request('POST', uploadSessionId, {
        body: bytes,
        headers: {
          Authorization: `OAuth ${token}`,
          'Content-Type': 'application/octet-stream',
          file_offset: String(offset),
        },
      });
    },

    async createMessageTemplate(payload) {
      return request('POST', `${waba}/message_templates`, {
        body: JSON.stringify(payload),
        headers: { 'Content-Type': 'application/json' },
      });
    },
  };
}
