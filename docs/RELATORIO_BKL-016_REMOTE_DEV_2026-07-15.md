# Relatório de execução — BKL-016 em Supabase remoto de desenvolvimento

- **Data:** 15/07/2026
- **Repositório:** `Sholdam/cbn`
- **Branch:** `codex/bkl-016-remote-dev`
- **Ambiente remoto:** projeto isolado `cbn-dev`
- **Produção:** não acessada ou alterada
- **Seed remoto:** não executado
- **Merge/deploy em produção:** não realizado

## Ponto inicial deste relatório

> Preparação e diagnóstico concluídos. A execução parou obrigatoriamente antes de qualquer `supabase link`, `db push` ou acesso a projeto remoto.
>
> Branch: `codex/bkl-016-remote-dev`
>
> Commit local: `3e5b3d96eee62fb792a06d65c30d1d6720036e5f`
>
> Árvore Git limpa.

Este documento registra tudo o que foi executado a partir desse ponto.

## Resumo executivo

A fundação da BKL-016 foi aplicada somente no projeto Supabase isolado de desenvolvimento `cbn-dev`, sem seed, usuários reais, fixtures persistentes ou integrações externas. A primeira validação remota detectou um grant operacional indevido para `anon`, causado por privilégios padrão diferentes dos observados no ambiente local.

A correção foi implementada em duas camadas:

1. a migration-base passou a revogar explicitamente privilégios de `PUBLIC` e `anon`, protegendo instalações novas;
2. uma migration incremental corrigiu o projeto de desenvolvimento que já havia recebido a migration-base.

Depois da correção, a validação estrutural remota e a suíte transacional completa de banco/RLS passaram. Todas as fixtures foram revertidas por `ROLLBACK`, e a inspeção final indicou zero linhas estimadas nas 13 tabelas BKL-016.

A BKL-016 permanece **Em andamento** porque ainda faltam o teste real de objeto/URL assinada, restauração, escolha/aprovação do KMS, retenção/legal hold e revisão independente.

## 1. Preparação e diagnóstico

Foram confirmados:

- branch correta: `codex/bkl-016-remote-dev`;
- árvore Git limpa;
- ausência de vínculo remoto no início;
- metadados locais da CLI protegidos por `.gitignore`;
- schemas privados fora da exposição PostgREST;
- nenhuma alteração em `telegram-gateway/`, `.env.example`, seed ou rollback;
- nenhuma credencial inserida em comando, arquivo versionado ou conversa.

Versões registradas:

| Ferramenta | Versão |
|---|---:|
| Docker | 29.6.1 |
| Docker Compose | 5.3.0 |
| Supabase CLI | 2.109.1 |
| PostgreSQL `psql` | 17.10 |

Artefatos de segurança preparados:

- runbook remoto com gates de segurança;
- preflight fail-closed para branch, árvore Git, ambiente e alvo;
- validador remoto com saída sanitizada;
- conexão PostgreSQL somente em memória, com senha digitada em campo oculto;
- limpeza restrita a fixtures sintéticas e IDs explícitos;
- teste SQL estrutural remoto;
- varredura estática de segredos, CPF e dados reais aparentes.

## 2. Vinculação e inspeção somente leitura

Depois da criação manual do projeto `cbn-dev` e autenticação interativa da CLI:

- o vínculo foi feito com `supabase link --project-ref <project-ref omitido>`;
- nenhuma senha foi passada em argumento;
- o marcador local ignorado confirmou que o projeto vinculado era o alvo informado;
- o histórico remoto de migrations estava vazio;
- nenhuma tabela de aplicação foi encontrada;
- nenhum dado, usuário, fixture ou objeto foi criado nessa etapa.

## 3. Dry-run e aplicação da migration-base

O comando abaixo foi executado primeiro em simulação:

```powershell
supabase db push --dry-run --linked
```

Resultado: somente a migration esperada foi listada:

```text
20260715_001_bkl016_secure_storage.sql
```

