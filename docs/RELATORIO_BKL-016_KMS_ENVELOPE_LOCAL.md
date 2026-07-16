# Relatório — BKL-016 KMS e criptografia por envelope local

**Data:** 15/07/2026
**Branch:** `codex/bkl-016-kms-envelope`
**Base:** `origin/main` em `b161110`
**Status da BKL-016:** **Em andamento**
**Escopo:** adaptador KMS local, KEK efêmera em memória e dados exclusivamente sintéticos

## Resultado

A arquitetura de criptografia por envelope foi implementada e validada localmente. O serviço usa AES-256-GCM, uma DEK aleatória por gravação, nonce aleatório, AAD de contexto, tag obrigatória e uma interface KMS independente de fornecedor. Foram comprovadas rotação de KEK por rewrap, rotação de DEK por recriptografia e recuperação do envelope anterior em caso de falha.

Foi criada migration incremental, sem editar migrations já aplicadas, para persistir metadados completos e rejeitar formatos parciais. Migration, seed, testes SQL, rollback protegido e reaplicação passaram no Supabase local descartável.

Nenhum login de provedor, chave real, recurso pago, deploy, merge, produção, n8n, Appsmith ou Telegram foi usado. Nenhuma migration desta branch foi enviada ao Supabase remoto.

## Diagnóstico registrado

| Item | Resultado |
|---|---|
| Branch inicial | `codex/bkl-016-kms-envelope`, criada de `origin/main` atualizado |
| Árvore antes da implementação | limpa |
| Docker | 29.6.1 |
| Docker Compose | 5.3.0 |
| Supabase CLI | 2.109.1 |
| psql | PostgreSQL 17.10 |
| Node.js | 24.18.0 |
| npm | 11.16.0 |

## Arquitetura adotada

- `KmsAdapter`: contrato com `wrapKey`, `unwrapKey`, `getKeyReference`, `rewrapDataKey` e `healthCheck`.
- `LocalTestKmsAdapter`: exclusivo de teste, sem SDK/rede, exige `environment: 'test'` e `allowLocalTestKms: true`; gera KEK de 32 bytes em memória por processo e mantém versões anteriores somente durante o teste.
- `EnvelopeEncryptionService`: usa primitivas nativas `node:crypto`, sem criptografia própria ou biblioteca cloud.
- Conteúdo: AES-256-GCM com DEK aleatória de 32 bytes, nonce aleatório de 12 bytes e tag de 16 bytes.
- AAD v1: envelope/tipo do payload e IDs canônicos de cliente, operação, proposta, bucket e objeto quando aplicáveis, sem PII.
- Logs/auditoria: somente tipo do evento, algoritmo, alias e versões; nunca plaintext, DEK, wrapped DEK, nonce/tag completos ou conteúdo descriptografado.
- Persistência: envelope inteiro deve ser gravado atomicamente pelo futuro backend; em falha, o envelope anterior permanece.

## Campos de envelope

A migration `20260717_001_bkl016_envelope_metadata.sql` acrescenta a `app_private.protected_payloads` e `app_private.protected_file_refs`:

- `envelope_algorithm`;
- `envelope_version`;
- `wrapped_dek`;
- `content_nonce`;
- `authentication_tag`;
- `aad_version`;
- `aad_sha256`;
- `encryption_version` também em `protected_file_refs`; `encryption_key_ref` já existia.

Constraints aceitam somente AES-256-GCM/v1, nonce de 12 bytes, tag de 16 bytes, AAD v1/hash SHA-256 e alias/versão não vazios. `num_nonnulls = 0 ou 7` garante que uma linha seja inteiramente legada ou um envelope completo, sem permitir que a semântica `NULL` de uma `CHECK` aceite mistura parcial.

O rollback incremental recusa executar se houver qualquer envelope novo, porque remover os metadados tornaria o ciphertext irrecuperável.

## Testes executados

### Node.js

Comando:

```powershell
npm.cmd test --prefix scripts
```

Resultado: **21 testes aprovados, 0 falhas** — 12 de envelope e 9 do runtime de Storage existente.

Cobertura do envelope:

