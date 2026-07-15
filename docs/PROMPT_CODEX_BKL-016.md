# Prompt para o Codex — BKL-016

Você está trabalhando no repositório `sholdam/cbn`, projeto CBN Crédito.

## Contexto do projeto

O projeto está construindo uma operação autônoma de crédito multiproduto para FGTS e Crédito do Trabalhador (CLT), com:

- captação por Meta/WhatsApp;
- automações no n8n;
- Gateway interno para consultas e propostas;
- integração provisória via Telegram MTProto;
- Supabase/PostgreSQL como fonte principal de dados;
- Appsmith como painel operacional interno;
- Google Sheets apenas como apoio, contingência e exportação;
- Power BI reservado para análise gerencial futura.

Leia antes de alterar qualquer coisa:

- `docs/HANDOFF.md`
- `docs/ARQUITETURA_TECNICA.md`
- `docs/DICIONARIO_DADOS.md`
- `docs/BACKLOG_CHECKPOINT.md`
- `telegram-gateway/`

A tarefa atual é **BKL-016 — Definir e preparar o armazenamento de dados sensíveis**.

## Objetivo desta execução

Criar a fundação técnica segura do Supabase/PostgreSQL para receber dados estruturados e sensíveis sem expor CPF, RG, endereço, conta bancária, links operacionais, sessões Telegram, tokens ou retornos brutos em tabelas abertas, logs comuns ou no GitHub.

Não conectar ainda dados reais, WhatsApp, Telegram, n8n, Appsmith ou produção.

Use apenas dados sintéticos de teste.

## Regras obrigatórias

1. Não criar, copiar, imprimir ou commitar qualquer segredo.
2. Não alterar ou apagar o fluxo MTProto já validado.
3. Não usar dados reais de clientes.
4. Não armazenar sessão Telegram, `api_hash`, senha, token ou chave em tabela operacional.
5. Não expor `service_role` no frontend, no Appsmith ou em código cliente.
6. Não criar criptografia caseira.
7. Não registrar CPF, RG, endereço, conta ou link completo em logs.
8. Aplicar princípio do menor privilégio.
9. Manter toda mudança reversível por migration.
10. Não fazer deploy e não criar projeto Supabase automaticamente.
11. Não marcar a BKL-016 como concluída; esta execução prepara a base, mas a validação no ambiente real será posterior.

## Arquitetura esperada

Criar uma separação clara entre:

### Dados operacionais

Podem ser lidos pelo painel conforme permissão, sempre sem dados completos sensíveis:

- clientes;
- consultas;
- ofertas;
- propostas;
- interações;
- pendências;
- operações técnicas;
- estados e códigos normalizados;
- versões mascaradas;
- referências seguras.

### Dados sensíveis

Devem ficar em estrutura separada e com acesso restrito:

- CPF completo;
- RG e metadados de documento;
- endereço;
- dados bancários;
- links de assinatura;
- payloads brutos protegidos;
- referências de arquivos.

### Segredos

Não pertencem ao banco operacional:

- sessão MTProto;
- `api_id`;
- `api_hash`;
- 2FA;
- tokens;
- chaves privadas;
- credenciais de provedores.

Documentar que esses itens devem ficar no cofre de credenciais do ambiente/n8n/Supabase e nunca em migrations, seed, exemplos ou logs.

## Entregas obrigatórias

### 1. Estrutura Supabase

Criar, preferencialmente:

- `supabase/config.toml`, caso ainda não exista e seja necessário para desenvolvimento local;
- `supabase/migrations/20260715_001_bkl016_secure_storage.sql`;
- `supabase/seed.sql` contendo somente dados sintéticos e claramente identificados como teste.

A migration deve ser idempotente quando possível e conter comentários explicativos.

### 2. Extensões e identificadores

Usar recursos padrão do PostgreSQL/Supabase, como:

- `pgcrypto` somente para UUID/hash quando adequado;
- UUID como identificador principal;
- timestamps com fuso (`timestamptz`);
- `created_at` e `updated_at`;
- constraints e índices necessários.

Não guardar a chave de criptografia dentro do banco ou da migration.

### 3. Schemas e tabelas

Criar uma divisão equivalente a:

- schema operacional exposto de forma controlada;
- schema privado para conteúdo sensível;
- schema de auditoria, caso faça sentido.

As tabelas devem refletir o dicionário de dados já documentado, sem tentar implementar todos os 72 campos à força. Priorize a fundação mínima correta e extensível.

Estruturas mínimas esperadas:

#### Operacionais

- `clients`
- `consultations`
- `offers`
- `proposals`
- `interactions`
- `pending_items`
- `technical_operations`

#### Privadas

- `client_sensitive_data`
- `proposal_sensitive_data`
- `protected_payloads`
- `protected_file_refs`

#### Segurança e acesso

- `user_profiles`
- definição inicial de papéis, por exemplo:
  - `admin`
  - `operations`
  - `support`
  - `auditor`

Os papéis podem ser preparados nesta fase, mas não é necessário concluir toda a BKL-018.

### 4. Regras de modelagem

Aplicar no mínimo:

- `client_id` estável;
- produto obrigatório em Consulta, Oferta e Proposta: `FGTS` ou `CLT`;
- FGTS e CLT independentes;
- `operation_id` único e persistente;
- uma Proposta vinculada a uma Oferta;
- status bruto e status normalizado em campos separados;
- ação pendente e motivo em campos separados;
- links completos fora da tabela operacional;
- `session_alias` no lugar de sessão Telegram;
- dados mascarados em colunas operacionais, quando necessários;
- campos de retenção, como `retention_until` ou equivalente;
- campo de exclusão/anônimização controlada, sem apagar trilha obrigatória indevidamente.

