const patterns = {
  cpfPrompt: /informe\s+o\s+cpf\s+do\s+cliente/i,
  phonePrompt: /qual\s+[ée]\s+o\s+seu\s+celular\s+com\s+ddd/i,
  processing: /consultando\s+bancos[\s\S]*pode\s+levar\s+at[eé]\s+5\s+minutos/i,
  terminal: /informe\s+outro\s+cpf\s+ou\s+escolha\s+uma\s+op[cç][aã]o/i,
  offerSelection: /escolha\s+um\s+banco\s+para\s+ver\s+os\s+prazos\s+dispon[ií]veis/i,
  cltMenu: /menu\s+principal\s*-\s*clt/i,
  productMenu: /com\s+qual\s+produto\s+deseja\s+seguir/i,
  c6Authorization: /link\s+de\s+autoriza[cç][aã]o|cliente\s+autorizou\s*[–—-]\s*simular\s+agora/i,
};

export function classifyTelegramMessage(text) {
  const message = String(text ?? '');
  if (patterns.c6Authorization.test(message)) return 'C6_AUTHORIZATION';
  if (patterns.phonePrompt.test(message)) return 'PHONE_PROMPT';
  if (patterns.cpfPrompt.test(message)) return 'CPF_PROMPT';
  if (patterns.processing.test(message)) return 'PROCESSING';
  if (patterns.offerSelection.test(message)) return 'OFFER_SELECTION_PROMPT';
  if (patterns.terminal.test(message)) return 'TERMINAL';
  if (patterns.cltMenu.test(message)) return 'CLT_MENU';
  if (patterns.productMenu.test(message)) return 'PRODUCT_MENU';
  return 'RESULT';
}

export function isResultContent(kind) {
  return kind === 'RESULT' || kind === 'TERMINAL' || kind === 'OFFER_SELECTION_PROMPT';
}