- round-trip positivo e plaintext vazio rejeitado;
- DEK, nonce e ciphertext diferentes para o mesmo conteúdo;
- AAD correta aceita e troca de cliente/operação/proposta/bucket rejeitada;
- tag, ciphertext, nonce e wrapped DEK adulterados rejeitados;
- key version incorreta, envelope desconhecido e incompleto rejeitados;
- rotação de KEK preserva plaintext e ciphertext, alterando wrapped DEK/versão;
- rotação de DEK preserva plaintext e altera ciphertext/nonce/wrapped DEK;
- falha de rotação não destrói o envelope anterior;
- adaptador local bloqueado fora de teste;
- saída/auditoria sem material sensível completo.

### Banco e RLS

Comandos locais:

```powershell
psql -X $DATABASE_URL -v ON_ERROR_STOP=1 -f supabase/tests/bkl016_secure_storage_test.sql
psql -X $DATABASE_URL -v ON_ERROR_STOP=1 -f supabase/tests/bkl016_envelope_constraints_test.sql
```

Resultados finais, antes e depois da reaplicação:

```text
BKL-016 database and RLS checks passed
BKL-016 envelope database constraints passed
```

A suíte principal confirmou anon, authenticated sem perfil, support, operations, auditor, admin, isolamento de `app_private`, funções SECURITY DEFINER, máscaras, snapshot, integridades de operação/evidência e auditoria append-only. A suíte nova confirmou linha legada, payload/arquivo completos e rejeição de algoritmo inválido ou nulo, nonce, tag, envelope parcial e referência de chave inválidos.

## Migration, seed, rollback e repetibilidade

1. `supabase db reset` aplicou migrations `20260715`, `20260716` e `20260717` e o seed sintético.
2. O rollback com um envelope v1 sintético foi recusado com `Rollback de envelope recusado: existem envelopes novos`; a linha e os metadados permaneceram.
3. Depois de remover somente essa fixture local, o rollback incremental passou.
4. `bkl016_envelope_rollback_test.sql` terminou com:

```text
BKL-016 envelope rollback checks passed
```

5. Novo `supabase db reset` reaplicou as três migrations e o seed.
6. As suítes SQL passaram novamente com os dois marcadores finais.

O seed mantém deliberadamente uma fixture legada para provar compatibilidade; não persiste KEK, DEK em claro ou wrapped DEK reutilizável. Envelopes completos existem somente em testes transacionais ou fixtures descartáveis removidas.

## Falhas encontradas e correções

- A primeira subida do stack demorou porque as imagens locais do Supabase ainda não existiam. Os downloads terminaram e todos os contêineres ficaram saudáveis.
- O primeiro `db reset`, disparado imediatamente após a subida, falhou durante a inicialização interna do schema. A repetição com diagnóstico concluiu migrations e seed; a reaplicação posterior também passou normalmente.
- A primeira fixture SQL de arquivo usou a palavra `envelope` no object key e foi corretamente rejeitada pela constraint hexadecimal existente. O teste foi corrigido para UUID/hash sintético permitido.
- O primeiro wrapper de verificação do rollback interpretou uma quebra de linha do PowerShell como mensagem divergente. O PostgreSQL já havia recusado corretamente e preservado os dados; a validação foi refeita conferindo estado e exit code.
- Dois testes Node inicialmente mostraram normalização excessiva de erros do adaptador. O serviço passou a preservar categorias seguras de `KmsAdapterError`; a suíte voltou a 12/12.
- A validação genérica de referência de chave estava acoplada ao provedor local. O contrato foi tornado neutro e o bloqueio `local-test-only` permaneceu dentro do adaptador de teste.
- A revisão final identificou que `CHECK` aceita resultado SQL `NULL` em uma combinação parcial específica. As duas tabelas passaram a exigir exatamente zero ou sete metadados não nulos, e um teste negativo com algoritmo nulo foi adicionado e aprovado.

## Matriz resumida de provedores

Pesquisa em documentação oficial em 15/07/2026; nenhum provedor foi selecionado.

