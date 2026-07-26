const offerLine =
  /^\s*([1-5])\s*[—–-]\s*(.+?)\s*[—–-]\s*(\d{1,3})\s*x\s*(?:de\s*)?R\$\s*([\d.]+,\d{2})\s*(?:→|->)\s*(?:recebe\s*)?R\$\s*([\d.]+,\d{2})\s*$/i;

function moneyToCents(value) {
  const normalized = String(value).replace(/\./g, '').replace(',', '.');
  return Math.round(Number(normalized) * 100);
}

export function parseCltOffers(text) {
  const offers = [];
  for (const line of String(text ?? '').split(/\r?\n/)) {
    const match = line.match(offerLine);
    if (!match) continue;

    offers.push({
      position: Number(match[1]),
      institution: match[2].trim(),
      installments: Number(match[3]),
      installment_amount: match[4],
      installment_amount_cents: moneyToCents(match[4]),
      released_amount: match[5],
      released_amount_cents: moneyToCents(match[5]),
    });
  }
  return offers
    .sort((left, right) => left.position - right.position)
    .slice(0, 5);
}

export function buildCltOfferList(offers) {
  const rows = offers.slice(0, 5).map((offer) => ({
    id: `clt_offer_${offer.position}`,
    title: `${offer.position} - ${offer.institution}`.slice(0, 24),
    description:
      `${offer.installments}x R$ ${offer.installment_amount} | ` +
      `Libera R$ ${offer.released_amount}`,
  }));

  rows.push({
    id: 'clt_other_amount',
    title: 'Outro valor',
    description: 'Quero verificar outra condição',
  });

  return {
    type: 'list',
    header: 'Ofertas de Crédito CLT',
    body: 'Encontramos estas opções para você. Escolha uma oferta para continuar:',
    button: 'Ver ofertas',
    sections: [{ title: 'Opções disponíveis', rows }],
  };
}