Depois da revisão, foi executado:

```powershell
supabase db push --linked
```

Resultado:

- migration-base aplicada com sucesso;
- seed não executado;
- histórico local/remoto conciliado em `20260715`;
- 13 tabelas BKL-016 reportadas;
- nenhuma linha, usuário ou fixture criada.

## 4. Preparação segura da validação PostgreSQL

O validador remoto foi alterado para:

- ler o endereço do pooler local ignorado, sem imprimir seu conteúdo;
- solicitar somente a senha em entrada oculta com `Read-Host -AsSecureString`;
- manter `PGPASSWORD` apenas no processo;
- liberar a memória nativa usada na conversão da senha;
- restaurar as variáveis de ambiente ao final;
- registrar somente fase, resultado e categoria segura em arquivo temporário ignorado;
- classificar separadamente falhas de autenticação, conexão, estrutura e execução SQL;
- impedir que stderr nativo do `psql` interrompa a classificação segura antes da leitura do exit code.

Nenhuma senha, URL completa, token, JWT ou chave foi salva no repositório ou incluída neste relatório.

## 5. Falha encontrada na primeira validação remota

A primeira execução autorizada parou no teste estrutural com:

```text
anon possui grant operacional inesperado
```

O erro ocorreu antes da suíte transacional de fixtures. Portanto:

- nenhuma fixture foi iniciada;
- nenhuma fixture foi persistida;
- nenhum objeto Storage foi criado;
- nenhum usuário Auth foi criado.

### Causa

O projeto Supabase remoto possuía privilégios padrão que concediam acesso operacional a `anon`. A existência de RLS não era suficiente para cumprir o princípio de menor privilégio: o papel não deveria sequer possuir grants de `SELECT`, `INSERT`, `UPDATE` ou `DELETE` nas tabelas operacionais.

### Correção

A migration-base foi endurecida para revogar explicitamente todas as permissões de `PUBLIC` e `anon` nas oito tabelas operacionais.

Também foi criada:

```text
20260716_001_bkl016_revoke_anon_operational_grants.sql
```

Essa migration incremental:

- revoga os grants operacionais de `PUBLIC` e `anon`;
- revoga acesso público à view de auditoria;
- reafirma somente os grants previstos de `authenticated`;
- não altera dados, policies ou RLS;
- é aplicável ao projeto que já havia recebido a migration-base.

O identificador `20260716` foi usado porque um timestamp completo de 15/07 colidia, na Supabase CLI 2.109.1, com o identificador legado `20260715` da migration-base e fazia o histórico aparecer desalinhado.

## 6. Dry-run e aplicação da migration corretiva

O dry-run corretivo exibiu exclusivamente:

```text
Would push these migrations:
 • 20260716_001_bkl016_revoke_anon_operational_grants.sql
```

Depois da aplicação sem seed, o histórico ficou:

| Local | Remoto |
|---:|---:|
| `20260715` | `20260715` |
| `20260716` | `20260716` |

Nenhuma outra migration foi aplicada.

## 7. Resultado integral da validação SQL remota

Foram executados pelo validador:

```text
supabase/tests/bkl016_remote_validation.sql
supabase/tests/bkl016_secure_storage_test.sql
```

Marcadores finais obtidos:

```text
BKL-016 remote structural checks passed
BKL-016 database and RLS checks passed
```

As fixtures foram sintéticas, executadas em transação e encerradas com `ROLLBACK`. Os papéis foram exercitados transacionalmente por role/claims, sem criar usuários Auth persistentes.

### Controles efetivamente comprovados