| Caminho | Vantagem principal | Custo/risco principal | Avaliação preliminar |
|---|---|---|---|
| KMS gerenciado | IAM/auditoria/alta disponibilidade administrados e modelo direto de KEK | cobrança por versões/operações, billing e dependência da API do provedor | primeiro caminho a avaliar para equipe pequena |
| Vault Transit | ACL, keyring e rewrap maduros; boa portabilidade | operação HA/unseal/backup complexa ou custo do serviço gerenciado | adequado se já houver competência Vault |
| Cofre + envelope próprio no Gateway | aproveita secrets existentes e mantém contrato interno | equipe custodia KEK, disponibilidade, auditoria e recuperação | somente transição controlada, não equivalente a KMS |

Detalhes, fontes e gate estão em `docs/BKL-016_KMS_ENVELOPE_RUNBOOK.md`.

## Validações finais de segurança

- `telegram-gateway/`: inalterado;
- `.env.example`: inalterado;
- nenhum arquivo `.env` real;
- nenhum CPF, RG, conta, endereço ou cliente real;
- nenhuma chave fixa, chave cloud, senha, token, sessão, JWT ou service role adicionada;
- nenhum plaintext sintético fora do teste Node controlado;
- nenhum wrapped DEK, nonce, tag ou ciphertext completo em logs da aplicação;
- nenhuma autenticação em provedor externo e nenhuma chave/recurso KMS criado;
- nenhuma conexão, migration ou seed executado no Supabase remoto;
- nenhum merge ou deploy.

Transparência: a pesquisa abriu somente páginas públicas oficiais. Ao concluir um `supabase db reset --debug`, a CLI registrou uma tentativa de telemetria HTTP ao PostHog; não houve autenticação, segredo enviado pelo projeto, recurso criado ou acesso ao Supabase remoto. A telemetria foi desativada nos comandos seguintes. Em uma nova subida, `supabase start` imprimiu as credenciais padrão descartáveis do stack local; elas não pertencem a projeto externo, não foram copiadas para arquivo/log da aplicação e foram destruídas com `supabase stop --no-backup`.

## Arquivos alterados

- `docs/ARQUITETURA_TECNICA.md`
- `docs/BACKLOG_CHECKPOINT.md`
- `docs/BKL-016_ARMAZENAMENTO_DADOS_SENSIVEIS.md`
- `docs/HANDOFF.md`
- `docs/BKL-016_KMS_ENVELOPE_RUNBOOK.md`
- `docs/RELATORIO_BKL-016_KMS_ENVELOPE_LOCAL.md`
- `scripts/package.json`
- `scripts/package-lock.json`
- `scripts/validate-bkl016.ps1`
- `scripts/kms-envelope/kms-adapter.mjs`
- `scripts/kms-envelope/local-test-kms-adapter.mjs`
- `scripts/kms-envelope/envelope-service.mjs`
- `scripts/kms-envelope/envelope-service.test.mjs`
- `supabase/migrations/20260717_001_bkl016_envelope_metadata.sql`
- `supabase/rollback/20260717_001_bkl016_envelope_metadata_down.sql`
- `supabase/tests/bkl016_envelope_constraints_test.sql`
- `supabase/tests/bkl016_envelope_rollback_test.sql`
- `supabase/seed.sql`

## Riscos restantes

- provedor, região, custo e contrato ainda não aprovados;
- adaptador remoto e identidade de workload ainda não existem;
- rotação/recuperação remotas não foram testadas;
- restauração do Supabase, retenção/legal hold e policies finais continuam pendentes;
- `client_sensitive_data` e `proposal_sensitive_data` ainda são formato legado e não devem receber novas escritas de envelope até migration específica;
- revisão técnica independente ainda pendente.

## Gate humano obrigatório

**Parada exata atingida:** antes de login/autenticação em provedor, ativação de API ou billing, criação/importação de KEK, criação de Vault, gravação de segredo Railway ou implementação de adaptador remoto.

Guilherme precisa aprovar provedor, região, custo, IAM mínimo, auditoria, retenção de versões, recuperação e plano sintético. O trabalho remoto deve ocorrer em tarefa separada e parar novamente antes de produção.

## Commit

O hash final é informado na entrega do Codex após o commit e o push; um arquivo versionado não consegue conter o hash do próprio commit sem alterá-lo.
