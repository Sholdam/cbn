# Backlog — checkpoint de 15/07/2026

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
- nenhuma conexão a banco/projeto remoto, migration, usuário, fixture, objeto, n8n ou Appsmith foi criada.

Após a primeira autorização, o vínculo foi concluído e a inspeção somente leitura encontrou histórico remoto de migrations vazio, migration local `20260715` pendente e nenhuma tabela reportada. Após autorização separada, o dry-run listou somente `20260715_001_bkl016_secure_storage.sql` e não alterou o projeto.

**Bloqueio deliberado:** terceira parada antes de `supabase db push`. A aplicação exige nova autorização explícita. Validação remota, Storage, limpeza, KMS e backup/restauração continuam pendentes e impedem concluir a BKL-016.

## Tarefas vivas paralelas

- BKL-007 — validação regulatória e operacional;
- BKL-011 — catálogo de produtos contínuo;
- BKL-012 — fluxo FGTS pós-oferta;
- BKL-013 — assinatura, análise, aprovação, pagamento ou cancelamento.
