# Instruções para Codex — CBN

Este repositório é a fonte oficial do projeto. Antes de agir:

1. Confirme `git branch --show-current`, `git status` e `git log -1 --oneline`.
2. Na retomada normal, use a branch `main` atualizada a partir de `origin/main`.
3. Leia, nesta ordem:
   - `README.md`;
   - `docs/HANDOFF.md`;
   - `docs/BACKLOG_CHECKPOINT.md`;
   - `docs/ARQUITETURA_TECNICA.md`;
   - o runbook específico da tarefa atual.
4. Preserve todo trabalho existente e crie branch `codex/<tarefa>` para mudanças.
5. Não faça merge, deploy ou alteração remota sem autorização expressa do usuário.

## Checkpoint atual

- BKL-018: fundação local de autenticação e perfis concluída e integrada.
- Próxima tarefa principal: BKL-020, trilha de auditoria canônica no PostgreSQL.
- BKL-016 geral continua Em andamento nos gates externos descritos no handoff.
- BKL-007, BKL-011, BKL-012 e BKL-013 continuam vivas como tarefas de produto.

## Segurança obrigatória

- Somente dados sintéticos até autorização explícita dos gates de produção.
- Nunca versionar `.env`, senhas, tokens, sessões Telegram, JWTs, chaves, URLs assinadas ou dados reais.
- Não usar `service_role` como identidade operacional ou humana.
- Não alterar migrations já aplicadas; usar migration incremental.
- Não alterar `telegram-gateway/` ou `.env.example` fora de tarefa explicitamente relacionada.
- Preserve RLS, menor privilégio, idempotência e comportamento fail-closed.

## Classificação de esforço

Informe ao usuário o nível antes de delegar uma tarefa ao Codex:

- Médio;
- Alto;
- Extralto;
- Ultra.

Use o menor nível compatível com o risco. Reutilize a implementação existente, rode primeiro os testes afetados e execute a suíte completa apenas uma vez antes do commit quando isso for suficiente.

## Estado e documentação

Ao concluir uma etapa:

- atualize `docs/HANDOFF.md` e `docs/BACKLOG_CHECKPOINT.md`;
- registre evidências e riscos sem PII ou segredos;
- valide `git diff --check` e os validadores aplicáveis;
- faça commit e push na branch;
- não declare teste não executado como aprovado.
