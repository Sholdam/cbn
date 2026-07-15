# BKL-016 — Armazenamento de dados sensíveis

**Status:** Em andamento — base e correções da revisão técnica preparadas no código, ainda não aplicadas nem validadas em Supabase real
**Data:** 15/07/2026
**Escopo desta entrega:** fundação local, dados sintéticos e políticas conservadoras

## Decisão de arquitetura

A base separa quatro destinos com responsabilidades diferentes:

| Destino | Conteúdo permitido | Conteúdo proibido |
|---|---|---|
| PostgreSQL `public` | IDs, produto, estados, códigos, aliases, valores de oferta, máscaras e referências UUID | CPF/RG/telefone completos, conta, endereço, link completo, sessão, token e payload bruto |
| PostgreSQL `app_private` | ciphertext, tokens opacos de busca, últimos 4 dígitos quando necessários e referências protegidas | chaves de criptografia, sessão Telegram, `api_hash`, 2FA e tokens de provedor |
| Supabase Storage privado | documentos, evidências, retornos brutos e arquivos temporários | nomes de arquivo com CPF, RG, telefone ou nome; bucket público; URL assinada persistida |
| Cofre do ambiente | sessão MTProto, `api_id`, `api_hash`, 2FA, tokens, chaves privadas, credenciais e chaves KMS | qualquer tabela, migration, seed, exemplo, log, planilha ou GitHub |

`pgcrypto` é usado apenas para UUID/hash técnico quando adequado. A migration não recebe chave de criptografia. Dados sensíveis devem ser cifrados por backend confiável com biblioteca consolidada e KMS/cofre externo; o banco armazena somente `bytea` e o alias da chave. Não há criptografia caseira.

## PostgreSQL operacional

As tabelas `public` são:

- `clients`: identificação operacional; `cpf_masked` e `phone_masked` exigem `*` e rejeitam sequências numéricas completas mesmo com formatação;
- `technical_operations`: `operation_id` canônico, fila, estado, retry e `session_alias`;
- `consultations`: uma consulta por produto e operação;
- `offers`: snapshot da condição retornada;
- `proposals`: sempre vinculada a uma oferta coerente em cliente/produto e a `final_authorization_evidence_payload_ref` cujo payload possui o mesmo `client_id`, o mesmo `operation_id` e o tipo canônico `FINAL_AUTHORIZATION_EVIDENCE`;
- `interactions`: linha do tempo com resumo mascarado;
- `pending_items`: ação e motivo em campos separados;
- `user_profiles`: papel interno ligado ao Supabase Auth.

FGTS e CLT usam o tipo fechado `credit_product`. O `operation_id` é chave primária de `technical_operations` e as entidades que executam efeitos externos o referenciam. Status bruto, status normalizado, ação pendente e motivo mascarado permanecem independentes.

Exclusões físicas são restritas por chaves estrangeiras. `retention_until` orienta a rotina futura de retenção e `anonymized_at` registra anonimização controlada sem remover a trilha obrigatória.

## Schema privado

O schema `app_private` não está na lista de schemas expostos pela API local e não concede acesso direto a `anon` ou `authenticated`.

- `client_sensitive_data`: CPF, RG, metadados, endereço e conta somente em ciphertext;
- `proposal_sensitive_data`: link, endereço, conta e documentos da proposta somente em ciphertext;
- `protected_payloads`: retornos brutos e evidências de autorização protegidas, com dono, retenção e hash do ciphertext; evidências finais já nascem ligadas ao cliente e à operação, mesmo antes de existir proposta;
- `protected_file_refs`: referência UUID/hash para objetos privados, nunca URL assinada.

A função `app_private.get_client_sensitive_summary` é `security definer`, fixa `search_path` vazio, valida o papel e retorna apenas presença de dados e últimos quatro dígitos. Ela não retorna ciphertext nem segredo. `admin` e `operations` são os únicos papéis que recebem resultado; chamadas de `support` e `auditor` retornam zero linhas e registram a negação. `anon` não possui `USAGE` no schema nem `EXECUTE` nessas funções. A função não é exposta no PostgREST.

## RLS e menor privilégio

RLS está ativa em todas as tabelas públicas, privadas e de auditoria.

- sem perfil ativo: nenhuma leitura operacional;
- `admin`: administração operacional ampla e gestão de perfis;
- `operations`: leitura, inclusão e alteração do fluxo; sem exclusão e sem tabela privada direta;
- `support`: leitura de clientes, consultas, propostas, interações e pendências; pode registrar interação e tratar pendência;
- `auditor`: leitura não sensível e trilha; nenhuma mutação;
- `anon`: nenhuma policy operacional;
- schema privado: negação direta por ausência de policy e grants.

### Escrita de ciphertext no schema privado

