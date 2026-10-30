# Backlog — checkpoint oficial de 17/07/2026

## CPF dos anúncios INSS — 30/10/2026

- Fechada lacuna de anúncio sem etiqueta e botão sem suporte INSS: web/worker atualizados e atendimento indicado retomado; uma confirmação `sent`, cadastro/etiquetas/agente conferidos. Sete verificações sintéticas passaram. Acompanhar próximo fluxo orgânico; não confundir `sent` com entrega confirmada. [Registro](CRM_INSS_CAPTURE_2026-10-30.md).

- Publicada correção da coleta e espelhamento de etiqueta. Recuperadas somente as três conversas indicadas, sem novos envios. Confirmação automática em novo atendimento ainda não observada. [Registro](CRM_INSS_CAPTURE_2026-10-30.md).

## Atendimento de chamadas WhatsApp — 28/10/2026

- Pedido registrado, não habilitado: conexão operacional WAHA/GOWS não documenta transporte de áudio para atender pelo CRM. Caminho oficial depende de Cloud API, licença paga e elegibilidade do número, ainda não avaliadas para migração. Diagnóstico somente leitura. [Detalhes](CRM_WHATSAPP_CALLING_2026-10-28.md).

## Saudação personalizada nas respostas prontas — 27/10/2026

- Concluído ajuste nativo do atalho `tele`: primeiro nome do contato com inicial maiúscula por `{{contact.first_name}}`. Corpo preservado e releitura confirmada; sem alteração de código ou envio a clientes. [Detalhes](CRM_CANNED_FIRST_NAME_2026-10-27.md).

## Reabertura de conversas resolvidas — 26/10/2026

- Publicada política de reabertura no modelo de mensagens dos quatro serviços Rails; inclui mensagens de bots/plugin/agendador e anexos. Regra 15 provisória desativada para evitar eventos tardios. SSH recuperado com troca apenas do IP /32 explicitamente autorizada. Carregamento/hashes e disponibilidade conferidos, sem suíte ou envio de teste. [Operação e rollback](CRM_REOPEN_ON_INTERACTION_2026-10-26.md).

## Indisponibilidade simultânea — 23/10/2026

- CRM/site retornaram espontaneamente; HTTP 200 e WhatsApp WORKING confirmados. Reinício do VPS registrado às 15h47 de Brasília, causa não comprovada. Sem intervenção remota ou mudança de configuração. [Registro](CRM_SITE_INCIDENT_2026-10-23.md).

## Menu de atendimento inicial — 22/10/2026

- Corrigido botão Retomar bot para iniciar menu em conversa anterior à ativação e retomar somente as opções. Rota autenticada usada no atendimento real solicitado: saudação e menu entregues, aguardando resposta. Sem envio de teste. [Detalhes](CRM_GENERIC_CREDIT_MENU_2026-10-22.md).
- Criadas e ativadas regras 12/13/14 e complemento isolado: saudação, menu de seis produtos, etiqueta e encaminhamento humano após seleção. Guardas contra repetição, histórico, intervenção humana e cruzamento com anúncios.
- Conferidos sintaxe, carregamento e disponibilidade; sem suíte ou disparo de teste. Confirmar entrega/resposta no primeiro atendimento orgânico. [Runbook](CRM_GENERIC_CREDIT_MENU_2026-10-22.md).

## Anexos no agendamento — 20/10/2026

- Tela, API, dispatcher e plugin atualizados para arquivos com ou sem texto; sem migração ou mudança de credenciais. Builds/sintaxe e disponibilidade conferidos, sem disparo de teste. [Runbook](CRM_SCHEDULE_ATTACHMENTS_2026-10-20.md).

## Conversas pendentes e nome da fila — 20/10/2026

- 27 conversas de todas as caixas passaram de `pending` para `resolved` por autorização explícita; zero pendentes na conferência final pelo plugin.
- Nome Secretária publicado somente no web, preservando enum/API e comportamento existente. [Runbook](CRM_SECRETARIA_STATUS_2026-10-20.md).

