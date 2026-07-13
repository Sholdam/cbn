# Telegram Gateway CBN — provas de conceito

Este diretório contém testes controlados para validar a rota MTProto.

## Preparação

```bash
npm install --registry=https://registry.npmjs.org/
cp .env.example .env
```

No PowerShell com execução de scripts bloqueada, use `npm.cmd`.

Preencha o `.env` local. Nunca envie o arquivo ao GitHub.

## Gerar sessão

```bash
npm run auth
```

Copie a string gerada para `TELEGRAM_SESSION` no `.env` ou para o cofre de secrets.

## Testar persistência

```bash
npm run check
```

Feche totalmente o processo, abra outro terminal e execute novamente. O teste passa quando a conta conecta sem novo código de login.

## Testar idempotência

Fase 1:

```bash
npm run idempotency:first
```

Feche o processo, abra outro terminal e execute:

```bash
npm run idempotency:retry
```

O resultado esperado é exatamente uma mensagem enviada para a operação.

Para reiniciar o teste:

```bash
npm run idempotency:reset
```

## Limites

Use somente comando seguro, como `menu`. Não usar CPF e não criar proposta durante as provas técnicas.