Nesta fase, nenhum papel da API (`anon` ou `authenticated`) grava diretamente em `app_private`; somente o owner da migration pode carregar fixtures cifradas durante validação controlada. No ambiente real, n8n/Gateway deverá usar uma credencial PostgreSQL backend dedicada, com grants explícitos apenas nas tabelas privadas necessárias. Essa conexão será direta ao PostgreSQL, não via PostgREST, portanto `app_private` continuará fora de `api.schemas`.

A criação do login técnico e sua senha depende do projeto Supabase real e não pertence à migration. A credencial ficará no gerenciador de credenciais do n8n/cofre do Gateway. O `service_role` contorna RLS e, por isso, só pode existir em backend confiável; nunca será entregue ao navegador ou ao Appsmith. Nenhuma chave administrativa será usada como atalho para a conexão direta do painel.

Todas as funções `security definer` usam `search_path = ''`, nomes totalmente qualificados e grants mínimos. Funções auxiliares de papel e resumo não concedem `EXECUTE` a `anon`.

### Integridade da autorização final

O banco aplica uma foreign key composta entre a proposta e o payload protegido usando `final_authorization_evidence_payload_ref`, `client_id`, `operation_id` e `final_authorization_evidence_type`. A chave candidata correspondente existe em `app_private.protected_payloads`. Assim, não basta conhecer o UUID de uma evidência válida: cliente, operação e tipo também precisam coincidir.

O payload `FINAL_AUTHORIZATION_EVIDENCE` exige `client_id` e `operation_id` não nulos. Ele pode ser inserido antes da proposta porque referencia somente entidades que já existem nessa etapa; a proposta é criada depois e aponta para essa evidência, sem dependência circular. Aplicação, n8n e Appsmith não conseguem contornar essa regra por erro de implementação.

O primeiro administrador não é criado pelo seed. Após criar o usuário real pelo Supabase Auth, um operador autorizado deve promover explicitamente o UUID no SQL Editor:

```sql
insert into public.user_profiles (user_id, role, display_name)
values ('UUID-DO-USUARIO-AUTH', 'admin', 'Administrador inicial');
```

Nunca coloque UUID, e-mail ou credencial real em migration ou seed.

## Auditoria

`audit.events` é append-only: `UPDATE` e `DELETE` são bloqueados por trigger. Alterações nas sete tabelas operacionais geram eventos com:

- entidade e identificador;
- `operation_id`, quando existir;
- origem `n8n`, `appsmith`, `gateway`, `human` ou `system`;
- ação e estados/códigos mínimos;
- papel e identidade, quando autenticados.

A trilha não copia `status_raw`, motivo livre, resumo de interação, CPF, RG, endereço, conta, link ou payload. Para integrações, o executor deve definir a origem na transação, por exemplo:

```sql
set local app.change_origin = 'gateway';
```

Falhas de RLS puras acontecem antes de trigger e devem ser registradas pelo Gateway/n8n em uma chamada de auditoria confiável. A função de resumo sensível já registra acesso permitido/negado sem retornar valor em caso de negação.

## Storage privado

A migration prepara, se o schema `storage` estiver disponível, quatro buckets privados:

- `cbn-documents-private`;
- `cbn-raw-payloads-private`;
- `cbn-evidence-private`;
- `cbn-temporary-private`.

Não é criada policy de acesso a `storage.objects`: a negação é intencional até existir backend validado. O nome do objeto deve ser UUID/hash e a referência fica em `protected_file_refs`. URLs assinadas são geradas sob demanda, com expiração curta, e nunca persistidas.

Retenção inicial a validar com jurídico/compliance:

- temporários: expiração curta e remoção automática;
- payload bruto: somente pelo prazo de diagnóstico/obrigação;
- documentos e evidências: prazo legal/contratual aprovado;
- após o prazo: remover objeto, marcar `deleted_at` e anonimizar referências não obrigatórias.

Nenhum prazo definitivo foi inventado nesta tarefa.

## Appsmith, Sheets e logs

### Appsmith

Pode exibir IDs, produto, banco/oferta, estado normalizado, ação pendente, motivo mascarado, protocolo mascarado e últimos quatro dígitos quando uma função controlada justificar. Não pode consultar tabela privada, receber `service_role`, ciphertext, URL completa ou segredo.

### Google Sheets

Somente exportações de apoio com IDs, aliases, códigos, estados e máscaras. Nunca CPF/RG/telefone completos, endereço, conta, links, payload, documento ou sessão.

### Logs

Podem conter `operation_id`, produto, `session_alias`, etapa, código, latência e decisão de retry. Nunca devem conter CPF, RG, endereço, conta, link completo, mensagem bruta, ciphertext, sessão, token ou chave. Erros devem ser normalizados antes de registrar.

## Retenção, anonimização e exclusão

