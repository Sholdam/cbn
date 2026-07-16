# BKL-016 — Runbook de validação remota em desenvolvimento

**Status:** migration corretiva, validação SQL e runtime real de objeto/URL assinada concluídos; KMS e restauração pendentes
**Data:** 15/07/2026
**Ambiente permitido:** projeto Supabase exclusivo de desenvolvimento, vazio e sem dados reais

## Limite desta execução

O runbook foi inicialmente preparado sem acesso remoto. Após a primeira autorização explícita, a CLI foi autenticada localmente, o projeto `cbn-dev` foi confirmado duas vezes pelo ref não secreto e o `supabase link` foi concluído. O marcador local corresponde ao alvo confirmado e permanece ignorado pelo Git.

A inspeção somente leitura mostrou histórico remoto de migrations vazio, migration local `20260715` pendente e nenhuma tabela reportada pelo inspetor. Após autorização separada, `supabase db push --dry-run --linked` terminou sem escrita e listou somente `20260715_001_bkl016_secure_storage.sql`.

Após uma terceira autorização explícita, `supabase db push --linked` aplicou somente essa migration, sem `--include-seed`. O histórico local/remoto passou a mostrar `20260715` nos dois lados e o inspetor reportou as 13 tabelas esperadas em `public`, `app_private` e `audit`. Os avisos `IF EXISTS` eram esperados para um projeto vazio. Nenhum usuário, fixture ou dado foi criado. A listagem de Storage pela CLI não ficou disponível; buckets e policies continuam pendentes de comprovação pelo validador SQL.

## Diagnóstico registrado

| Componente | Resultado |
|---|---|
| Branch | `codex/bkl-016-remote-dev` |
| Commit inicial | `3c7905e docs: add Codex prompt for BKL-016 remote development` |
| Docker | 29.6.1 |
| Docker Compose | 5.3.0 |
| Supabase CLI | 2.109.1 |
| psql | 17.10 |
| Autenticação Supabase CLI | ativa, realizada interativamente pelo usuário |
| Projeto de desenvolvimento identificável | `cbn-dev`, alvo confirmado duas vezes; ref omitido no documento |
| Vínculo local | presente, correspondente ao alvo e ignorado pelo Git |
| Schemas expostos localmente | `app_private` e `audit` não aparecem em `api.schemas` |

`supabase db push --help` confirmou que a CLI instalada oferece `--dry-run`. Nenhuma conexão remota foi iniciada para essa verificação.

## Controles preparados

- `scripts/supabase-remote-preflight.ps1` bloqueia branch incorreta, árvore suja, ambiente sem marcador, alvo vazio ou de produção conhecido, dados não confirmados como sintéticos, vínculo sem confirmação, migration sem dry-run revisado, `.env` versionado, padrões de segredo/CPF e schema privado exposto.
- `scripts/supabase-remote-validate.ps1` exige todos os controles, vínculo local correspondente e credencial PostgreSQL somente em memória. O modo recomendado pede a senha em entrada oculta e combina com o pooler local ignorado, sem imprimir ou persistir o valor. Ele executa verificações estruturais e depois a suíte transacional que termina em `ROLLBACK`.
- `scripts/supabase-remote-cleanup.ps1` aceita apenas um manifesto ignorado em `supabase/.temp`, IDs explícitos e objetos com bucket permitido e nome UUID/hash. A limpeza exige uma segunda confirmação e aborta se o registro não tiver marcador sintético.
- `supabase/tests/bkl016_remote_validation.sql` verifica migration, RLS, papéis, grants, funções, PostgREST, buckets, policies, integridades, snapshot, auditoria e padrões aparentes de dado real ou segredo.

O preflight possui fases diferentes para evitar uma dependência circular:

- `LinkInspection`: permite ausência de vínculo e não exige dry-run, pois nenhuma escrita é autorizada;
- `RemoteWrite`, `RemoteValidation` e `Cleanup`: exigem vínculo correspondente e confirmação de que o dry-run foi revisado.

O modo padrão é `RemoteWrite`, portanto executar o script sem parâmetros falha de forma segura.

## Primeira parada obrigatória — concluída

Não executar ainda `supabase link`, `supabase db push`, SQL remoto, criação de usuário ou upload.

O usuário deve:

1. criar ou selecionar no painel um projeto exclusivo de desenvolvimento, com nome claramente marcado como desenvolvimento, por exemplo `cbn-dev`;
2. confirmar a organização e escolher conscientemente a região;
3. usar senha forte de banco e guardá-la em cofre local, fora do Git e do chat;
4. confirmar que o projeto não possui dados reais nem integração com n8n, Appsmith ou outro sistema;
5. autenticar a Supabase CLI localmente de forma interativa, se desejar, sem enviar token ao chat;
6. informar somente que o projeto foi criado e o **project ref não secreto**.

A criação do projeto, autenticação local e autorização do vínculo foram concluídas sem compartilhar senha, URL de banco, token, JWT, `service_role` ou chave.

## Segunda parada obrigatória — concluída

O usuário autorizou exclusivamente o dry-run. O comando foi executado sem `--include-seed`, não alterou o banco e apresentou somente a migration BKL-016 esperada.

## Terceira parada obrigatória — concluída

O usuário autorizou somente a migration BKL-016, sem seed. A aplicação e a verificação de leitura foram concluídas sem criar dados.

## Quarta parada obrigatória — concluída

A validação recebeu autorização explícita e usou conexão PostgreSQL somente em memória, com entrada de senha oculta. Nenhum usuário Auth foi criado e nenhuma credencial foi enviada ao chat ou persistida.

### Resultado da primeira tentativa autorizada

O teste estrutural remoto parou antes da suíte de fixtures com `anon possui grant operacional inesperado`. Nenhuma fixture foi iniciada ou persistida. A causa é compatível com default privileges do projeto remoto, que diferem do ambiente local.

A correção foi preparada em duas camadas:

- a migration-base passou a revogar explicitamente todas as permissões das tabelas operacionais de `PUBLIC` e `anon`, protegendo instalações novas;
- `20260716_001_bkl016_revoke_anon_operational_grants.sql` faz o hardening idempotente do projeto já migrado e reafirma somente os grants de `authenticated` previstos.

Essa migration corretiva não altera dados ou policies. O dry-run listou exclusivamente `20260716_001_bkl016_revoke_anon_operational_grants.sql`; a aplicação sem seed foi concluída e o histórico local/remoto passou a coincidir em `20260715` e `20260716`.

### Resultado da repetição integral

Os testes terminaram com `BKL-016 remote structural checks passed` e `BKL-016 database and RLS checks passed`. As fixtures sintéticas foram revertidas pelo `ROLLBACK`, e a inspeção final reportou zero linhas estimadas nas 13 tabelas. Os quatro buckets privados foram listados e as verificações SQL confirmaram ausência de acesso/policy pública. A CLI experimental recusou o upload sintético com `Unsupported operation` antes da criação; nenhum objeto persistiu e URL assinada não foi testada.

O painel do projeto confirmou plano Free, sem backup agendado; PITR aparece como adicional do Pro. O dump manual somente de schema passou na varredura de dados/segredos e foi removido. Restauração, KMS/cofre, retenção e legal hold continuam pendentes.

## Continuação autorizada — inspeção antes do vínculo

Somente depois da confirmação manual, definir na sessão local:

```powershell
$env:CBN_ENVIRONMENT = 'development'
$env:SUPABASE_PROJECT_REF = '<project-ref-nao-secreto>'
```

Se existir qualquer projeto de produção conhecido, registrar os refs correspondentes apenas na variável local `CBN_PRODUCTION_PROJECT_REFS`, separados por vírgula. Não versionar essa lista.

Executar o gate sem escrita:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\scripts\supabase-remote-preflight.ps1 `
  -Phase LinkInspection `
  -RemoteTargetConfirmed `
  -SyntheticDataConfirmed
```

Se passar, conferir novamente no painel e somente então vincular ao ref confirmado:

```powershell
supabase link --project-ref $env:SUPABASE_PROJECT_REF
```

Não fornecer senha em argumento. Se a CLI pedir autenticação, ela deve ocorrer interativamente no terminal local.

## Inspeção e dry-run

Depois do vínculo autorizado:

1. confirmar branch e árvore limpa;
2. verificar que o marcador local coincide com o ref confirmado, sem imprimir o valor no relatório;
3. inspecionar o histórico de migrations e o schema remoto sem alterar;
4. confirmar que o projeto está vazio ou compatível com a aplicação inicial;
5. executar apenas:

```powershell
supabase db push --dry-run
```

