import { classifyTelegramMessage, isResultContent } from './clt-state.js';
import { parseCltOffers } from './clt-offers.js';
import { sanitizeTelegramText } from './validation.js';

export class HumanReviewError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'HumanReviewError';
    this.code = code;
  }
}

async function moveToCpfPrompt(adapter, operationId) {
  for (let transitions = 0; transitions < 5; transitions += 1) {
    const current = await adapter.peekLatest();
    const kind = classifyTelegramMessage(current?.text);

    if (kind === 'CPF_PROMPT') return;
    if (kind === 'C6_AUTHORIZATION') {
      throw new HumanReviewError(
        'UNEXPECTED_C6_FLOW',
        'O bot do Telegram está em uma etapa de autorização do C6.'
      );
    }

    if (kind === 'PROCESSING') {
      throw new HumanReviewError(
        'PREVIOUS_OPERATION_STILL_PROCESSING',
        'O bot ainda indica uma consulta anterior em processamento.'
      );
    }

    if (kind === 'PHONE_PROMPT') {
      throw new HumanReviewError(
        'ORPHAN_PHONE_PROMPT',
        'O bot está aguardando telefone de uma operação anterior.'
      );
    }

    if (kind === 'PRODUCT_MENU' || kind === 'CLT_MENU' || kind === 'TERMINAL') {
      const sent = await adapter.send(operationId, `navigate-${transitions}`, '1');
      const next = await adapter.waitAfter(sent.id);
      const nextKind = classifyTelegramMessage(next.text);
      if (nextKind === 'CPF_PROMPT') return;
      if (nextKind === 'C6_AUTHORIZATION') {
        throw new HumanReviewError(
          'UNEXPECTED_C6_FLOW',
          'O bot do Telegram desviou para a autorização do C6.'
        );
      }
      continue;
    }

    if (!current?.text?.trim()) {
      const sent = await adapter.send(operationId, `menu-${transitions}`, 'menu');
      await adapter.waitAfter(sent.id);
      continue;
    }

    throw new HumanReviewError(
      'UNKNOWN_TELEGRAM_STATE',
      'A tela atual do bot não corresponde a um menu seguro conhecido.'
    );
  }

  throw new HumanReviewError(
    'CPF_PROMPT_NOT_REACHED',
    'Não foi possível posicionar o bot na solicitação de CPF.'
  );
}

export async function runCltFlow({ adapter, operationId, cpf, phone }) {
  await moveToCpfPrompt(adapter, operationId);

  const cpfSent = await adapter.send(operationId, 'cpf', cpf);
  let cursor = Number(cpfSent.id);
  const collected = [];
  let phoneSent = false;

  const finish = () => {
    const resultText = collected.filter(Boolean).join('\n\n').trim();
    if (!resultText) {
      throw new HumanReviewError(
        'EMPTY_RESULT',
        'A consulta terminou sem conteúdo seguro para registrar.'
      );
    }
    return {
      resultText,
      offers: parseCltOffers(resultText),
      phoneSent,
    };
  };

  for (;;) {
    const message = await adapter.waitAfter(cursor);
    cursor = Number(message.id);
    const kind = classifyTelegramMessage(message.text);

    if (kind === 'C6_AUTHORIZATION') {
      throw new HumanReviewError(
        'UNEXPECTED_C6_FLOW',
        'O bot solicitou autorização do C6 durante a consulta geral.'
      );
    }

    if (kind === 'PHONE_PROMPT') {
      if (phoneSent) {
        throw new HumanReviewError(
          'PHONE_REQUEST_REPEATED',
          'O bot solicitou o telefone mais de uma vez.'
        );
      }
      const sent = await adapter.send(operationId, 'phone', phone);
      cursor = Number(sent.id);
      phoneSent = true;
      continue;
    }

    if (isResultContent(kind)) {
      collected.push(sanitizeTelegramText(message.text, { cpf, phone }).trim());
    }

    if (kind === 'OFFER_SELECTION_PROMPT') {
      const sent = await adapter.send(operationId, 'exit-offer-selection', '0');
      const menu = await adapter.waitAfter(sent.id);
      if (classifyTelegramMessage(menu.text) !== 'CLT_MENU') {
        throw new HumanReviewError(
          'CLT_MENU_NOT_RESTORED',
          'Não foi possível voltar ao menu CLT após coletar as ofertas.'
        );
      }
      return finish();
    }

    if (kind === 'TERMINAL') {
      return finish();
    }
  }
}
