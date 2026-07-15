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

A **BKL-016** está em revisão técnica na branch `codex/bkl-016-secure-storage`. A migration, o rollback e os testes de RLS foram preparados com dados sintéticos, mas ainda não foram executados em Supabase local nem aplicados em ambiente real.

BKL-012 e BKL-013 permanecem tarefas vivas paralelas. Nenhuma proposta real pode ser confirmada sem autorização expressa e evidência protegida válida.

Veja o checkpoint completo em [`docs/HANDOFF.md`](docs/HANDOFF.md).

## Estrutura

- `docs/` — handoff, arquitetura, backlog e pesquisas.
- `supabase/` — migration, seed sintético, rollback manual e testes de RLS da BKL-016.
- `scripts/validate-bkl016.ps1` — validação estática de estrutura, máscaras, segredos e dados pessoais.
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
