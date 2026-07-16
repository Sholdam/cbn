# Prompt executado — BKL-016 Retenção e legal hold

Implementar, na branch `codex/bkl-016-retention-legal-hold`, uma camada
incremental e local para retenção, anonimização, exclusão segura e legal hold.

Regras obrigatórias:

- dados exclusivamente sintéticos e stack Supabase descartável;
- nenhum prazo jurídico definitivo embutido no código;
- políticas configuráveis e inicialmente sujeitas a revisão;
- legal hold bloqueando anonimização, banco e Storage;
- anonimização transacional, idempotente e sem descriptografia;
- exclusão física somente com IDs explícitos, lote máximo pequeno e confirmação
  `CBN_RETENTION_DELETE_CONFIRMED=synthetic-local-explicit-ids`;
- inventário antes do descarte e conclusão somente após comprovar ausência do
  objeto Storage;
- auditoria append-only apenas com códigos e IDs técnicos;
- rollback fail-closed quando existir qualquer estado novo;
- testes de RLS, constraints, backup pós-anonimização, Storage e reaplicação;
- não acessar Supabase remoto, produção, Railway, n8n, Appsmith, Telegram,
  Google Cloud KMS, billing ou credencial externa;
- não alterar `telegram-gateway/` nem `.env.example`;
- não fazer merge.

Entregar migration e rollback `20260718`, testes SQL e Node, runtime local,
runbook, relatório, validação estática, commit e push da branch. A BKL-016 deve
permanecer **Em andamento**.