Revisar a migration `20260715_001_bkl016_secure_storage.sql`, grants, policies, funções `SECURITY DEFINER` e criação dos quatro buckets. Parar novamente se houver objeto inesperado, divergência de migration, remoção ou risco de perda.

Antes de qualquer `db push` real, executar:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\scripts\supabase-remote-preflight.ps1 `
  -Phase RemoteWrite `
  -RemoteTargetConfirmed `
  -SyntheticDataConfirmed `
  -MigrationDryRunReviewed
```

Mesmo com o preflight aprovado, o `db push` exige nova autorização humana explícita.

## Aplicação e validação futuras

Não executar `supabase/seed.sql` no projeto remoto. A suíte SQL cria fixtures exclusivamente sintéticas dentro de uma transação e termina com `ROLLBACK`.

A credencial pode existir somente em memória. O modo recomendado é `-PromptForDatabasePassword`, que lê o endereço sem senha de `supabase/.temp/pooler-url` e pede a senha em entrada oculta. Como alternativa automatizada, a URL completa pode existir somente na variável de processo `CBN_REMOTE_DATABASE_URL`. Não colocar senha ou URL em comando, arquivo versionado, log ou relatório.

Depois de migration autorizada e aplicada:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\scripts\supabase-remote-validate.ps1 `
  -RemoteTargetConfirmed `
  -SyntheticDataConfirmed `
  -MigrationDryRunReviewed `
  -PromptForDatabasePassword
```

Marcadores finais esperados:

- `BKL-016 remote structural checks passed`;
- `BKL-016 database and RLS checks passed`;
- `BKL-016 remote validation passed`.

O validador cobre `anon`, authenticated sem perfil, support, operations, auditor, admin, acesso privado, `SECURITY DEFINER`, grants, buckets, policy pública, integridades, evidência final, snapshot e auditoria append-only. A exposição dos schemas deve também ser conferida no painel de API, porque uma configuração externa ao banco pode não aparecer em `pg_db_role_setting`.

## Storage sintético

### Runtime backend executado

O runtime usa `scripts/supabase-storage-runtime-run.ps1`, que encadeia o preflight, o teste Node.js e a validação SQL remota já existente. A dependência oficial `@supabase/supabase-js` está isolada em `scripts/package.json` e fixada em `2.110.6`; ela não altera o aplicativo principal.

Antes do gate, execute somente o preflight sanitizado com os mesmos parâmetros seguros já confirmados. Ele exige a branch `codex/bkl-016-storage-runtime`, `development`, árvore limpa, branch não atrasada da `main`, vínculo coerente, migrations reconciliadas e bucket temporário existente. A migration versionada também fixa esse bucket como privado. O teste autenticado repete a verificação de privacidade antes do upload e para sem criar objeto se ela falhar.

### Gate humano de credencial backend

A variável efêmera reservada é `CBN_SUPABASE_BACKEND_KEY`. O operador deve obter no painel do projeto isolado `cbn-dev` uma chave secreta de API apropriada exclusivamente a backend. Não cole o valor no chat e não o salve em `.env`, perfil, script, screenshot, relatório ou histórico do shell.

O método recomendado é manter apenas `CBN_SUPABASE_URL` na sessão atual e iniciar o wrapper com `-PromptForBackendCredential`; a entrada fica oculta e o wrapper coloca a chave em `CBN_SUPABASE_BACKEND_KEY` somente dentro do processo, limpa a memória nativa usada pelo prompt e remove as duas variáveis do processo ao terminar. Não passe chave em argumento de linha de comando.

Comando reservado para depois de confirmação explícita do operador; **não executar durante a preparação**:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\scripts\supabase-storage-runtime-run.ps1 `
  -RemoteTargetConfirmed `
  -SyntheticDataConfirmed `
  -MigrationDryRunReviewed `
  -PromptForBackendCredential
