import test from 'node:test';
import assert from 'node:assert/strict';
import { buildCltOfferList, parseCltOffers } from '../src/clt-offers.js';

test('estrutura até cinco ofertas retornadas pelo Telegram', () => {
  const result = parseCltOffers(`
1 — Banco Alfa — 24x R$ 222,70 → R$ 2.511,07
2 — Financeira Beta — 24x R$ 286,32 → R$ 3.602,99
3 — Banco Gama — 18x R$ 300,00 → R$ 4.000,00
4 — Banco Delta — 12x R$ 400,00 → R$ 4.500,00
5 — Banco Épsilon — 10x R$ 500,00 → R$ 4.700,00
6 — Banco ignorado — 8x R$ 600,00 → R$ 4.800,00
`);

  assert.equal(result.length, 5);
  assert.deepEqual(result[0], {
    position: 1,
    institution: 'Banco Alfa',
    installments: 24,
    installment_amount: '222,70',
    installment_amount_cents: 22270,
    released_amount: '2.511,07',
    released_amount_cents: 251107,
  });
});

test('lista interativa inclui ofertas e Outro valor como última opção', () => {
  const offers = parseCltOffers(`
1 — Banco Alfa — 24x R$ 222,70 → R$ 2.511,07
2 — Financeira Beta — 24x R$ 286,32 → R$ 3.602,99
`);
  const list = buildCltOfferList(offers);
  const rows = list.sections[0].rows;

  assert.equal(list.type, 'list');
  assert.equal(rows.length, 3);
  assert.equal(rows[0].id, 'clt_offer_1');
  assert.equal(rows[1].id, 'clt_offer_2');
  assert.equal(rows[2].id, 'clt_other_amount');
  assert.equal(rows[2].title, 'Outro valor');
});