- migration presente e histórico coerente;
- RLS ativa nas tabelas BKL-016;
- `anon` sem grants operacionais;
- `anon` sem execução de funções privadas;
- `authenticated` sem acesso direto a `app_private`;
- schemas privados fora da exposição PostgREST;
- funções `SECURITY DEFINER` com `search_path` vazio;
- usuário autenticado sem perfil negado;
- permissões de `support`;
- permissões de `operations`;
- permissões de `auditor`;
- permissões de `admin`;
- máscaras de CPF e telefone rejeitando valores completos;
- snapshot de oferta imutável;
- auditoria append-only;
- integridade entre cliente, produto e operação técnica;
- proposta rejeitada com operação de outro cliente;
- proposta rejeitada com operação de outro produto;
- consulta rejeitada com operação de outro cliente;
- consulta rejeitada com operação de outro produto;
- evidência final obrigatoriamente do mesmo cliente, mesma operação e tipo correto;
- rejeição de evidência inexistente, de outro cliente, de outra operação ou de tipo incorreto;
- detecção de dado real ou segredo aparente nas tabelas e auditoria.

### Estado após o `ROLLBACK`

A inspeção `supabase inspect db table-stats --linked` reportou estimativa de zero linhas nas 13 tabelas BKL-016. Não houve limpeza destrutiva porque nenhuma fixture persistiu.

## 8. Validação de Storage

A listagem experimental da CLI confirmou os quatro buckets:

```text
cbn-documents-private
cbn-raw-payloads-private
cbn-evidence-private
cbn-temporary-private
```

A suíte SQL confirmou:

- buckets privados;
- ausência de bucket público;
- ausência de policy pública ou para `anon`;
- padrão UUID/hash obrigatório para nomes de objetos existentes;
- nenhum objeto persistente.

Foi tentado um upload de arquivo sintético, sem PII e com nome UUID, no bucket temporário. A CLI experimental recusou a operação com `Unsupported operation` antes de criar o objeto. A listagem posterior não encontrou o objeto e o arquivo local temporário foi removido.

Consequentemente, ainda não foram comprovados:

- upload/download real pelo caminho definitivo do backend;
- URL assinada temporária;
- expiração da URL;
- ausência da URL em logs de aplicação.

Não foi usado `service_role` nem criada chave administrativa para contornar a limitação da CLI.

## 9. Backup, exportação e restauração

O painel do projeto confirmou:

- organização/projeto no plano Free;
- backup agendado não incluído;
- PITR não ativo e disponível somente em plano/add-on pago.

Foi executado um dump manual somente dos schemas `public`, `app_private` e `audit`:

- tamanho: 51.078 bytes;
- 13 tabelas esperadas encontradas;
- nenhum `COPY` ou `INSERT`;
- nenhuma URL com senha, JWT ou chave privada detectada;
- arquivo salvo somente em `supabase/.temp`;
- arquivo removido depois da validação.

A restauração gerenciada não foi executada porque o plano atual não oferece backup gerenciado e não havia um alvo remoto descartável separado para teste. Essa limitação foi registrada, sem afirmar falsamente que recuperação/PITR está disponível.

Para executar `pg_dump`, a CLI baixou a imagem oficial `public.ecr.aws/supabase/postgres:17.6.1.141`, com aproximadamente 353 MiB — não 6 GB.

## 10. Decisão técnica de KMS/cofre

Foram comparadas no máximo três opções:

| Opção | Vantagem | Risco/custo principal |
|---|---|---|
| KMS gerenciado com envelope encryption | rotação, auditoria e segregação maduras | custo e dependência do provedor |
| HashiCorp Vault Transit | controle e portabilidade | operação, disponibilidade e recuperação sob responsabilidade da equipe |
| Secrets manager com criptografia no Gateway | implantação inicial simples | exige desenho criptográfico adicional e não pode alcançar navegador/Appsmith |

Recomendação registrada:

- usar KMS gerenciado;
- gerar DEK por gravação/objeto;
- cifrar localmente com AES-256-GCM;
- manter a KEK no KMS;
- armazenar somente ciphertext, DEK encapsulada e alias/versionamento da chave;
- restringir secrets manager a credenciais, sessões e tokens.

Referências técnicas:

