# BKL-016 — Runbook de identidade mínima do backend

## Auditoria localizada dos wrappers

A migration incremental `20260721_001_bkl016_backend_identity_audit.sql`
mantém papéis, grants e matriz inalterados e registra o modelo
`BKL016_BACKEND_IDENTITY_V1` somente depois do resultado do wrapper controlado.
Negações esperadas recebem `allowed=false`; falhas técnicas revertem a transação
e não produzem evento enganoso. O rollback incremental deve ser executado antes
do rollback `20260720_001` e recusa qualquer evento indispensável desse modelo.

## Estado e limites

Este runbook valida somente papéis PostgreSQL `NOLOGIN` em Supabase local.
Ele não cria login, senha, JWT, chave, credencial Railway ou identidade remota.
Dados reais e produção continuam proibidos.

## Preflight

1. estar na branch `codex/bkl-016-backend-identity`;
2. árvore sem alteração em `telegram-gateway/` ou `.env.example`;
3. nenhuma stack `supabase_db_cbn` preexistente;
4. nenhuma variável contendo alvo Supabase remoto;
5. Docker e Supabase CLI disponíveis;
6. confirmação exata:

```powershell
$env:CBN_BACKEND_IDENTITY_CONFIRMED='synthetic-local-role-test'
```

## Execução

```powershell
cd C:\Users\Daniely\Documents\CBN\scripts
npm.cmd test
npm.cmd run run:backend-identity-local
Remove-Item Env:CBN_BACKEND_IDENTITY_CONFIRMED
```

O runtime:

1. recusa branch, confirmação, alvo ou stack incompatível;
2. inicia Supabase local e executa `supabase db reset`;
3. roda as suítes de banco, envelope, retenção e identidade;
4. cria auditoria sintética pelo Gateway, operador, revisor e executor e comprova
   que o rollback incremental recusa;
5. recria uma base limpa e comprova o rollback destrutivo permitido;
6. verifica que papéis/wrappers sumiram sem ampliar `anon`/`authenticated`;
7. reaplica todas as migrations e repete a suíte de identidade;
8. executa `supabase stop --no-backup` no `finally`.

## Modelo futuro de autenticação

Os papéis desta migration são grupos de autorização, não identidades de login.
A credencial real futura deve ser criada fora da migration, em tarefa separada,
e receber apenas o papel necessário. O Gateway não deve usar `service_role` como
identidade permanente. Appsmith, navegador, `anon` e `authenticated` não recebem
membership nem `EXECUTE` nos wrappers.

Até essa tarefa futura existir:

- `SET ROLE` é usado somente pelo administrador da stack descartável;
- nenhum segredo é persistido;
- nenhum papel CBN é usado remotamente;
- a migration `20260720` não deve ser aplicada fora de ambiente autorizado.

## Resposta a falhas

- `human_confirmation_required`: não prosseguir; refazer o gate humano.
- `preexisting_local_stack_rejected`: não tocar na stack; identificar o dono.
- `remote_environment_rejected`: limpar variáveis remotas antes de testar.
- `protected_path_modified`: revisar e preservar os caminhos protegidos.
- `backend_*_metadata_rejected`: corrigir somente códigos tipados; não inserir
  texto livre ou PII.
- rollback recusado: preservar o estado e realizar revisão humana.

## Rollback

O rollback `20260721_001` falha fechado se houver qualquer auditoria do modelo
`BKL016_BACKEND_IDENTITY_V1`. Depois dele, o rollback `20260720_001` falha
fechado se houver retenção/hold/
anonimização/descarte indispensável, membership inesperado ou objeto pertencente
a papel operacional. Em base limpa ele revoga funções, remove wrappers, revoga a
associação administrativa local e apaga os quatro papéis. Ele nunca concede
privilégio a `PUBLIC`, `anon` ou `authenticated`.
