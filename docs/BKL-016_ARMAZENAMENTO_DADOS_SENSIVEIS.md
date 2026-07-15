# BKL-016 â€” Armazenamento de dados sensÃ­veis

**Status:** Em andamento â€” base preparada no cÃ³digo, ainda nÃ£o aplicada nem validada em Supabase real
**Data:** 15/07/2026
**Escopo desta entrega:** fundaÃ§Ã£o local, dados sintÃ©ticos e polÃ­ticas conservadoras

## DecisÃ£o de arquitetura

A base separa quatro destinos com responsabilidades diferentes:

| Destino | ConteÃºdo permitido | ConteÃºdo proibido |
|---|---|---|
| PostgreSQL `public` | IDs, produto, estados, cÃ³digos, aliases, valores de oferta, mÃ¡scaras e referÃªncias UUID | CPF/RG/telefone completos, conta, endereÃ§o, link completo, sessÃ£o, token e payload bruto |
| PostgreSQL `app_private` | ciphertext, tokens opacos de busca, Ãºltimos 4 dÃ­gitos quando necessÃ¡rios e referÃªncias protegidas | chaves de criptografia, sessÃ£o Telegram, `api_hash`, 2FA e tokens de provedor |
| Supabase Storage privado | documentos, evidÃªncias, retornos brutos e arquivos temporÃ¡rios | nomes de arquivo com CPF, RG, telefone ou nome; bucket pÃºblico; URL assinada persistida |
| Cofre do ambiente | sessÃ£o MTProto, `api_id`, `api_hash`, 2FA, tokens, chaves privadas, credenciais e chaves KMS | qualquer tabela, migration, seed, exemplo, log, planilha ou GitHub |

`pgcrypto` Ã© usado apenas para UUID/hash tÃ©cnico quando adequado. A migration nÃ£o recebe chave de criptografia. Dados sensÃ­veis devem ser cifrados por backend confiÃ¡vel com biblioteca consolidada e KMS/cofre externo; o banco armazena somente `bytea` e o alias da chave. NÃ£o hÃ¡ criptografia caseira.

## PostgreSQL operacional

As tabelas `public` sÃ£o:

- `clients`: identificaÃ§Ã£o operacional e versÃµes mascaradas;
- `technical_operations`: `operation_id` canÃ´nico, fila, estado, retry e `session_alias`;
- `consultations`: uma consulta por produto e operaÃ§Ã£o;
- `offers`: snapshot da condiÃ§Ã£o retornada;
- `proposals`: sempre vinculada a uma oferta coerente em cliente e produto;
- `interactions`: linha do tempo com resumo mascarado;
- `pending_items`: aÃ§Ã£o e motivo em campos separados;
- `user_profiles`: papel interno ligado ao Supabase Auth.

FGTS e CLT usam o tipo fechado `credit_product`. O `operation_id` Ã© chave primÃ¡ria de `technical_operations` e as entidades que executam efeitos externos o referenciam. Status bruto, status normalizado, aÃ§Ã£o pendente e motivo mascarado permanecem independentes.

ExclusÃµes fÃ­sicas sÃ£o restritas por chaves estrangeiras. `retention_until` orienta a rotina futura de retenÃ§Ã£o e `anonymized_at` registra anonimizaÃ§Ã£o controlada sem remover a trilha obrigatÃ³ria.

## Schema privado

O schema `app_private` nÃ£o estÃ¡ na lista de schemas expostos pela API local e nÃ£o concede acesso direto a `anon` ou `authenticated`.

- `client_sensitive_data`: CPF, RG, metadados, endereÃ§o e conta somente em ciphertext;
- `proposal_sensitive_data`: link, endereÃ§o, conta e documentos da proposta somente em ciphertext;
- `protected_payloads`: retornos brutos protegidos com dono, retenÃ§Ã£o e hash do ciphertext;
- `protected_file_refs`: referÃªncia UUID/hash para objetos privados, nunca URL assinada.