## Data de nascimento e Secretaria — 20/10/2026

- Data de nascimento: cópia/visualização brasileira publicada somente no serviço web, imagem `cbn/chatwoot:4.16.2-cbn-date-copy-20261020`. Sem mudança de cadastro/WhatsApp ou envio de mensagens. [Publicação e rollback](CRM_CONTACT_DATE_COPY_2026-10-20.md).
- Secretaria: requisito de reação imediata aos 20 leads registrado; receptor HTTPS, fila deduplicada e assinatura MCP Events dependem de destino Work/Cloud compatível ou agente backend definido. [Plano](CRM_SECRETARIA_EVENTS_2026-10-20.md). Não implantado.

## Retomada manual do bot — 20/10/2026

- Atalho “Retomar bot” publicado no cabeçalho. Retoma a coleta conhecida, aproveita dados já salvos e pode repetir a pergunta pendente, mantendo validações e proteção contra duplicação.
- Rota/auth/backend carregados e botão conferido no navegador. Primeiro uso de envio pelo botão depende do clique explícito do operador; nenhum disparo de teste realizado. [Runbook](CRM_BOT_RESUME_2026-10-20.md).

## Coleta em respostas com anúncio — 20/10/2026

- Corrigida leitura da seção “MENSAGEM DO CLIENTE” nos envelopes WAHA para CPF, matrícula e vínculo. Mantém validação, proteção contra conflitos, expiração e idempotência.
- Recuperação limitada à conversa apontada pelo proprietário; sem replay geral de eventos ou histórico. [Runbook](CRM_COLATINA_CADASTRO_ETIQUETAS_2026-10-19.md#respostas-dentro-do-envelope-do-anúncio).

## Compatibilidade de formatação WhatsApp — 20/10/2026

- Refinamento visual após retorno do proprietário: barra de formatação sempre visível no compositor, com contraste e botões maiores. Imagem persistente `cbn/chatwoot:4.16.2-cbn-whatsapp-toolbar-20261020`, CSS com hash novo e conferência visual na aba aberta. Sem envio de mensagem.

- Ajuste do editor da caixa WAHA e conversor de saída implantado. Suporte à sintaxe WhatsApp na digitação/colagem e conversão CommonMark para envio com espaços/linhas tratados.
- Build e disponibilidade conferidos; nenhum envio de teste. Acompanhar próximo envio orgânico para confirmar aparência no cliente WhatsApp. [Runbook](CRM_WHATSAPP_FORMATTING_2026-10-20.md).

## Correção operacional Colatina — 19/10/2026

- Resolvida falha de serialização na identificação de perguntas automáticas. Complemento usa a mensagem retornada pelo serviço nativo, conservando idempotência e roteiro ADS.
- Cinco saudações faltantes recuperadas individualmente, com status `delivered`; sem duplicações. Fluxo completo conferido com rollback, sem envio de teste a clientes. Acompanhar as próximas respostas orgânicas para confirmar a coleta em operação.
- Detalhes no runbook [Colatina](CRM_COLATINA_CADASTRO_ETIQUETAS_2026-10-19.md#correção-de-envio-e-recuperação-dos-cinco-leads).

## CRM Colatina — vínculo numerado — 19/10/2026

- Etapa 11 ativa após matrícula: 1 Comissionado / 2 Efetivo / 3 Temporário. Registra autodeclaração e segue para atendente; sem decisão automática ou pedido de contracheque.
- Gatilho 8 reconhece anúncio original e V2. Código/configuração implantados com backup. 10 testes sintéticos/30 asserções aprovados, sem disparo para clientes.
- [Detalhes e rollback](CRM_COLATINA_CADASTRO_ETIQUETAS_2026-10-19.md).

## Recuperação do HD — 02/10/2026

- Reparo do Ubuntu e do cofre autorizado sem backup completo; journals
  recuperados e sistemas de arquivos novamente graváveis.
- CRM/site local e público 200, API privada 401, dez containers ativos,
  WAHA `WORKING`, keepalive e recuperação automática reativados.
- Corrigida montagem para namespaces systemd/Docker e desmontagem segura
  correspondente; início do Rails aguarda até cinco minutos.
- Backup independente e auditoria completa dos dados continuam pendentes.
  Distro `CBN-Recovery` parada, disponível para manutenção futura.

## Acesso adicional — 30/09/2026

- Agente humano `8` criado e confirmado por autorização explícita, somente
  na caixa WAHA `5`. Proprietário `1` e conta técnica `7` preservados.
  Credenciais não pertencem ao repositório.

## Disponibilidade e endereço — 30/09/2026

- Acesso restaurado após encontrar WSL parado, com Toshiba saudável.
  Endereço ativo renomeado: <https://crmcbn.up.railway.app/>.
- Keepalive independente do chat pelo Agendador do Windows; recuperação
  configurada por minuto e no logon. Execução retornou 0; checagem confirmou
  cofre, dez containers, HTTP 200, API privada 401 e WAHA `WORKING`.
- Parada segura tem flag de manutenção; reinício automático não deve
  reabrir cofre após pedido de parada. PC/HD/internet continuam necessários.
  Não foi feito reboot nem parada artificial para provar recuperação.

## Acesso e atendimento — atualização de 29/09/2026

- Cinco regras de etiquetas/saudação/apresentação reativadas somente para
  entrada não privada na caixa WAHA `5`; sem reprocessar histórico.
- Outros três usuários humanos removidos, preservando proprietário `1` e
  conta técnica `7`, como confirmado pelo usuário. Histórico preservado.
- Senha HTTP extra removida; login próprio, cadastro público bloqueado,
  APIs privadas 401, S3 sem assinatura 403 e limite de login 429 conferidos.
- Usuário escolheu somente as regras de atendimento do CRM nesta etapa;
  consultas Telegram e publicações n8n continuam desligadas.

## Trilha paralela — WAHA local conectado (29/09/2026)

- Canal confirmado pelo usuário: WAHA, com o mesmo número comercial e
  aparelho disponível. WAHA 2026.9.1/GOWS e Redis próprio estão no PC;
  sessão e mídia persistem no cofre Toshiba. Nova caixa API `5` criada,
  preservando a `CBN Api` e seu histórico. App Chatwoot provisionado.
- Filas Chatwoot isoladas no Redis DB `1`, mantendo DB `0`. Cinco regras
  reativadas na caixa WAHA após os testes; worker limitado a eventos, webhooks e análise de mídia,
  sem cron. n8n e canal Meta seguem inertes.
- QR pareado; número comercial conferido sem expor identificador. Um envio
  pelo CRM ficou `read`, e uma resposta entrou na mesma conversa, com um
  mapeamento por direção no WAHA. Contato existente reutilizado. Reinício
  WAHA retomou `WORKING` sem QR. Foto recebida, salva e devolvida com autorização
  adicional; envio ficou `read`. Fotos/miniaturas responderam HTTP 200 no PC
  e pela prévia autenticada; áudio respondeu HTTP 206 com Range. Rotas de
  mídia agora usam a origem atual e transporte S3 interno no servidor.
  Build offline do Vite concluído e imagem com ajuste dos helpers ativa em
  web/worker. Após reinício do WSL, serviços recuperados e sessão `WORKING`
  sem novo QR. O usuário confirmou manualmente envio, recebimento e reprodução
  de áudio funcionando; encerrada a pendência funcional do player. Texto,
  foto e áudio validados nos dois sentidos, com essa evidência manual para áudio.
  Procedimento em [`WAHA_LOCAL_RUNBOOK.md`](WAHA_LOCAL_RUNBOOK.md).

## Trilha paralela — túnel Railway ativo para prévia (29/09/2026)

- Serviço `cbn-tunnel-gateway` implantado no Railway e cliente frpc conectado
  a partir do PC. A prévia protegida por senha usa um domínio Railway novo;
  HTTP, WebSocket e URL S3 assinada responderam. O site tem prévia em `/site/`
  no mesmo gateway, com HTML idêntico ao local. Ver
  [`RAILWAY_TUNNEL_PLAN.md`](RAILWAY_TUNNEL_PLAN.md).
- Backup independente adiado pelo usuário. Nenhum dado real foi enviado ao
  GitHub. O custo do gateway deve ser acompanhado; o corte e os serviços de
  automação ainda não foram autorizados nesta etapa.

## Trilha paralela — clone retomado (29/09/2026)

- Toshiba reconectado; cofre LUKS2, PostgreSQL, Redis, S3, Chatwoot Web e site
  voltaram. Web e site responderam HTTP 200. Inicio seguro reproduzível por
  `infra/scripts/start-cbn-clone.ps1`.
- Bucket S3: 56/56 objetos reconferidos. Dos 64 blobs, dois S3 já faltavam na
  origem e quatro arquivos locais estão no volume Sidekiq separado; os volumes
  foram preservados sem mesclar. Web alcança 58/64 arquivos.
- n8n, Sidekiq e Telegram seguem inertes. Recuperação independente da chave,
  backup e validação funcional completa ainda impedem promover o clone.

## Trilha paralela — clone Railway local (29/09/2026)

- Banco físico, Redis, cinco volumes, segredos e 56 objetos S3 foram copiados
  para o cofre LUKS2 no Toshiba. Chatwoot real e site responderam localmente.
  Sidekiq, Telegram e n8n permanecem inertes, sem cutover.
- A conferência de 64 blobs apontou seis referências sem objeto local. Falta
  comparar essas seis com o bucket de origem.
- O HD externo desapareceu do Windows após reinicialização às 08:36, deixando
  o WSL e o clone indisponíveis. Primeiro reconectar e conferir integridade;
  depois validar dados/serviços e concluir backup recuperável.
- A origem Railway foi restaurada ao estado sem deploy ativo nos serviços usados
  para extração. O status detalhado está em
  [`CRM_INFRA_MIGRATION_STATUS.md`](CRM_INFRA_MIGRATION_STATUS.md).

## Trilha paralela — migração da infraestrutura CRM (28/09/2026)

- A meta foi confirmada como clone fiel do Railway. Inventário de nove serviços,
  cinco volumes e bucket S3 documentado. PgVector foi iniciado apenas para
  extração via SSH, e desligado após salvar dump cifrado com DPAPI no Toshiba.
- O clone real não foi restaurado. A tentativa de cofre LUKS no HD falhou;
  armazenamento criptografado confiável e backup recuperável seguem pendentes.
- Ubuntu 24.04.5 em WSL2 e Docker Engine/Compose no HD externo; `hello-world`
  confirmado. A composição sintética de Postgres/pgvector, Redis, Chatwoot CBN
  e um Sidekiq está saudável, aguardando onboarding manual.
- Nenhum DNS/webhook ou serviço de mensageria foi alterado. O único dado real
  transferido está cifrado em staging, sem aplicação produtiva.
- Seguem pendentes as decisões externas e gates BKL-016 registrados em
  [`CRM_INFRA_MIGRATION_STATUS.md`](CRM_INFRA_MIGRATION_STATUS.md).

## Trilha paralela — migração da infraestrutura CRM (25/09/2026)

- Etapa 0 de auditoria somente leitura concluída; nenhuma mudança no Railway nem
  transferência de dados foi feita.
- Etapa 1 pendente de espaço local e confirmação para habilitar WSL2/Docker
  Desktop no host Windows.
- Dumps, anexos e sessões reais permanecem proibidos até aprovação dos gates
  externos BKL-016.
- Acompanhar [`CRM_INFRA_MIGRATION_STATUS.md`](CRM_INFRA_MIGRATION_STATUS.md).
## Correção de agendamento pelo plugin — 20/10/2026

- Endereço do agendador alinhado à API pública `/site/cbn-api/...`, compartilhado por todas as operações. Rota atual respondeu 200 autenticado na conversa técnica; antiga retornou 404.
- Sem criação de agendamento, envio ou mudança na fila dos 20 leads. Guardas de autoria/UUID/estado incerto preservadas. [Runbook](CRM_PLUGIN_SCHEDULE_FIX_2026-10-20.md).

## Integração Codex ↔ CRM — 16/10/2026

- **Implementação e instalação local concluídas:** plugin privado `CBN CRM`,
  CLI/MCP em `tools/cbn-crm`, com consulta de conversas, texto/mídia, áudio offline,
  agendamentos, estado da conversa e regras nativas. 13 ferramentas; 15 testes
  sintéticos aprovados e validação autenticada somente leitura pelo MCP instalado.
- **Homologação produtiva pendente:** testar envio/entrega/mídia com destinatário
  explicitamente autorizado e avaliar convivência com humanos/Rebeca. Nenhum
  cliente contatado, automação criada/ativada ou serviço remoto modificado.
- Receber mensagens funciona por consulta paginada com cursor. Agente 24h/push e
  plugin para ChatGPT web/mobile não fazem parte do stdio local instalado.
- As tarefas de domínio/BKL-020 e gates históricos abaixo não foram concluídos
  nem liberados por esta entrega. Ver [CRM_CODEX_PLUGIN.md](CRM_CODEX_PLUGIN.md).

## Retomada oficial

- Fonte: `https://github.com/Sholdam/cbn`, branch `main`.
- **BKL-018 — Concluída e integrada:** autenticação, perfis humanos, estados de
  acesso, menor privilégio, RLS e funções administrativas controladas foram
  validados localmente.
- **BKL-020 — Próxima:** consolidar a trilha de auditoria canônica no PostgreSQL,
  reaproveitando as estruturas existentes e sem registrar PII.
- **BKL-016 geral — Em andamento por dependências externas:** KMS real,
  aprovação jurídica dos prazos, backup/produção remotos e revisão independente.
- BKL-007, BKL-011, BKL-012 e BKL-013 continuam vivas em paralelo conforme as
  evidências de produto forem obtidas.
- Dados reais e produção permanecem proibidos.

Consulte `docs/HANDOFF.md` para o contexto completo e
`docs/CONTINUAR_EM_OUTRO_COMPUTADOR.md` para retomar em outra máquina.

## BKL-016 — auditoria localizada da identidade (16/07/2026)

- Migration incremental `20260721_001` registra identidade técnica do operador
  de retenção, revisor de hold e executor de descarte em eventos específicos.
- Rollback incremental falha fechado após qualquer evento do modelo
  `BKL016_BACKEND_IDENTITY_V1` e funciona antes do rollback-base em banco limpo.
- Matriz de privilégios e grants não foram ampliados.
- Status: **Em andamento**, sem merge, deploy ou conexão remota.

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

### BKL-018 — Fundação local de autenticação e perfis

Status: **Em revisão para merge**.

- migration incremental e rollback fail-closed preparados;
- estados `ACTIVE`, `DISABLED` e `PENDING_REVIEW` validados;
- gestão humana somente por funções controladas;
- autoatribuição, autoelevação e papéis técnicos bloqueados;
- `anon`, usuário sem perfil ativo e `service_role` sem identidade humana;
- RLS-base e identidade backend sem regressão;
- nenhuma conexão remota, Appsmith, usuário real ou deploy.

Próxima após merge: **BKL-020 — trilha de auditoria canônica no PostgreSQL**.

- BKL-007 — validação regulatória e operacional;
- BKL-011 — catálogo de produtos contínuo;
- BKL-012 — fluxo FGTS pós-oferta;
- BKL-013 — assinatura, análise, aprovação, pagamento ou cancelamento.