1. Cada registro protegido recebe `retention_until` conforme política aprovada.
2. Uma rotina backend futura seleciona itens vencidos sem ler/registrar o conteúdo.
3. Conteúdo não obrigatório é apagado; referências recebem `deleted_at` ou `anonymized_at`.
4. Identificadores e eventos exigidos para auditoria permanecem, sem dado completo.
5. Legal hold e obrigação regulatória devem suspender exclusão por regra documentada.
6. Toda execução gera evento agregado, nunca cópia do conteúdo removido.

A rotina automática não foi implementada porque prazo legal, legal hold e ambiente real ainda precisam de aprovação.

## Backup e recuperação

No projeto real, habilitar backups gerenciados/PITR conforme o plano Supabase, restringir acesso administrativo e testar restauração em ambiente separado. Backup herda a sensibilidade do banco: acesso, retenção e descarte precisam seguir a mesma política. Esta entrega não ativou nem simulou backup.

## Como aplicar em um Supabase real

1. Criar manualmente um projeto Supabase isolado de desenvolvimento, sem dados reais.
2. Configurar MFA, membros mínimos e região adequada; não compartilhar credenciais.
3. Instalar a CLI e autenticar localmente sem versionar token.
4. Revisar o diff SQL, principalmente grants, policies, buckets e funções `security definer`.
5. Vincular o projeto com `supabase link --project-ref <PROJECT_REF>` usando referência pública, nunca senha no comando salvo.
6. Fazer `supabase db reset` local e executar o teste SQL antes da base remota.
7. Aplicar somente a migration com `supabase db push --dry-run` e revisar a saída.
8. Após aprovação humana, executar `supabase db push` no ambiente de desenvolvimento.
9. Não executar `supabase/seed.sql` em ambiente compartilhado; ele é fixture local.
10. Criar usuários pelo Auth e promover o primeiro admin manualmente.
11. Configurar KMS/cofre e testar cifrar/decifrar com dado sintético; a chave não entra no banco.
12. Validar RLS com contas sintéticas de cada papel e confirmar negações.
13. Configurar policies de Storage somente para o backend confiável e testar URLs curtas.
14. Configurar backup/PITR, retenção e um teste de restauração.
15. Só depois planejar conexões de n8n/Appsmith em tarefas próprias.

## Validação local preparada

- `supabase/tests/bkl016_secure_storage_test.sql`: fixtures Auth sintéticas para admin, operations, support, auditor e usuário sem perfil; troca efetiva de role/claims; acesso de anon; isolamento privado; permissões reais; máscaras; oferta imutável; evidência positiva do mesmo cliente/operação/tipo; rejeição de evidência de outro cliente, outra operação, tipo incorreto ou UUID inexistente; e auditoria append-only;
- `scripts/validate-bkl016.ps1`: estrutura esperada, invariantes da revisão, seed sintético, ausência recursiva de `.env`, padrões de segredo, sessão, token, chave, JWT e CPF completo;
- `supabase/seed.sql`: cliente, operações, consulta, oferta, evidência protegida e proposta claramente sintéticos; a evidência é inserida antes da proposta para provar o ciclo válido.
- `supabase/rollback/20260715_001_bkl016_secure_storage_down.sql`: rollback manual e destrutivo somente para desenvolvimento limpo; buckets com objetos não são apagados silenciosamente.

Se Docker/Supabase CLI não estiverem disponíveis, o teste de banco ficará preparado, mas não executado. Isso deve ser registrado como limitação, sem marcar BKL-016 como concluída.

## Riscos restantes

- migration ainda não executada em uma instância Supabase limpa;
- testes dinâmicos por papel estão preparados, mas ainda precisam ser executados em Supabase local;
- KMS/cofre, rotação e recuperação de chave não foram escolhidos;
- prazos legais de retenção e legal hold precisam de validação;
- policies de objetos Storage continuam deliberadamente ausentes;
- backup/PITR e restauração ainda não foram testados;
- rotina de anonimização/exclusão ainda não foi implementada;
- funções e grants devem passar por revisão independente antes da aplicação;
- BKL-018 e BKL-020 completarão autenticação/perfis e auditoria canônica.

## Checklist para aprovar a aplicação futura

- [ ] migration aplicada em projeto Supabase limpo de desenvolvimento;
- [ ] teste SQL executado sem falhas;
- [ ] RLS testada com usuário sem papel, admin, operations, support e auditor;
- [ ] acesso direto ao schema privado negado;
- [ ] Appsmith sem `service_role` e sem acesso privado;
- [ ] n8n usando cofre e credencial mínima;
- [ ] buckets confirmados como privados e sem nome de arquivo com PII;
- [ ] URLs assinadas expiram e não aparecem em logs;
- [ ] KMS/cofre e rotação aprovados;
- [ ] retenção, anonimização, legal hold e backup aprovados;
- [ ] varredura de segredos e dados pessoais aprovada;
- [ ] documentação e handoff revisados;
- [ ] BKL-016 somente então avaliada para conclusão.