### 5. Row Level Security

Ativar RLS em todas as tabelas acessíveis pela API.

Criar políticas iniciais conservadoras:

- acesso negado por padrão;
- `admin`: acesso operacional amplo;
- `operations`: leitura e alteração do fluxo necessário, sem acesso direto irrestrito aos dados privados;
- `support`: acesso somente ao necessário para atendimento e pendências;
- `auditor`: somente leitura de dados não sensíveis e trilha de auditoria;
- dados privados acessados somente por funções controladas ou backend confiável;
- operações de sistema feitas pelo backend/n8n, nunca pelo navegador com `service_role` exposto.

Funções `security definer`, se usadas, devem:

- definir `search_path` explicitamente;
- validar papel e identidade;
- retornar somente o mínimo necessário;
- nunca retornar segredo;
- evitar SQL dinâmico inseguro.

### 6. Auditoria mínima

Preparar trilha append-only para eventos importantes:

- criação e alteração de cliente;
- consulta;
- oferta;
- proposta;
- mudança de status;
- acesso controlado a dado sensível;
- tentativa negada relevante;
- origem da alteração: `n8n`, `appsmith`, `gateway`, `human`, `system`.

A auditoria não pode armazenar valor completo sensível.

### 7. Storage

Documentar e, quando seguro via migration, preparar buckets privados para:

- documentos;
- payloads brutos;
- evidências;
- links ou arquivos temporários.

Regras:

- buckets privados;
- nomes de arquivos sem CPF, RG ou telefone;
- acesso por referência/UUID;
- URLs assinadas com expiração;
- nada público;
- política de retenção documentada.

Caso a criação segura de buckets/policies dependa do projeto Supabase real, deixar SQL ou instrução preparada, mas não inventar credenciais nem simular que foi aplicado.

### 8. Documentação

Criar:

- `docs/BKL-016_ARMAZENAMENTO_DADOS_SENSIVEIS.md`

O documento deve explicar:

- o que fica no PostgreSQL operacional;
- o que fica no schema privado;
- o que fica no Storage;
- o que fica no cofre de secrets;
- o que pode aparecer no Appsmith;
- o que pode aparecer no Sheets;
- o que pode aparecer em logs;
- como funciona o acesso mínimo;
- como funcionará retenção, anonimização e exclusão;
- riscos restantes;
- passos para aplicar em um projeto Supabase real;
- checklist de validação.

Atualizar também, sem apagar histórico:

- `docs/HANDOFF.md`
- `docs/ARQUITETURA_TECNICA.md`
- `docs/BACKLOG_CHECKPOINT.md`

Registrar que a base foi **preparada no código**, porém ainda não aplicada e validada em ambiente Supabase real.

### 9. Variáveis de ambiente

Atualizar `.env.example` somente com nomes seguros e placeholders vazios, por exemplo:

- `SUPABASE_URL=`
- `SUPABASE_ANON_KEY=`
- `SUPABASE_SERVICE_ROLE_KEY=`
- `DATABASE_URL=`

Adicionar comentários de segurança deixando claro:

- `service_role` somente em backend confiável;
- nenhuma chave deve ir para GitHub;
- Appsmith não deve usar `service_role` no navegador;
- n8n deve guardar credenciais no gerenciador de credenciais.

Não alterar o `.env` real e não criar credenciais fictícias parecidas com chaves reais.

### 10. Testes e validação local

Criar validações automatizadas ou scripts SQL que comprovem, pelo menos:

- tabelas esperadas existem;
- RLS está ativa;
- usuário sem papel não acessa dados;
- auditor não altera registros;
- operador não lê diretamente conteúdo privado completo;
- `operation_id` não duplica;
- Proposta exige Oferta válida;
- produto aceita somente `FGTS` ou `CLT`;
- seed usa somente dados sintéticos;
- nenhum arquivo criado contém padrão de chave, sessão ou dado real.

Caso não seja possível executar Supabase local no ambiente, deixe os testes preparados e documente claramente o que não foi executado.

## Critérios de aceite desta execução

A execução será considerada aprovada quando:

1. a migration puder ser revisada e aplicada em um projeto Supabase limpo;
2. dados operacionais e dados sensíveis estiverem separados;
3. RLS estiver ativada e conservadora;
4. não houver segredo no repositório;
5. não houver dado real no seed/testes;
6. a documentação indicar exatamente onde cada tipo de dado fica;
7. Appsmith, n8n e Power BI estiverem tratados apenas como consumidores futuros, sem conexão prematura;
8. o histórico do projeto estiver preservado;
9. limitações e itens não executados estiverem declarados sem mascarar falhas;
10. a BKL-016 permanecer como em andamento até aplicação e validação no ambiente real.

## Forma de trabalho

1. inspecione o repositório antes de alterar;
2. apresente um plano curto;
3. implemente em mudanças pequenas e revisáveis;
4. execute os testes disponíveis;
5. revise o diff procurando segredos e dados pessoais;
6. entregue um relatório final contendo:
   - arquivos criados e alterados;
   - decisões tomadas;
   - testes executados;
   - resultados;
   - riscos restantes;
   - instruções exatas para aplicar no Supabase real;
   - confirmação de que nenhum segredo ou dado real foi incluído.

Não faça merge automático. Não faça deploy. Não crie proposta real. Não conecte contas reais.