- [Cloud KMS — envelope encryption](https://docs.cloud.google.com/kms/docs/envelope-encryption)
- [HashiCorp Vault Transit](https://developer.hashicorp.com/vault/docs/secrets/transit)

Nenhuma chave foi criada. Provedor, custo, rotação e recuperação continuam pendentes de aprovação e revisão independente.

## 11. Validações finais executadas

```powershell
git diff --check
powershell.exe -ExecutionPolicy Bypass -File .\scripts\validate-bkl016.ps1
powershell.exe -ExecutionPolicy Bypass -File .\scripts\supabase-remote-preflight.ps1 `
  -ProjectRef '<project-ref omitido>' `
  -Phase RemoteValidation `
  -RemoteTargetConfirmed `
  -SyntheticDataConfirmed `
  -MigrationDryRunReviewed
supabase migration list --linked
supabase inspect db table-stats --linked
```

Resultados:

- `git diff --check`: aprovado;
- validador estático: aprovado;
- preflight remoto: aprovado;
- histórico local/remoto: conciliado;
- `telegram-gateway/`: inalterado;
- `.env.example`: inalterado;
- seed e rollback: inalterados;
- nenhum arquivo `.env` real;
- nenhum CPF, RG, conta, endereço ou cliente real;
- nenhum token, senha, sessão, JWT ou chave;
- nenhuma conexão com Supabase de produção;
- nenhuma conexão com n8n ou Appsmith;
- nenhum merge na `main`;
- nenhum push realizado nesta etapa.

## 12. Arquivos criados ou alterados desde o checkpoint

### Documentação

- `README.md`
- `docs/ARQUITETURA_TECNICA.md`
- `docs/BACKLOG_CHECKPOINT.md`
- `docs/BKL-016_ARMAZENAMENTO_DADOS_SENSIVEIS.md`
- `docs/BKL-016_REMOTE_DEV_RUNBOOK.md`
- `docs/HANDOFF.md`

### Scripts

- `scripts/supabase-remote-preflight.ps1`
- `scripts/supabase-remote-validate.ps1`
- `scripts/supabase-remote-cleanup.ps1`
- `scripts/validate-bkl016.ps1`

### Banco e testes

- `supabase/migrations/20260715_001_bkl016_secure_storage.sql`
- `supabase/migrations/20260716_001_bkl016_revoke_anon_operational_grants.sql`
- `supabase/tests/bkl016_remote_validation.sql`

## 13. Commits produzidos

| Commit | Mensagem |
|---|---|
| `3e5b3d9` | `chore: prepare BKL-016 remote development validation` |
| `7c69984` | `chore: record BKL-016 remote link inspection` |
| `d41d58d` | `chore: record BKL-016 remote migration dry-run` |
| `d573783` | `chore: record BKL-016 remote migration application` |
| `9d2045f` | `fix: prompt securely for remote database password` |
| `6091060` | `fix: classify remote validation failures safely` |
| `dee60df` | `fix: revoke anon operational grants in remote dev` |
| `52be77f` | `docs: record BKL-016 corrective migration dry-run` |
| `5517be0` | `docs: record BKL-016 remote validation results` |

## 14. Pendências e riscos restantes

- testar objeto sintético por um backend confiável com credencial mínima;
- testar URL assinada temporária e sua expiração;
- confirmar que a URL não entra em logs ou tabela pública;
- escolher e aprovar o provedor de KMS;
- criar e testar rotação/recuperação somente em tarefa autorizada;
- definir política de backup compatível com produção;
- executar teste real de restauração em alvo descartável;
- validar retenção, anonimização, exclusão e `legal hold` com jurídico;
- realizar revisão independente de grants, policies e funções;
- concluir BKL-018 e BKL-020 antes das integrações finais.

## Status final

**BKL-016: Em andamento.**

A fundação remota de desenvolvimento, migrations, grants, integridades e RLS foram validados. Isso não significa prontidão de produção. Produção permaneceu intocada, e não houve merge, push, seed remoto, usuário real ou integração externa.

**Último commit existente antes deste relatório:** `5517be0e674992cc30bf691fc8ed5837109aeb27`.
