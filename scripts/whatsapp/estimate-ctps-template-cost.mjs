import { pathToFileURL } from 'node:url';

export const BRAZIL_MARKETING_RATE_USD = 0.0625;
export const REFERENCE_USD_BRL = 5.0666;
export const REFERENCE_EXCHANGE_DATE = '2026-07-24';

function positiveNumber(value, name) {
  const number = Number(value);
  if (!Number.isFinite(number) || number < 0) {
    throw new Error(`${name} deve ser um número não negativo.`);
  }
  return number;
}

export function estimateCtpsTemplateCost({
  deliveredMessages,
  usdBrl = REFERENCE_USD_BRL,
  rateUsd = BRAZIL_MARKETING_RATE_USD,
}) {
  const delivered = positiveNumber(deliveredMessages, 'deliveredMessages');
  const exchange = positiveNumber(usdBrl, 'usdBrl');
  const rate = positiveNumber(rateUsd, 'rateUsd');

  return {
    deliveredMessages: delivered,
    category: 'MARKETING',
    market: 'Brazil',
    rateUsdPerDeliveredMessage: rate,
    estimatedUsd: Number((delivered * rate).toFixed(4)),
    usdBrl: exchange,
    estimatedBrl: Number((delivered * rate * exchange).toFixed(2)),
    excludes: ['impostos', 'spread cambial', 'eventual tarifa do provedor'],
  };
}

function argumentValue(name) {
  const prefix = `--${name}=`;
  const argument = process.argv.find((item) => item.startsWith(prefix));
  return argument?.slice(prefix.length);
}

function main() {
  const deliveredMessages = argumentValue('messages') ?? '1';
  const usdBrl = argumentValue('usd-brl') ?? REFERENCE_USD_BRL;
  console.log(
    JSON.stringify(
      {
        ...estimateCtpsTemplateCost({ deliveredMessages, usdBrl }),
        exchangeReferenceDate: REFERENCE_EXCHANGE_DATE,
        notice:
          'Estimativa. Confirme a tarifa vigente da Meta e o câmbio antes de cada campanha.',
      },
      null,
      2,
    ),
  );
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    main();
  } catch (error) {
    console.error(`Falha ao estimar o custo: ${error.message}`);
    process.exitCode = 1;
  }
}
