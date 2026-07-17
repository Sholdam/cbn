# Relatório local — BKL-018 autenticação, perfis e permissões

## Resultado

Implementação local concluída na branch
`codex/bkl-018-auth-profiles-local`, sem merge ou deploy.

Entregas:

- migration incremental `20260722_001_bkl018_auth_profiles.sql`;
- rollback fail-closed correspondente;
- estados `ACTIVE`, `DISABLED` e `PENDING_REVIEW`;
- quatro RPCs administrativas e consulta mínima do próprio perfil;
- DML direto em `user_profiles` removido dos papéis web;
- helpers de RLS limitados a perfil ativo;
- auditoria provisória sem PII;
- matriz de permissões e runbook.

## Testes executados

- BKL-018 focada: aprovada;
- RLS-base BKL-016 afetada: aprovada;
- identidade backend BKL-016: aprovada como `supabase_admin` local;
- rollback com auditoria nova: recusado com fail-closed;
- rollback em base limpa: aprovado;
- reaplicação por `supabase db reset`: aprovada;
- reaplicação da suíte BKL-018: aprovada;
- suíte Node completa: **44/44 testes aprovados**;
- `git diff --check`: aprovado;
- validador BKL-016: aprovado sem regressão;
- stack local: removida com `supabase stop --no-backup`.

Os testes cobrem os 22 cenários mínimos solicitados, incluindo ausência de
perfil, estados inativos, gestão por admin, recusas a outros papéis,
autoelevação, papel técnico, DML direto, conteúdo mascarado, schemas privados,
auditoria, rollback e reaplicação.

## Segurança e limites

- oito usuários Auth sintéticos, sem senha utilizável e com domínio inválido,
  existiram apenas dentro de transação revertida;
- nenhum e-mail foi copiado para tabela operacional;
- nenhum segredo, PII, JWT ou credencial externa foi versionado;
- nenhum acesso remoto, Appsmith, Railway, n8n, Telegram ou KMS;
- `telegram-gateway/` e `.env.example` permaneceram inalterados.

## Riscos restantes

- bootstrap e recuperação do primeiro admin ainda exigem desenho operacional;
- convite, MFA, expiração/revogação de sessões e Appsmith ficam para fase futura;
- auditoria canônica será implementada na BKL-020;
- revisão independente é obrigatória antes de usuário real ou produção.
