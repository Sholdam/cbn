# BKL-016 — Runbook de validação remota em desenvolvimento

**Status:** preparação local concluída; parada obrigatória ativa antes de qualquer vínculo ou alteração remota
**Data:** 15/07/2026
**Ambiente permitido:** projeto Supabase exclusivo de desenvolvimento, vazio e sem dados reais

## Limite desta execução

Este runbook foi preparado sem `supabase link`, `db push`, migration remota, usuário remoto ou objeto remoto. A CLI não está autenticada, nenhum projeto foi selecionado e não existe marcador local de vínculo em `supabase/.temp` ou `supabase/.branches`.

Os comandos das seções posteriores à parada são instruções para uma continuação autorizada. Eles não foram executados nesta etapa.

## Diagnóstico registrado

| Componente | Resultado |
|---|---|
| Branch | `codex/bkl-016-remote-dev` |
| Commit inicial | `3c7905e docs: add Codex prompt for BKL-016 remote development` |
| Docker | 29.6.1 |
| Docker Compose | 5.3.0 |
| Supabase CLI | 2.109.1 |
| psql | 17.10 |
| Autenticação Supabase CLI | inativa |
| Projeto de desenvolvimento identificável | não verificável sem autenticação; nenhum projeto foi escolhido |
| Vínculo local | ausente |
| Schemas expostos localmente | `app_private` e `audit` não aparecem em `api.schemas` |

`supabase db push --help` confirmou que a CLI instalada oferece `--dry-run`. Nenhuma conexão remota foi iniciada para essa verificação.

## Controles preparados

- `scripts/supabase-remote-preflight.ps1` bloqueia branch incorreta, árvore suja, ambiente sem marcador, alvo vazio ou de produção conhecido, dados não confirmados como sintéticos, vínculo sem confirmação, migration sem dry-run revisado, `.env` versionado, padrões de segredo/CPF e schema privado exposto.
- `scripts/supabase-remote-validate.ps1` exige todos os controles, vínculo local correspondente e conexão PostgreSQL guardada somente em variável de processo. Ele executa verificações estruturais sem imprimir a conexão e depois a suíte transacional que termina em `ROLLBACK`.
- `scripts/supabase-remote-cleanup.ps1` aceita apenas um manifesto ignorado em `supabase/.temp`, IDs explícitos e objetos com bucket permitido e nome UUID/hash. A limpeza exige uma segunda confirmação e aborta se o registro não tiver marcador sintético.
- `supabase/tests/bkl016_remote_validation.sql` verifica migration, RLS, papéis, grants, funções, PostgREST, buckets, policies, integridades, snapshot, auditoria e padrões aparentes de dado real ou segredo.

O preflight possui fases diferentes para evitar uma dependência circular:

- `LinkInspection`: permite ausência de vínculo e não exige dry-run, pois nenhuma escrita é autorizada;
- `RemoteWrite`, `RemoteValidation` e `Cleanup`: exigem vínculo correspondente e confirmação de que o dry-run foi revisado.

O modo padrão é `RemoteWrite`, portanto executar o script sem parâmetros falha de forma segura.

## PARADA OBRIGATÓRIA — ação manual

Não executar ainda `supabase link`, `supabase db push`, SQL remoto, criação de usuário ou upload.

O usuário deve:

1. criar ou selecionar no painel um projeto exclusivo de desenvolvimento, com nome claramente marcado como desenvolvimento, por exemplo `cbn-dev`;
2. confirmar a organização e escolher conscientemente a região;
3. usar senha forte de banco e guardá-la em cofre local, fora do Git e do chat;
4. confirmar que o projeto não possui dados reais nem integração com n8n, Appsmith ou outro sistema;
5. autenticar a Supabase CLI localmente de forma interativa, se desejar, sem enviar token ao chat;
6. informar somente que o projeto foi criado e o **project ref não secreto**.

A continuação exige autorização explícita. Senha, URL de banco, token, JWT, `service_role` e chaves não devem ser enviados.

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

A URL PostgreSQL com senha deve existir somente na variável de processo `CBN_REMOTE_DATABASE_URL`, preenchida por mecanismo seguro local. Não colocar o valor no comando, em arquivo, log ou relatório.

Depois de migration autorizada e aplicada:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\scripts\supabase-remote-validate.ps1 `
  -RemoteTargetConfirmed `
  -SyntheticDataConfirmed `
  -MigrationDryRunReviewed
```

Marcadores finais esperados:

- `BKL-016 remote structural checks passed`;
- `BKL-016 database and RLS checks passed`;
- `BKL-016 remote validation passed`.

O validador cobre `anon`, authenticated sem perfil, support, operations, auditor, admin, acesso privado, `SECURITY DEFINER`, grants, buckets, policy pública, integridades, evidência final, snapshot e auditoria append-only. A exposição dos schemas deve também ser conferida no painel de API, porque uma configuração externa ao banco pode não aparecer em `pg_db_role_setting`.

## Storage sintético

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

Critérios de decisão: custo comprovado, simplicidade, rotação, recuperação, integração backend, separação desenvolvimento/produção, portabilidade e prevenção de exposição. A opção final depende de aprovação do usuário e revisão independente.

## Backup, restauração e retenção pendentes

O projeto ainda não foi criado/confirmado, portanto o plano e os recursos disponíveis não foram comprovados. Não há afirmação de PITR ou backup gerenciado.

Após autorização, registrar evidência do plano no painel e preparar exportação/restauração somente de estruturas e fixtures sintéticas em ambiente separado. O dump não pode conter credencial embutida. Prazo de retenção, anonimização e `legal hold` continuam pendentes de validação jurídica.

## Checklist antes de encerrar a fase remota

- [ ] projeto isolado confirmado duas vezes;
- [ ] dry-run revisado e segunda autorização registrada;
- [ ] migration aplicada sem seed remoto;
- [ ] validação remota completa aprovada;
- [ ] buckets privados e ausência de policy pública confirmados;
- [ ] fixtures persistentes e objetos sintéticos removidos;
- [ ] validador reaprovado após limpeza;
- [ ] backup/restauração testados ou pendência fundamentada;
- [ ] decisão de KMS aprovada ou pendência registrada;
- [ ] nenhum dado real, segredo, `.env`, n8n ou Appsmith;
- [ ] nenhuma alteração em `telegram-gateway/`;
- [ ] nenhum merge na `main`.
