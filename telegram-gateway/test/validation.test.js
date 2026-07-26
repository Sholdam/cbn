import test from 'node:test';
import assert from 'node:assert/strict';
import {
  normalizeBrazilianPhone,
  normalizeCpf,
  sanitizeTelegramText,
  validateOperationId,
} from '../src/validation.js';

test('normaliza CPF sintético formatado e rejeita dígitos inválidos', () => {
  assert.equal(normalizeCpf('123.456.789-09'), '12345678909');
  assert.throws(() => normalizeCpf('11111111111'), /CPF_INVALID/);
  assert.throws(() => normalizeCpf('12345678900'), /CPF_INVALID/);
});

test('remove o código do Brasil e preserva DDD e celular', () => {
  assert.equal(normalizeBrazilianPhone('+55 (11) 90000-0000'), '11900000000');
  assert.equal(normalizeBrazilianPhone('(27) 3000-0000'), '2730000000');
  assert.throws(() => normalizeBrazilianPhone('9000'), /PHONE_INVALID/);
});

test('mascara CPF e telefone se o bot os repetir', () => {
  const text = sanitizeTelegramText(
    'CPF 123.456.789-09 telefone (11) 90000-0000',
    { cpf: '12345678909', phone: '11900000000' }
  );
  assert.equal(text, 'CPF [DADO_PROTEGIDO] telefone [DADO_PROTEGIDO]');
});

test('operation_id aceita contrato estável e rejeita texto livre', () => {
  assert.equal(validateOperationId('CBN-CLT-20260726-0001'), 'CBN-CLT-20260726-0001');
  assert.throws(() => validateOperationId('curto'), /OPERATION_ID_INVALID/);
  assert.throws(() => validateOperationId('id com espaço sensível'), /OPERATION_ID_INVALID/);
});
