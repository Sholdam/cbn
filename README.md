# CBN — Operação Autônoma de Crédito

Projeto da CBN para captação, atendimento, consulta e acompanhamento de crédito, começando por **FGTS** e **Crédito do Trabalhador (CLT)**.

## Estado atual

Em 12/07/2026, a rota provisória via **Telegram MTProto** foi validada localmente:

- conta autorizada e comunicação com o bot operacional;
- sessão persistente após encerrar e reabrir o processo;
- retry com o mesmo `operation_id` sem duplicar o comando;
- arquitetura manual com sessões separadas de CLT, FGTS e status já comprovada pelo operador.

A decisão técnica está registrada em [`docs/ARQUITETURA_TECNICA.md`](docs/ARQUITETURA_TECNICA.md).

## Próximo ponto de retomada

Retomar pela **BKL-012**: completar o mapeamento dos campos e validações da digitação de propostas FGTS e CLT, sem confirmar proposta real sem autorização expressa.

Veja o checkpoint completo em [`docs/HANDOFF.md`](docs/HANDOFF.md).

## Estrutura

- `docs/` — handoff, arquitetura, backlog e pesquisas.
- `telegram-gateway/` — provas de conceito MTProto de persistência e idempotência.

## Segurança

Este repositório deve permanecer privado; ainda assim, é proibido versionar:

- `.env`;
- `TELEGRAM_API_HASH`;
- `TELEGRAM_SESSION`;
- senha 2FA ou código de login;
- tokens, webhooks privados ou credenciais do n8n;
- CPF, documentos, dados bancários ou dados de clientes.

Somente exemplos sem segredos podem entrar no GitHub.
