# BKL-018 — Runbook de autenticação e perfis locais

## Limites

- Supabase local em `127.0.0.1`;
- usuários e dados exclusivamente sintéticos;
- nenhuma credencial real, conexão remota, Appsmith ou deploy;
- `service_role` não é identidade humana final;
- perfis técnicos da BKL-016 não são atribuíveis a humanos.

## Modelo

`public.user_profiles` continua vinculado a `auth.users.id` e passa a ter:

- papel humano: `admin`, `operations`, `support` ou `auditor`;
- estado: `ACTIVE`, `DISABLED` ou `PENDING_REVIEW`;
- referências técnicas de quem alterou papel/estado;
- compatibilidade controlada entre `active` e `status`.

Somente `ACTIVE` é aceito pelos helpers de RLS. Perfil pendente ou desativado
pode consultar apenas seu UUID, papel e estado por `get_my_profile()`.

## Operações controladas

- `admin_create_human_profile`;
- `admin_change_human_role`;
- `admin_disable_human_profile`;
- `admin_reactivate_human_profile`;
- `get_my_profile`.

As funções usam `SECURITY DEFINER`, `search_path = ''`, validação de códigos e
grants mínimos. `user_profiles` não oferece DML direto a papéis web, nem mesmo
ao admin. O bootstrap inicial continua sendo uma atividade administrativa fora
do navegador e não usa `service_role` como usuário final.

## Auditoria provisória

A BKL-018 reutiliza `audit.events` apenas para criação, alteração de papel,
desativação, reativação e tentativa negada de elevação. Os eventos contêm UUID
técnico, códigos e versão do processo, nunca PII ou segredo. A trilha canônica
completa permanece na BKL-020.

## Validação local

```powershell
supabase start
supabase db reset
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" `
  -v ON_ERROR_STOP=1 -f supabase/tests/bkl018_auth_profiles_test.sql
```

O teste de identidade backend deve ser executado como `supabase_admin`, pois os
papéis técnicos são `NOLOGIN` e deliberadamente não são concedidos a `postgres`.

## Rollback

O rollback recusa execução (`SQLSTATE 55000`) quando existe auditoria do modelo
`BKL018_HUMAN_PROFILE_V1` ou estado não representável. Em base limpa, restaura
os helpers, policies e grants anteriores. Depois, `supabase db reset` comprova
a reaplicação integral.

## Produção

Esta fase não autoriza usuário real, Appsmith ou produção. Antes disso ainda são
necessários bootstrap, recuperação administrativa, MFA, sessões, convites e
revisão independente.