A funÃ§Ã£o `app_private.get_client_sensitive_summary` Ã© `security definer`, fixa `search_path`, valida o papel e retorna apenas presenÃ§a de dados e Ãºltimos quatro dÃ­gitos. Ela nÃ£o retorna ciphertext nem segredo. Tentativas permitidas e negadas sÃ£o auditadas sem valores completos. A funÃ§Ã£o nÃ£o deve ser exposta no PostgREST; backend/n8n deve chamÃ¡-la por uma conexÃ£o controlada quando houver justificativa operacional.

## RLS e menor privilÃ©gio

RLS estÃ¡ ativa em todas as tabelas pÃºblicas, privadas e de auditoria.

- sem perfil ativo: nenhuma leitura operacional;
- `admin`: administraÃ§Ã£o operacional ampla e gestÃ£o de perfis;
- `operations`: leitura, inclusÃ£o e alteraÃ§Ã£o do fluxo; sem exclusÃ£o e sem tabela privada direta;
- `support`: leitura de clientes, consultas, propostas, interaÃ§Ãµes e pendÃªncias; pode registrar interaÃ§Ã£o e tratar pendÃªncia;
- `auditor`: leitura nÃ£o sensÃ­vel e trilha; nenhuma mutaÃ§Ã£o;
- `anon`: nenhuma policy operacional;
- schema privado: negaÃ§Ã£o direta por ausÃªncia de policy e grants.

O `service_role` contorna RLS e, por isso, sÃ³ pode existir em backend confiÃ¡vel. Appsmith nÃ£o deve receber `service_role` no navegador. O n8n deve guardar credenciais no gerenciador de credenciais e usar uma conta/conexÃ£o com o menor privilÃ©gio necessÃ¡rio.

O primeiro administrador nÃ£o Ã© criado pelo seed. ApÃ³s criar o usuÃ¡rio real pelo Supabase Auth, um operador autorizado deve promover explicitamente o UUID no SQL Editor:

```sql
insert into public.user_profiles (user_id, role, display_name)
values ('UUID-DO-USUARIO-AUTH', 'admin', 'Administrador inicial');
```

Nunca coloque UUID, e-mail ou credencial real em migration ou seed.

## Auditoria

`audit.events` Ã© append-only: `UPDATE` e `DELETE` sÃ£o bloqueados por trigger. AlteraÃ§Ãµes nas sete tabelas operacionais geram eventos com:

- entidade e identificador;
- `operation_id`, quando existir;
- origem `n8n`, `appsmith`, `gateway`, `human` ou `system`;
- aÃ§Ã£o e estados/cÃ³digos mÃ­nimos;
- papel e identidade, quando autenticados.

A trilha nÃ£o copia `status_raw`, motivo livre, resumo de interaÃ§Ã£o, CPF, RG, endereÃ§o, conta, link ou payload. Para integraÃ§Ãµes, o executor deve definir a origem na transaÃ§Ã£o, por exemplo:

```sql
set local app.change_origin = 'gateway';
```

Falhas de RLS puras acontecem antes de trigger e devem ser registradas pelo Gateway/n8n em uma chamada de auditoria confiÃ¡vel. A funÃ§Ã£o de resumo sensÃ­vel jÃ¡ registra acesso permitido/negado sem retornar valor em caso de negaÃ§Ã£o.

## Storage privado

A migration prepara, se o schema `storage` estiver disponÃ­vel, quatro buckets privados:

- `cbn-documents-private`;
- `cbn-raw-payloads-private`;
- `cbn-evidence-private`;
- `cbn-temporary-private`.

NÃ£o Ã© criada policy de acesso a `storage.objects`: a negaÃ§Ã£o Ã© intencional atÃ© existir backend validado. O nome do objeto deve ser UUID/hash e a referÃªncia fica em `protected_file_refs`. URLs assinadas sÃ£o geradas sob demanda, com expiraÃ§Ã£o curta, e nunca persistidas.

