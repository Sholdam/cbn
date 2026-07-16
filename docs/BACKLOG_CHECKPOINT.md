# Backlog — checkpoint de 15/07/2026

## BKL-016 — identidade mínima do backend (16/07/2026)

- Migration incremental `20260720_001` cria quatro papéis sem LOGIN e sem
  atributos administrativos.
- Gateway, retenção, revisão de hold e conclusão de descarte estão separados por
  wrappers controlados; não existe grant direto a tabelas privadas ou auditoria.
- Matriz de privilégios, runbook, rollback e suíte SQL foram adicionados.
- Resultado local: 44/44 testes Node; cinco suítes SQL; rollback recusado com
  auditoria indispensável; rollback limpo e reaplicação aprovados.
- Status da BKL-016: **Em andamento**. Não houve merge, deploy ou conexão remota.

## BKL-016 — revisão corretiva de retenção (16/07/2026)

Status: **Em andamento**.

Bloqueadores corrigidos localmente: auditoria persistente de negações,
anonimização fail-closed com inventário completo, prevenção de reidentificação,
hold superior de cliente, revalidação entre prepare/complete e segregação entre
solicitante/aprovador. Migration incremental `20260719_001`, rollback, quatro
suítes SQL, 36 testes Node e runtime Storage aprovados.

Não houve merge, deploy ou conexão remota.

## BKL-016 — checkpoint de retenção e legal hold (16/07/2026)

Status: **Em andamento**.

Concluído localmente: migration incremental, política configurável, legal hold,
anonimização idempotente, exclusão em duas fases, auditoria, Storage sintético,
rollback fail-closed, restauração pós-anonimização e reaplicação.

Pendente: aprovação jurídica de prazos/finalidades, KMS real bloqueado por
faturamento, papel backend mínimo, execução em desenvolvimento remoto autorizada,
reconciliação operacional e revisão técnica independente.

## Concluído anteriormente

### BKL-014 — Decidir a rota técnica da integração multiproduto

Status: **Concluído para a prova técnica inicial**.

Evidências:

- arquitetura de três contas confirmada;
- sessão MTProto autorizada;
- persistência após reinício comprovada;
- retry idempotente com o mesmo `operation_id` comprovado.

## BKL-012 — mapeamento das propostas

### CLT

O fluxo de digitação foi confirmado até a criação e o protocolo, incluindo documento, data, COMPE, agência, conta com dígito, tipo de conta, revisão, correção e confirmação final.

### FGTS

As consultas observadas ainda não retornaram oferta. Campos pós-oferta permanecem como **A confirmar FGTS**, sem regra inferida do CLT.

## BKL-013 — acompanhamento

No CLT foram confirmados:

- proposta criada;
- consulta por contrato;
- status `Em análise de compliance`;
- assinatura pendente;
- motivo operacional;
- link de assinatura/coleta.

Status, ação pendente, motivo e link são campos separados.

## BKL-015 — Dicionário de Dados multiproduto

Status: **Concluído v1**.

Foi criada a aba `Dicionário de Dados`, com `DD-001` a `DD-072`, cobrindo:

- Cliente;
- Consulta;
- Oferta;
- Proposta;
- Interação;
- Pendência;
- Operação técnica.

Foram alinhadas as abas operacionais:

- `Clientes`;
- `Consultas`;
- `Ofertas`;
- `Propostas`;
- `Interações`;
- `Pendências`;
- `Operações Técnicas`.

### Critérios atendidos

- cada entidade possui identificador próprio;
- Consulta, Oferta e Proposta possuem produto obrigatório;
- FGTS e CLT possuem estados e operações independentes;
- `operation_id` está presente nas estruturas técnicas e comerciais;
- status original, status normalizado, ação pendente e motivo não se sobrescrevem;
- campos sensíveis usam referências protegidas ou versões mascaradas;
- sessão Telegram é representada apenas por `session_alias`;
- campos FGTS não observados estão marcados como pendentes, sem regra inventada.

### Segurança incorporada

- CPF completo: tokenização ou referência em banco protegido;
- RG, endereço e dados bancários: storage criptografado;
- sessão MTProto: cofre de secrets;
- link de assinatura: referência protegida;
- retorno bruto e logs: storage protegido e mascarado;
- MTProto: `random_id` determinístico a partir do `operation_id`.

Novos campos FGTS serão manutenção do dicionário e não reabrem a arquitetura.

## DE-002 — Sistema interno e camada de dados

Decisão aprovada:

- **Supabase/PostgreSQL:** fonte principal de dados e memória;
- **Appsmith:** interface interna da operação;
- **n8n/Gateway:** regras, integrações, idempotência e execução;
- **Google Sheets:** apoio temporário, exportação e contingência;
- **Power BI:** camada analítica futura, não operacional.

A implantação será distribuída pelas tasks já existentes, evitando criar um projeto paralelo que interrompa o fluxo principal:

- BKL-016 — schema, proteção, RLS, backup, storage e secrets;
- BKL-018 — autenticação, perfis e permissões no Supabase/Appsmith;
- BKL-020 — trilha de auditoria canônica no PostgreSQL;
- BKL-024 — memória e máquina de estados persistidas;
- BKL-035 — painel Appsmith de monitoramento operacional;
- BKL-048 — KPIs no Appsmith e avaliação posterior do Power BI.

## Próxima tarefa operacional

### BKL-016 — Base protegida e fundação do sistema interno

Status: **Em andamento**.

Decisões já tomadas:

1. Supabase/PostgreSQL será o banco principal;
2. Appsmith será conectado apenas depois da validação do ambiente e das permissões;
3. Power BI fica fora do MVP operacional;
4. o primeiro ambiente usará somente dados sintéticos;
5. a planilha continuará contendo apenas referências, aliases, códigos, resumos e dados mascarados.

Próximas ações:

1. o usuário criar/selecionar projeto Supabase isolado de desenvolvimento e informar apenas o project ref não secreto;
2. executar preflight e inspeção sem escrita após autorização explícita;
3. executar `db push --dry-run`, revisar e parar novamente antes da aplicação;
4. aplicar/validar migration, RLS, Storage e integridades somente após segunda autorização;
5. remover fixtures/objetos sintéticos por manifesto explícito e revalidar;
6. decidir KMS/cofre e comprovar backup/restauração conforme o plano real;
7. manter n8n e Appsmith desconectados até aprovação independente.

### Checkpoint de preparação no repositório — 15/07/2026

Status permanece: **Em andamento**.

Foi preparada, sem deploy, a fundação revisável da BKL-016:

- migration com tabelas operacionais e schema privado separado;
- `operation_id` canônico, produto fechado em FGTS/CLT e proposta vinculada à oferta;
- RLS e papéis iniciais `admin`, `operations`, `support` e `auditor`;
- auditoria mínima append-only e sem valores completos sensíveis;
- buckets privados preparados, sem acesso público;
- seed somente sintético, teste SQL e varredura estática;
- documentação de Storage, cofre, exibição, logs, retenção, anonimização, backup e aplicação real.

Ainda pendem escolha de KMS/cofre, policies finais de Storage, prazos legais, backup/restauração, ambiente remoto isolado e validação independente. Nenhuma conta real foi conectada.

### Revisão técnica da fundação

Os bloqueios encontrados na primeira revisão foram corrigidos no código:

- constraint inválida de Interação substituída por validação de `event_type`;
- campos mascarados exigem asterisco e rejeitam CPF/telefone completos;
- evidência final da proposta passou a referenciar payload protegido obrigatório;
- a integridade da evidência final foi fechada por FK composta de payload, cliente, operação e tipo;
- evidências finais exigem cliente/operação desde a criação e podem preceder a proposta sem ciclo;
- consultas e propostas agora exigem que `operation_id`, cliente e produto coincidam com a operação técnica;
- rollback foi ajustado à proteção nativa do Storage para preservar buckets que contenham objetos;
- rollback respeita as FKs cruzadas entre `public` e `app_private`;
- suíte SQL agora exercita RLS com usuários/roles sintéticos reais;
- privilégios de `anon` e o caminho backend para ciphertext foram documentados.

Em 15/07/2026, migration e seed foram aplicados em Supabase local descartável. A suíte completa passou duas vezes, antes e depois do rollback/reaplicação. O rollback removeu toda a estrutura BKL-016 e buckets vazios, preservou um bucket com objeto sintético e não deixou funções ou constraints quebradas. Nenhum projeto remoto foi vinculado ou acessado.

### Checkpoint da preparação remota — 15/07/2026

Status permanece: **Em andamento**.

- branch `codex/bkl-016-remote-dev` criada a partir da `main` atualizada;
- ferramentas disponíveis: Docker 29.6.1, Compose 5.3.0, Supabase CLI 2.109.1 e psql 17.10;
- CLI autenticada interativamente, projeto isolado `cbn-dev` confirmado duas vezes e vínculo local correspondente;
- runbook remoto, preflight fail-closed, validador SQL/PowerShell e limpeza sintética por manifesto preparados;
- a CLI instalada oferece `db push --dry-run`;
- metadados de vínculo continuam ignorados e schemas privados continuam fora do PostgREST local;
- nenhuma conexão com produção, usuário Auth, fixture persistente, objeto Storage, n8n ou Appsmith foi criada.

Após a primeira autorização, o vínculo foi concluído e a inspeção somente leitura encontrou histórico remoto de migrations vazio, migration local `20260715` pendente e nenhuma tabela reportada. Após autorização separada, o dry-run listou somente `20260715_001_bkl016_secure_storage.sql` e não alterou o projeto.

