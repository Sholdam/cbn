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

A **BKL-016** teve migration, seed, rollback e testes de RLS validados em Supabase local descartável. A preparação da fase remota está na branch `codex/bkl-016-remote-dev`; o projeto isolado `cbn-dev` foi vinculado e inspecionado somente para leitura, sem migration ou dado remoto.

BKL-012 e BKL-013 permanecem tarefas vivas paralelas. Nenhuma proposta real pode ser confirmada sem autorização expressa e evidência protegida válida.

Veja o checkpoint completo em [`docs/HANDOFF.md`](docs/HANDOFF.md) e a parada obrigatória em [`docs/BKL-016_REMOTE_DEV_RUNBOOK.md`](docs/BKL-016_REMOTE_DEV_RUNBOOK.md).

## Estrutura

- `docs/` — handoff, arquitetura, backlog e pesquisas.
- `supabase/` — migration, seed sintético, rollback manual e testes de RLS da BKL-016.
- `scripts/validate-bkl016.ps1` — validação estática de estrutura, máscaras, segredos e dados pessoais.
- `scripts/supabase-remote-*.ps1` — preflight, validação e limpeza sintética para futuro projeto remoto isolado.
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
