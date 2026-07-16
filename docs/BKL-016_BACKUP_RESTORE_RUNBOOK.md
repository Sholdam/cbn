# BKL-016 — runbook de backup, restauração e recuperação sintética

**Status:** Em andamento

**Escopo:** somente stack Supabase local descartável e dados sintéticos

**Produção/dados reais:** proibidos

## Gate e execução

O runtime exige a branch `codex/bkl-016-backup-restore` e a confirmação explícita no processo:

```powershell
$env:CBN_BACKUP_RESTORE_CONFIRMED = 'synthetic-local-only'
npm.cmd run run:backup-restore-local --prefix scripts
Remove-Item Env:CBN_BACKUP_RESTORE_CONFIRMED
```

Ele recusa stack local preexistente para não destruir trabalho de outra execução. Os comandos Supabase usados não possuem `--linked`; telemetria é desativada no processo. Metadados locais de vínculo remoto, caso existam, não são lidos nem usados.

Serviços locais sem relação com a prova (`analytics`, `vector`, `realtime`, `studio`, edge runtime, proxy de imagem e caixa de e-mail) são excluídos da subida. O teste mantém apenas o necessário para PostgreSQL, API e Storage, reduzindo superfície, tempo e falsos bloqueios de saúde.

Analytics também fica desativado no `supabase/config.toml`. A subida ignora o health check global, mas não assume sucesso: `db reset`, consulta PostgreSQL e upload/download no Storage são executados imediatamente como sondas obrigatórias. Falha em qualquer serviço necessário interrompe a prova.

O dump é produzido pelo papel local `postgres`; a restauração usa `supabase_admin`, proprietário local autorizado a controlar triggers durante a carga. Ambos existem somente na stack descartável, sem senha externa ou conexão remota.

## Conteúdo do backup

| Plano | Fonte canônica | Artefato temporário | Recuperação |
|---|---|---|---|
| Schema | migrations Git | `schema.sql` para verificação | `supabase db reset` local |
| Dados | tabelas BKL-016 | `data.sql`, somente fixtures sintéticas | restore PostgreSQL com triggers controlados |
| Storage | bucket privado temporário | bytes + manifesto UUID/hash/tamanho | upload autenticado local e verificação SHA-256 |
| Chaves | KMS/cofre externo | **não entra no backup** | versão da KEK precisa continuar disponível |

Os artefatos existem apenas em diretório temporário do sistema operacional e são removidos no `finally`.

## Ordem de recuperação

1. iniciar stack local descartável;
2. aplicar migrations e seed sintético;
3. criar envelope com KEK local efêmera e versão 2;
4. criar objeto Storage sintético;
5. gerar backup de schema, dados e objeto/manifesto;
6. verificar os artefatos contra plaintext, PII, URL assinada, JWT e credencial;
7. remover objeto e resetar o banco;
8. reaplicar schema pelas migrations;
9. restaurar o dump de dados;
10. restaurar o objeto e conferir SHA-256;
11. carregar o envelope restaurado e descriptografar com a KEK em memória;
12. provar falha sem a versão da KEK;
13. provar falha após adulteração;
14. provar que rollback de metadados recusa envelope existente;
15. remover objeto, dumps, KEK em memória e stack local.

## Dependências de recuperação

```text
Migrations Git ──> schema PostgreSQL
Dump de dados ───> linhas operacionais/privadas/auditoria
Backup Storage ──> bytes do objeto + manifesto/hash
KMS/cofre ───────> KEK alias/versão usada para desembrulhar a DEK
                         │
                         └── sem essa versão: falha fechada
```

Restaurar somente o banco não recupera documentos do Storage. Restaurar banco e Storage sem a KEK correta conserva os bytes, mas não recupera o conteúdo. Destruir uma versão de KEK antes do inventário/rewrap pode tornar o backup irrecuperável.

## RTO e RPO preliminares

- **RTO local observado:** medido do início da stack até verificação criptográfica após restauração; serve apenas como baseline técnico, não como SLA.
- **RPO do teste:** snapshot exato criado durante a execução.
- **RPO operacional preliminar:** igual ao intervalo futuro entre backups bem-sucedidos. Sem backup gerenciado/PITR, não existe promessa de perda zero.

Antes de produção devem ser definidos frequência, retenção, armazenamento externo protegido, teste periódico, responsável, alerta de falha e meta aprovada de RTO/RPO.

## Bloqueio financeiro e gate externo

O Google Cloud KMS real continua bloqueado temporariamente porque a conta de faturamento exige pagamento. Isso não autoriza adaptar o KMS local para produção. Até existir KMS/cofre aprovado:

```text
Dados sintéticos: permitido
Dados reais: proibido
Produção: proibida
```

Parar antes de qualquer login cloud, billing, criação de key ring/KEK, upload externo, credencial externa ou conexão Supabase remota.
