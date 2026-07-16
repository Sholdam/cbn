# Relatório — BKL-016 backup, restauração e recuperação sintética local

**Data:** 16/07/2026

**Branch:** `codex/bkl-016-backup-restore`

**Status da fase:** concluída localmente

**Status da BKL-016 geral:** Em andamento

## Escopo e limites

Foram usados exclusivamente fixtures sintéticas, stack Supabase local descartável e `LocalTestKmsAdapter` com KEK efêmera em memória. Não houve `supabase link`, `--linked`, conexão remota, upload cloud, billing, recurso pago, credencial externa, produção, n8n, Appsmith ou Telegram.

Google Cloud KMS real permanece bloqueado por faturamento. Isso não altera a regra: dados reais e produção são proibidos enquanto não existir KMS/cofre aprovado.

## Implementação

- prompt: `docs/PROMPT_CODEX_BKL-016_BACKUP_RESTORE.md`;
- runbook: `docs/BKL-016_BACKUP_RESTORE_RUNBOOK.md`;
- utilitários/testes: `scripts/backup-restore/`;
- runtime integrado: backup de schema/dados, Storage, recuperação do envelope, testes negativos e limpeza;
- `supabase/config.toml`: analytics local desativado por não participar da prova.

## Resultado final

```text
BKL-016 synthetic schema backup passed
BKL-016 synthetic data restore passed
BKL-016 synthetic Storage restore passed
BKL-016 envelope recovery passed
BKL-016 missing KEK version failed closed
BKL-016 tamper detection passed
BKL-016 database and RLS checks passed
BKL-016 envelope database constraints passed
BKL-016 safe rollback refusal passed
BKL-016 preliminary local RTO seconds: 105.08
BKL-016 preliminary RPO: exact snapshot; operational RPO equals future backup cadence
BKL-016 backup and restore runtime passed
```

O schema foi recuperado pelas migrations versionadas, com dump de schema mantido apenas como verificação. Os dados BKL-016 foram restaurados por dump. O objeto privado foi restaurado separadamente e teve SHA-256 idêntico. O envelope restaurado foi descriptografado apenas com a KEK correta.

## Falhas encontradas e correções

1. O scanner confundiu UUID/campo de autorização com CPF/cabeçalho: os padrões foram restringidos e ganhou teste de regressão.
2. Analytics local ficou `unhealthy`: foi desativado no config e a prova manteve sondas reais de banco/Storage.
3. Restore com `postgres` não podia controlar triggers: a carga passou a usar o proprietário local `supabase_admin`.
4. Base64 do PostgreSQL continha quebras de linha: a consulta remove as quebras antes da validação canônica.
5. O npm alterava o diretório corrente para `scripts`: caminhos de SQL passaram a usar a raiz obtida pelo Git.

Todas as falhas ocorreram somente no ambiente descartável. O `finally` removeu objetos, diretórios temporários, KEK em memória e a stack após cada tentativa.

## RTO/RPO

- RTO local final observado: **105,08 segundos**; não é SLA de produção.
- RPO do teste: snapshot exato.
- RPO operacional preliminar: igual à frequência futura de backups bem-sucedidos.
- Sem PITR/backup gerenciado não há promessa de perda zero.

## Segurança e limpeza

- nenhum plaintext protegido, URL assinada, JWT, credencial, chave ou PII em logs/commits;
- dumps/manifesto existiram apenas no diretório temporário e foram removidos;
- objeto Storage removido;
- stack encerrada com `supabase stop --no-backup`;
- `telegram-gateway/` e `.env.example` inalterados.

## Riscos restantes

- KMS real, IAM e recuperação de chave dependem de faturamento/aprovação;
- estratégia de backup/PITR e armazenamento externo de produção ainda não existe;
- retenção, legal hold e policies finais de Storage ainda pendem;
- revisão técnica independente continua necessária;
- restauração remota/gerenciada não foi executada.
