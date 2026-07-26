# Telegram Gateway CBN

Este diretório contém:

- provas controladas da rota MTProto;
- Gateway interno serializado para consultas CLT;
- validação de CPF e telefone;
- callback fixo para o n8n registrar o retorno como nota privada no Chatwoot.

O Gateway processa somente uma operação por vez na sessão CLT. CPF e telefone
permanecem apenas em memória durante a consulta e não são gravados em arquivos ou
logs.

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

## Executar o Gateway CLT

Preencha somente no ambiente seguro as variáveis novas documentadas no
`.env.example`. Depois:

```bash
npm test
npm start
```

Endpoints:

- `GET /health`: saúde sem dados sensíveis;
- `POST /v1/clt/simulations`: enfileira uma consulta;
- `GET /v1/operations/:operation_id`: consulta apenas metadados do estado.

O endpoint de consulta exige `x-gateway-key` e recebe:

```json
{
  "operation_id": "CBN-CLT-EXEMPLO-0001",
  "conversation_id": 123,
  "cpf": "CPF_RECEBIDO_NO_FLUXO",
  "phone": "TELEFONE_DO_CONTATO_NO_CHATWOOT"
}
```

O callback é enviado somente para `N8N_CALLBACK_URL`, com autenticação Bearer e
`idempotency-key`. Em sucesso, `result_text` contém a resposta do Telegram
sanitizada, `offers` contém até cinco ofertas estruturadas e `visibility` é
sempre `private`.

Consulte `../docs/CLT_TELEGRAM_GATEWAY_RUNBOOK.md`.

## Limites atuais

Use somente comando seguro, como `menu`. Não usar CPF e não criar proposta durante as provas técnicas.

O serviço CLT implementado é um piloto supervisionado. A fila e os dados em voo
ficam em memória; reinício durante uma consulta exige retry controlado pelo mesmo
`operation_id`. A persistência canônica de estados e locks pertence à BKL-024.
O pacote `telegram` atual está arquivado; a migração para `teleproto` deve ocorrer
antes da liberação de produção.