RetenÃ§Ã£o inicial a validar com jurÃ­dico/compliance:

- temporÃ¡rios: expiraÃ§Ã£o curta e remoÃ§Ã£o automÃ¡tica;
- payload bruto: somente pelo prazo de diagnÃ³stico/obrigaÃ§Ã£o;
- documentos e evidÃªncias: prazo legal/contratual aprovado;
- apÃ³s o prazo: remover objeto, marcar `deleted_at` e anonimizar referÃªncias nÃ£o obrigatÃ³rias.

Nenhum prazo definitivo foi inventado nesta tarefa.

## Appsmith, Sheets e logs

### Appsmith

Pode exibir IDs, produto, banco/oferta, estado normalizado, aÃ§Ã£o pendente, motivo mascarado, protocolo mascarado e Ãºltimos quatro dÃ­gitos quando uma funÃ§Ã£o controlada justificar. NÃ£o pode consultar tabela privada, receber `service_role`, ciphertext, URL completa ou segredo.

### Google Sheets

Somente exportaÃ§Ãµes de apoio com IDs, aliases, cÃ³digos, estados e mÃ¡scaras. Nunca CPF/RG/telefone completos, endereÃ§o, conta, links, payload, documento ou sessÃ£o.

### Logs

Podem conter `operation_id`, produto, `session_alias`, etapa, cÃ³digo, latÃªncia e decisÃ£o de retry. Nunca devem conter CPF, RG, endereÃ§o, conta, link completo, mensagem bruta, ciphertext, sessÃ£o, token ou chave. Erros devem ser normalizados antes de registrar.

## RetenÃ§Ã£o, anonimizaÃ§Ã£o e exclusÃ£o

1. Cada registro protegido recebe `retention_until` conforme polÃ­tica aprovada.
2. Uma rotina backend futura seleciona itens vencidos sem ler/registrar o conteÃºdo.
3. ConteÃºdo nÃ£o obrigatÃ³rio Ã© apagado; referÃªncias recebem `deleted_at` ou `anonymized_at`.
4. Identificadores e eventos exigidos para auditoria permanecem, sem dado completo.
5. Legal hold e obrigaÃ§Ã£o regulatÃ³ria devem suspender exclusÃ£o por regra documentada.
6. Toda execuÃ§Ã£o gera evento agregado, nunca cÃ³pia do conteÃºdo removido.

A rotina automÃ¡tica nÃ£o foi implementada porque prazo legal, legal hold e ambiente real ainda precisam de aprovaÃ§Ã£o.

## Backup e recuperaÃ§Ã£o

No projeto real, habilitar backups gerenciados/PITR conforme o plano Supabase, restringir acesso administrativo e testar restauraÃ§Ã£o em ambiente separado. Backup herda a sensibilidade do banco: acesso, retenÃ§Ã£o e descarte precisam seguir a mesma polÃ­tica. Esta entrega nÃ£o ativou nem simulou backup.

## Como aplicar em um Supabase real

1. Criar manualmente um projeto Supabase isolado de desenvolvimento, sem dados reais.
2. Configurar MFA, membros mÃ­nimos e regiÃ£o adequada; nÃ£o compartilhar credenciais.
3. Instalar a CLI e autenticar localmente sem versionar token.
4. Revisar o diff SQL, principalmente grants, policies, buckets e funÃ§Ãµes `security definer`.
5. Vincular o projeto com `supabase link --project-ref <PROJECT_REF>` usando referÃªncia pÃºblica, nunca senha no comando salvo.
6. Fazer `supabase db reset` local e executar o teste SQL antes da base remota.
7. Aplicar somente a migration com `supabase db push --dry-run` e revisar a saÃ­da.
8. ApÃ³s aprovaÃ§Ã£o humana, executar `supabase db push` no ambiente de desenvolvimento.
9. NÃ£o executar `supabase/seed.sql` em ambiente compartilhado; ele Ã© fixture local.
10. Criar usuÃ¡rios pelo Auth e promover o primeiro admin manualmente.
11. Configurar KMS/cofre e testar cifrar/decifrar com dado sintÃ©tico; a chave nÃ£o entra no banco.
12. Validar RLS com contas sintÃ©ticas de cada papel e confirmar negaÃ§Ãµes.
13. Configurar policies de Storage somente para o backend confiÃ¡vel e testar URLs curtas.
14. Configurar backup/PITR, retenÃ§Ã£o e um teste de restauraÃ§Ã£o.
15. SÃ³ depois planejar conexÃµes de n8n/Appsmith em tarefas prÃ³prias.