```

O runtime usa objeto UUID e conteúdo `BKL016_STORAGE_SYNTHETIC_ONLY` acrescido de aleatoriedade, tudo em memória. A URL assinada nominal é de 30 segundos, com margem padrão de 5 segundos e tolerância total máxima de 15 segundos. Só serão documentados tempo observado, classe HTTP, tamanho e SHA-256; URL, token e identificadores ficam omitidos.

O preflight sanitizado passou com migrations conciliadas e bucket temporário localizado. Após o gate humano, os seis marcadores finais foram atingidos: upload de 94 bytes, acesso anônimo `4xx`, download pré-expiração com SHA-256 idêntico, falha `4xx` após 36 segundos para TTL nominal de 30 segundos, limpeza confirmada e revalidação SQL `complete/passed`. A listagem recursiva final encontrou zero objetos. URL assinada, chave, senha e project-ref permaneceram omitidos.

Se for necessário validar URL assinada, criar somente um objeto descartável com conteúdo inerte, nome UUID/hash e bucket privado. Não persistir a URL. Registrar bucket e nome exatos no manifesto local de limpeza antes do upload.

`anon` e `support` não devem receber acesso direto. Nenhuma policy pública ou policy definitiva de produção será criada nesta tarefa.

## Manifesto e limpeza

O manifesto deve ficar em `supabase/.temp/bkl016-remote-cleanup.json`, nunca ser versionado, e usar esta estrutura:

```json
{
  "marker": "BKL016_SYNTHETIC_REMOTE_DEV",
  "projectRef": "<project-ref-nao-secreto>",
  "authUserIds": [],
  "clientIds": [],
  "operationIds": [],
  "consultationIds": [],
  "offerIds": [],
  "proposalIds": [],
  "interactionIds": [],
  "pendingItemIds": [],
  "protectedPayloadIds": [],
  "protectedFileRefIds": [],
  "storageObjects": []
}
```

Cada criação persistente deve ser registrada imediatamente. A limpeza aceita somente IDs UUID explícitos, usuários `@example.invalid`, clientes com prefixo `[SYNTHETIC REMOTE BKL-016]`, aliases sintéticos e objetos nos quatro buckets permitidos.

Com autorização separada:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\scripts\supabase-remote-cleanup.ps1 `
  -ManifestPath .\supabase\.temp\bkl016-remote-cleanup.json `
  -RemoteTargetConfirmed `
  -SyntheticDataConfirmed `
  -MigrationDryRunReviewed `
  -CleanupApproved
```

Depois, executar novamente o validador remoto e confirmar que o projeto continua isolado e sem integrações.

## Decisão pendente de KMS/cofre

Nenhuma chave será criada nesta tarefa. A decisão será tomada antes de integrar n8n/Gateway, comparando no máximo estas três opções:

| Opção | Vantagem principal | Custo/risco principal |
|---|---|---|
| KMS gerenciado do provedor de nuvem escolhido, com envelope encryption | rotação, auditoria e segregação maduras | custo e dependência do provedor |
| HashiCorp Vault Transit | controle e portabilidade | operação, disponibilidade e recuperação ficam sob responsabilidade da CBN |
| serviço de secrets gerenciado com criptografia feita no Gateway | implantação inicial simples | rotação e uso criptográfico exigem desenho adicional e nunca podem alcançar o navegador/Appsmith |

Critérios de decisão: custo comprovado, simplicidade, rotação, recuperação, integração backend, separação desenvolvimento/produção, portabilidade e prevenção de exposição. A recomendação atual é KMS gerenciado com envelope encryption; provedor, custo e criação de chave dependem de aprovação e revisão independente.

## Backup, restauração e retenção

O painel do `cbn-dev` confirmou plano Free: backup agendado não está incluído e PITR aparece como adicional do Pro. Portanto não há backup gerenciado ativo a afirmar.

Um dump manual somente dos schemas BKL-016 foi gerado, validado sem registros/credenciais e removido. Restauração não foi executada porque não há backup gerenciado nem alvo descartável separado nesta fase. Prazo de retenção, anonimização e `legal hold` continuam pendentes de validação jurídica.

## Checklist antes de encerrar a fase remota

- [x] projeto isolado confirmado duas vezes;
- [x] dry-run revisado e segunda autorização registrada;
- [x] migration aplicada sem seed remoto;
- [x] validação SQL remota completa aprovada;
- [x] buckets privados e ausência de policy pública confirmados;
- [x] nenhuma fixture ou objeto sintético persistente ao final;
- [x] validador concluiu após o `ROLLBACK` e a inspeção final confirmou zero linhas;
- [x] backup/restauração testados ou pendência fundamentada;
- [x] decisão de KMS aprovada ou pendência registrada;
- [x] nenhum dado real, segredo, `.env`, n8n ou Appsmith;
- [x] nenhuma alteração em `telegram-gateway/`;
- [x] nenhum merge na `main`.
