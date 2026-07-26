import { pathToFileURL } from 'node:url';
import {
  TEMPLATE_LANGUAGE,
  TEMPLATE_NAME,
  configFromEnvironment,
} from './create-ctps-template.mjs';
import { createMetaWhatsappClient } from './lib/meta-whatsapp-client.mjs';

export async function checkTemplateStatus({
  client,
  name = TEMPLATE_NAME,
  language = TEMPLATE_LANGUAGE,
  now = () => new Date(),
}) {
  const template = (await client.listMessageTemplates()).find(
    (candidate) => candidate.name === name && candidate.language === language,
  );

  if (!template) {
    return {
      name,
      language,
      status: 'NOT_FOUND',
      checkedAt: now().toISOString(),
    };
  }

  return {
    name: template.name,
    language: template.language,
    category: template.category,
    status: template.status,
    rejectedReason: template.rejected_reason ?? null,
    quality: template.quality_score ?? null,
    checkedAt: now().toISOString(),
  };
}

async function main() {
  const config = configFromEnvironment();
  const client = createMetaWhatsappClient(config);
  const result = await checkTemplateStatus({
    client,
    name: config.name,
    language: config.language,
  });
  console.log(JSON.stringify(result, null, 2));
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    console.error(`Falha ao consultar o modelo CTPS: ${error.message}`);
    process.exitCode = 1;
  });
}