## ValidaÃ§Ã£o local preparada

- `supabase/tests/bkl016_secure_storage_test.sql`: existÃªncia, RLS, negaÃ§Ã£o sem papel, isolamento privado, auditor read-only, unicidade, produto, oferta obrigatÃ³ria e auditoria append-only;
- `scripts/validate-bkl016.ps1`: estrutura esperada, seed sintÃ©tico, ausÃªncia de `.env`, padrÃµes de segredo e CPF completo;
- `supabase/seed.sql`: somente cliente, operaÃ§Ã£o, consulta e oferta claramente sintÃ©ticos.
- `supabase/rollback/20260715_001_bkl016_secure_storage_down.sql`: rollback manual e destrutivo somente para desenvolvimento limpo; buckets com objetos nÃ£o sÃ£o apagados silenciosamente.

Se Docker/Supabase CLI nÃ£o estiverem disponÃ­veis, o teste de banco ficarÃ¡ preparado, mas nÃ£o executado. Isso deve ser registrado como limitaÃ§Ã£o, sem marcar BKL-016 como concluÃ­da.

## Riscos restantes

- migration ainda nÃ£o executada em uma instÃ¢ncia Supabase limpa;
- polÃ­ticas ainda precisam de teste dinÃ¢mico com usuÃ¡rios Auth de cada papel;
- KMS/cofre, rotaÃ§Ã£o e recuperaÃ§Ã£o de chave nÃ£o foram escolhidos;
- prazos legais de retenÃ§Ã£o e legal hold precisam de validaÃ§Ã£o;
- policies de objetos Storage continuam deliberadamente ausentes;
- backup/PITR e restauraÃ§Ã£o ainda nÃ£o foram testados;
- rotina de anonimizaÃ§Ã£o/exclusÃ£o ainda nÃ£o foi implementada;
- funÃ§Ãµes e grants devem passar por revisÃ£o independente antes da aplicaÃ§Ã£o;
- BKL-018 e BKL-020 completarÃ£o autenticaÃ§Ã£o/perfis e auditoria canÃ´nica.

## Checklist para aprovar a aplicaÃ§Ã£o futura

- [ ] migration aplicada em projeto Supabase limpo de desenvolvimento;
- [ ] teste SQL executado sem falhas;
- [ ] RLS testada com usuÃ¡rio sem papel, admin, operations, support e auditor;
- [ ] acesso direto ao schema privado negado;
- [ ] Appsmith sem `service_role` e sem acesso privado;
- [ ] n8n usando cofre e credencial mÃ­nima;
- [ ] buckets confirmados como privados e sem nome de arquivo com PII;
- [ ] URLs assinadas expiram e nÃ£o aparecem em logs;
- [ ] KMS/cofre e rotaÃ§Ã£o aprovados;
- [ ] retenÃ§Ã£o, anonimizaÃ§Ã£o, legal hold e backup aprovados;
- [ ] varredura de segredos e dados pessoais aprovada;
- [ ] documentaÃ§Ã£o e handoff revisados;
- [ ] BKL-016 somente entÃ£o avaliada para conclusÃ£o.
