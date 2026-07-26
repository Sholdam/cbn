import { createHash } from 'node:crypto';

export function deterministicRandomId(operationId, step) {
  const hash = createHash('sha256')
    .update(`${operationId}:${step}`, 'utf8')
    .digest();
  let value = hash.readBigInt64BE(0);
  if (value === 0n) value = 1n;
  return value;
}
