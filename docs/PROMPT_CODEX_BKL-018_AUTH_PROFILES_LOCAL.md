# Prompt executado — BKL-018 autenticação e perfis locais

**Nível de esforço: ALTO**

Implementar em `codex/bkl-018-auth-profiles-local`, sem merge ou deploy, a
fundação local de perfis humanos `admin`, `operations`, `support` e `auditor`.

Requisitos centrais:

- preservar os quatro papéis técnicos `NOLOGIN` da BKL-016;
- vincular perfis exclusivamente a `auth.users.id`, sem copiar e-mail;
- suportar `ACTIVE`, `DISABLED` e `PENDING_REVIEW`;
- impedir autoatribuição, autoelevação, papel técnico em perfil humano e DML
  direto em `user_profiles`;
- administrar perfis somente por funções controladas e auditadas;
- negar operação a usuário sem perfil ativo;
- manter `anon`, `service_role` e perfis humanos fora de tabelas privadas;
- usar somente fixtures sintéticas e Supabase local descartável;
- criar migration incremental, rollback fail-closed, testes, runbook, matriz e
  relatório;
- executar primeiro os testes afetados e a suíte Node completa somente uma vez
  no fechamento;
- não conectar Appsmith, Railway, n8n, Telegram, KMS ou ambiente remoto.

Critério de aceite: migration, RLS, funções, auditoria mínima, rollback limpo,
recusa fail-closed e reaplicação aprovados; branch publicada sem merge/deploy.
