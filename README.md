# CBN — Operação Autônoma de Crédito

Repositório oficial do projeto CBN para captação, atendimento, consulta e acompanhamento de crédito, começando por **FGTS** e **Crédito do Trabalhador (CLT)**.

## Fonte oficial

A fonte oficial para continuar o projeto é:

- repositório: `https://github.com/Sholdam/cbn`
- branch estável: `main`
- handoff atual: [`docs/HANDOFF.md`](docs/HANDOFF.md)
- instruções para outro computador: [`docs/CONTINUAR_EM_OUTRO_COMPUTADOR.md`](docs/CONTINUAR_EM_OUTRO_COMPUTADOR.md)
- regras para o próximo Codex: [`AGENTS.md`](AGENTS.md)

Não continue o projeto a partir de ZIPs, Downloads ou cópias antigas. Clone a `main` do GitHub.

## Checkpoint oficial — 17/07/2026

Concluído e validado:

- Telegram MTProto: sessão persistente, comunicação com o bot e idempotência;
- BKL-016: banco e RLS, Storage privado, criptografia por envelope local, backup/restauração sintética, retenção/legal hold e identidades técnicas de menor privilégio;
- BKL-018: fundação local de autenticação, perfis humanos e permissões para `admin`, `operations`, `support` e `auditor`.

Próxima tarefa principal:

- **BKL-020 — trilha de auditoria canônica no PostgreSQL**.

Tarefas de produto que continuam vivas em paralelo:

- BKL-007 e BKL-011: regras e catálogo atualizados durante atendimentos;
- BKL-012: completar campos da proposta FGTS quando houver oferta autorizada;
- BKL-013: completar acompanhamento de proposta e pagamento.

A BKL-016 geral permanece **Em andamento** apenas nos pontos que dependem de decisões ou recursos externos: KMS real, aprovação jurídica dos prazos, estratégia remota de backup/produção e revisão técnica independente. Até esses gates serem aprovados, **dados reais e produção permanecem proibidos**.

## Estrutura

- `AGENTS.md` — instruções automáticas para o Codex que abrir este repositório.
- `docs/` — handoff, backlog, arquitetura, matrizes, runbooks e relatórios.
- `supabase/` — migrations incrementais, rollbacks, seed sintético e testes SQL.
- `scripts/` — validadores e runtimes locais controlados.
- `telegram-gateway/` — prova de conceito MTProto de persistência e idempotência.

## Segurança

É proibido versionar:

- `.env`;
- `TELEGRAM_API_HASH` ou `TELEGRAM_SESSION`;
- senha 2FA ou código de login;
- tokens, webhooks privados, JWTs ou credenciais;
- CPF, RG, documentos, dados bancários ou qualquer dado real de cliente;
- URLs assinadas e chaves criptográficas.

Dependências instaladas e estados temporários locais também não pertencem ao GitHub. Eles são recriados no novo computador.
