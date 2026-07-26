import { readFile, stat } from 'node:fs/promises';
import { basename, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { createMetaWhatsappClient } from './lib/meta-whatsapp-client.mjs';

export const TEMPLATE_NAME = 'cbn_ctps_simulacao_v1';
export const TEMPLATE_LANGUAGE = 'pt_BR';
export const TEMPLATE_CATEGORY = 'MARKETING';
export const DEFAULT_IMAGE_PATH = resolve(
  import.meta.dirname,
  '../../assets/whatsapp/cbn-ctps-simulacao-header.png',
);

export const TEMPLATE_BODY =
  'Olá, {{1}}! 👋\n\n' +
  'Você realizou recentemente uma simulação de Crédito do Trabalhador pela Carteira de Trabalho Digital.\n\n' +
  'A CBN Crédito pode ajudar a verificar as condições disponíveis e orientar os próximos passos.\n\n' +
  'Deseja continuar por aqui?';

export const TEMPLATE_FOOTER =
  'Atendimento sujeito à análise e às condições do produto.';

export const TEMPLATE_BUTTONS = [
  'Quero continuar',
  'Agora não',
  'Não quero receber',
];

export function validateTemplateName(name) {
  if (!/^[a-z0-9_]{1,512}$/.test(name ?? '')) {
    throw new Error(
      'Nome técnico inválido: use até 512 caracteres com letras minúsculas, números e underscore.',
    );
  }
  return name;
}

export function validateTemplateLanguage(language) {
  if (language !== 'pt_BR') {
    throw new Error('O modelo CBN CTPS deve usar o idioma pt_BR.');
  }
  return language;
}

export function buildTemplatePayload(headerHandle = 'DRY_RUN_HEADER_HANDLE', {
  name = TEMPLATE_NAME,
  language = TEMPLATE_LANGUAGE,
} = {}) {
  validateTemplateName(name);
  validateTemplateLanguage(language);
  if (!headerHandle) throw new Error('O header_handle da imagem é obrigatório.');

  return {
    name,
    language,
    category: TEMPLATE_CATEGORY,
    components: [
      {
        type: 'HEADER',
        format: 'IMAGE',
        example: { header_handle: [headerHandle] },
      },
      {
        type: 'BODY',
        text: TEMPLATE_BODY,
        example: { body_text: [['Maria']] },
      },
      {
        type: 'FOOTER',
        text: TEMPLATE_FOOTER,
      },
      {
        type: 'BUTTONS',
        buttons: TEMPLATE_BUTTONS.map((text) => ({ type: 'QUICK_REPLY', text })),
      },
    ],
  };
}

const FORBIDDEN_COPY = [
  /\baprovad[oa]\b/i,
  /\bpré[- ]?aprovad[oa]\b/i,
  /\bvalor liberado\b/i,
  /\bgarantia de aprovação\b/i,
  /\b\d+[,.]\d{2}\s*%/,
  /\bCPF\b/i,
  /\bFGTS\b/i,
  /\bconsulta CLT automática\b/i,
];

export function validateTemplateCopy(payload) {
  const body = payload.components.find(({ type }) => type === 'BODY')?.text ?? '';
  const violations = FORBIDDEN_COPY.filter((pattern) => pattern.test(body)).map(String);

  if (payload.category !== 'MARKETING') violations.push('category deve ser MARKETING');
  if (!body.includes('{{1}}')) violations.push('corpo deve conter {{1}}');
  if (!body.includes('CBN Crédito')) violations.push('corpo deve identificar a CBN Crédito');
  if (!body.includes('simulação')) violations.push('corpo deve mencionar a simulação');

  const buttons =
    payload.components.find(({ type }) => type === 'BUTTONS')?.buttons ?? [];
  if (
    buttons.length !== 3 ||
    buttons.some((button, index) => {
      return button.type !== 'QUICK_REPLY' || button.text !== TEMPLATE_BUTTONS[index];
    })
  ) {
    violations.push('botões de resposta rápida divergentes');
  }

  if (violations.length > 0) {
    throw new Error(`Modelo inválido: ${violations.join('; ')}`);
  }
  return true;
}

function readPngDimensions(bytes) {
  const signature = '89504e470d0a1a0a';
  if (bytes.length < 24 || bytes.subarray(0, 8).toString('hex') !== signature) {
    throw new Error('A imagem precisa ser um PNG válido.');
  }
  return {
    width: bytes.readUInt32BE(16),
    height: bytes.readUInt32BE(20),
  };
}

export async function validateHeaderImage(imagePath = DEFAULT_IMAGE_PATH) {
  let metadata;
  try {
    metadata = await stat(imagePath);
  } catch {
    throw new Error(`Imagem de cabeçalho não encontrada: ${imagePath}`);
  }
  if (!metadata.isFile()) throw new Error(`O cabeçalho não é um arquivo: ${imagePath}`);
  if (metadata.size > 5 * 1024 * 1024) {
    throw new Error('O PNG do cabeçalho excede o limite seguro de 5 MB.');
  }

  const bytes = await readFile(imagePath);
  const dimensions = readPngDimensions(bytes);
  if (dimensions.width !== 800 || dimensions.height !== 418) {
    throw new Error(
      `Dimensões inválidas: esperado 800x418, recebido ${dimensions.width}x${dimensions.height}.`,
    );
  }

  return {
    bytes,
    fileName: basename(imagePath),
    fileLength: metadata.size,
    fileType: 'image/png',
    width: dimensions.width,
    height: dimensions.height,
    optimized: metadata.size < 300 * 1024,
  };
}

function canonicalComponents(components = []) {
  return components.map((component) => {
    if (component.type === 'HEADER') {
      return { type: 'HEADER', format: component.format };
    }
    if (component.type === 'BODY') {
      return {
        type: 'BODY',
        text: component.text,
      };
    }
    if (component.type === 'FOOTER') {
      return { type: 'FOOTER', text: component.text };
    }
    if (component.type === 'BUTTONS') {
      return {
        type: 'BUTTONS',
        buttons: (component.buttons ?? []).map(({ type, text }) => ({ type, text })),
      };
    }
    return { type: component.type };
  });
}

export function compareTemplate(existing, expected) {
  const differences = [];
  if (existing.category !== expected.category) differences.push('category');
  if (
    JSON.stringify(canonicalComponents(existing.components)) !==
    JSON.stringify(canonicalComponents(expected.components))
  ) {
    differences.push('components');
  }
  return differences;
}

function findTemplate(templates, name, language) {
  return templates.find(
    (template) => template.name === name && template.language === language,
  );
}

export async function createCtpsTemplate({
  client,
  imagePath = DEFAULT_IMAGE_PATH,
  name = TEMPLATE_NAME,
  language = TEMPLATE_LANGUAGE,
}) {
  const expected = buildTemplatePayload('COMPARE_ONLY_HANDLE', { name, language });
  validateTemplateCopy(expected);

  const existing = findTemplate(
    await client.listMessageTemplates(),
    name,
    language,
  );

  if (existing) {
    if (existing.status === 'REJECTED') {
      throw new Error(
        `TEMPLATE_REJECTED: não será apagado. Revise o motivo e use uma nova versão, como ${name.replace(/_v\d+$/, '_v2')}.`,
      );
    }
    const differences = compareTemplate(existing, expected);
    if (differences.length > 0) {
      throw new Error(
        `TEMPLATE_DIVERGENT: ${differences.join(', ')}. Use um novo nome versionado.`,
      );
    }
    if (['PENDING', 'APPROVED'].includes(existing.status)) {
      return {
        outcome: 'NO_OP_TEMPLATE_ALREADY_EXISTS',
        name,
        language,
        status: existing.status,
      };
    }
  }

  const image = await validateHeaderImage(imagePath);
  const session = await client.startResumableUpload(image);
  if (!session?.id) throw new Error('A Meta não retornou o ID da sessão de upload.');

  const upload = await client.uploadFileBytes(session.id, image.bytes);
  if (!upload?.h) throw new Error('A Meta não retornou o header_handle da imagem.');

  const payload = buildTemplatePayload(upload.h, { name, language });
  validateTemplateCopy(payload);
  const response = await client.createMessageTemplate(payload);

  return {
    outcome: 'TEMPLATE_SUBMITTED',
    name,
    language,
    status: response?.status ?? 'PENDING',
    templateId: response?.id,
    imageOptimized: image.optimized,
  };
}

export function configFromEnvironment(env = process.env) {
  return {
    graphVersion: env.META_GRAPH_API_VERSION,
    appId: env.META_APP_ID,
    wabaId: env.META_WABA_ID,
    accessToken: env.META_SYSTEM_USER_ACCESS_TOKEN,
    name: env.META_TEMPLATE_NAME || TEMPLATE_NAME,
    language: env.META_TEMPLATE_LANGUAGE || TEMPLATE_LANGUAGE,
  };
}

function sanitizePayloadForOutput(payload) {
  return {
    ...payload,
    components: payload.components.map((component) => {
      if (component.type !== 'HEADER') return component;
      return {
        ...component,
        example: { header_handle: ['<obtido somente no upload autorizado>'] },
      };
    }),
  };
}

async function main() {
  const submit = process.argv.includes('--submit');
  const config = configFromEnvironment();
  const payload = buildTemplatePayload('DRY_RUN_HEADER_HANDLE', config);
  validateTemplateCopy(payload);
  const image = await validateHeaderImage();

  if (!submit) {
    console.log(
      JSON.stringify(
        {
          mode: 'DRY_RUN',
          remoteCalls: 0,
          image: {
            path: DEFAULT_IMAGE_PATH,
            dimensions: `${image.width}x${image.height}`,
            bytes: image.fileLength,
            optimizedBelow300KB: image.optimized,
          },
          payload: sanitizePayloadForOutput(payload),
        },
        null,
        2,
      ),
    );
    return;
  }

  const client = createMetaWhatsappClient(config);
  const result = await createCtpsTemplate({
    client,
    name: config.name,
    language: config.language,
  });
  console.log(JSON.stringify(result, null, 2));
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    console.error(`Falha ao preparar o modelo CTPS: ${error.message}`);
    process.exitCode = 1;
  });
}