Após uma terceira autorização explícita, somente `20260715_001_bkl016_secure_storage.sql` foi aplicada, sem seed. A primeira validação remota encontrou grant operacional indevido para `anon`; `20260716_001_bkl016_revoke_anon_operational_grants.sql` foi então preparada, passou em dry-run e foi aplicada sem seed.

Depois da correção, os marcadores `BKL-016 remote structural checks passed` e `BKL-016 database and RLS checks passed` foram atingidos. As fixtures usaram transação com `ROLLBACK`; o inspetor reportou zero linhas estimadas nas 13 tabelas. Foram validados `anon`, usuário sem perfil, support, operations, auditor, admin, schema privado, integridades cliente/produto/operação/evidência, snapshot de oferta e auditoria append-only.

Storage estrutural passou: quatro buckets privados, ausência de policy pública e `anon` sem grants. A CLI experimental recusou o primeiro upload sem criar objeto, lacuna posteriormente fechada pelo runtime backend validado. O painel confirmou plano Free sem backup agendado e sem PITR; dump manual somente de schema passou e foi removido, mas restauração continua não comprovada. KMS gerenciado com envelope encryption é a recomendação técnica, pendente de provedor, custo e aprovação. Esses itens, retenção/legal hold e revisão independente impedem concluir a BKL-016.

### Checkpoint do runtime de Storage — concluído

Foi criada a branch `codex/bkl-016-storage-runtime` a partir da `main` atualizada. O código backend descartável usa a biblioteca oficial do Supabase, objeto e conteúdo exclusivamente sintéticos em memória, bucket temporário em allowlist, bloqueio de overwrite, validação SHA-256, URL assinada curta, varredura de vazamento e limpeza remota em `finally`. O preflight também recusa `main`, árvore suja, alvo divergente, migration não conciliada e repositório com segredo ou PII.

Os 9 testes negativos locais, o validador estático e o preflight remoto sanitizado passaram. Após o gate humano, o ciclo real aprovou upload sintético de 94 bytes, negação anônima `4xx`, hash antes da expiração, falha `4xx` após 36 segundos para TTL de 30 segundos, varredura sem vazamento, limpeza e revalidação SQL `complete/passed`. A listagem recursiva final do bucket encontrou zero objetos. Nenhuma URL, credencial, fixture ou usuário Auth persistiu. KMS/cofre, restauração, retenção/legal hold, policies finais e revisão independente continuam abertos, logo a BKL-016 permanece **Em andamento**.

### Checkpoint de KMS/envelope local — 15/07/2026

Status permanece: **Em andamento**.

Foi preparado um contrato KMS sem SDK cloud, adaptador estritamente local e serviço AES-256-GCM com DEK/nonce únicos, AAD canônica e falha fechada. A migration incremental `20260717` acrescenta metadados completos e constraints de coerência a payloads/arquivos protegidos, preserva linhas legadas e possui rollback que recusa perda de envelopes novos.

Os testes sintéticos cobrem round-trip, plaintext vazio, aleatoriedade, troca de contexto, adulteração de todos os componentes, versões inválidas, rewrap de KEK, rotação completa de DEK, recuperação em falha e saída segura. A matriz oficial compara KMS gerenciado, Vault Transit e cofre de credenciais com envelope no Gateway. A recomendação preliminar é avaliar KMS gerenciado, sem escolha automática.

**Gate aberto:** Guilherme ainda precisa aprovar provedor, região, custo, identidade mínima, auditoria, recuperação e retenção de versões. É proibido autenticar, ativar billing/API, criar/importar chave ou gravar segredo externo antes dessa decisão. Restauração, retenção/legal hold, policies finais e revisão independente também continuam pendentes.

### Checkpoint de backup/restauração sintética — 16/07/2026

Status da fase: **Concluída localmente**. Status da BKL-016 geral: **Em andamento**.

- schema preservado em dump de verificação e reconstruído por migrations;
- dados exclusivamente sintéticos restaurados de dump separado;
- objeto do Storage privado restaurado com SHA-256 idêntico;
- envelope recuperado com KEK local efêmera correta;
- versão de KEK ausente falhou fechada;
- ciphertext adulterado falhou em autenticação;
- rollback incremental recusou perda dos metadados do envelope;
- suíte RLS e constraints do envelope passaram após a restauração;
- RTO local final de 105,08 s; RPO sintético de snapshot exato;
- dumps, manifesto, objeto, KEK e stack removidos ao final;
- nenhuma conexão remota, cloud, billing, credencial externa, dado real ou produção.

Continuam pendentes: KMS real (bloqueado por faturamento), política de backup de produção/PITR, retenção/legal hold, policies finais e revisão independente.

## Tarefas vivas paralelas

- BKL-007 — validação regulatória e operacional;
- BKL-011 — catálogo de produtos contínuo;
- BKL-012 — fluxo FGTS pós-oferta;
- BKL-013 — assinatura, análise, aprovação, pagamento ou cancelamento.
