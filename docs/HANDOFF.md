# Handoff — CBN Crédito

## Queda simultânea CRM/site — 23/10/2026

- Retorno espontâneo informado pelo proprietário e confirmado: ambos HTTP 200, WhatsApp WORKING, serviços ativos. Investigação apenas de leitura; nenhuma reinicialização ou alteração aplicada.
- VPS iniciou novo boot às 15h47 de Brasília. Sem desligamento normal, OOM ou kernel panic nos registros consultados; causa exata não confirmada. Recursos atuais com folga. [Evidências e limites](CRM_SITE_INCIDENT_2026-10-23.md).

## Menu inicial de crédito — 22/10/2026

- Retorno do proprietário: atalho não iniciava menu na chegada anterior à ativação. Corrigido roteamento do serviço para coleta ou menu. Primeiro clique envia duas mensagens, retomada repete só opções; guardas de autenticação/UUID/trava/cooldown preservadas. Imagem web atual `cbn-generic-menu-resume-20261022`. Conversa indicada ativada via rota autenticada, duas mensagens `delivered`, aguardando opção. [Publicação e limites](CRM_GENERIC_CREDIT_MENU_2026-10-22.md).
- Ativas regras nativas 12/13/14: saudação separada, menu 1–6 (INSS, SIAPE, servidor estadual/municipal, CLT, carro em garantia, outros), confirmação e uma orientação para escolha inválida. Escolha etiqueta contato/conversa e encaminha a Guilherme, preservando agente existente.
- Complemento isolado no worker, estado/trava por conversa, sem repetição histórica ou interferência nas coletas de anúncios. Intervenção humana interrompe o menu. Textos editáveis em Automações; sem IA/API adicional.
- Ativação automática 12:50:58 de Brasília. Sintaxe/carregamento/configuração/regras conferidos, CRM 200 e WAHA WORKING. Envio real posterior via retomada, conforme acima; seleção pelo cliente ainda não observada. [Detalhes e rollback](CRM_GENERIC_CREDIT_MENU_2026-10-22.md).

## Agendamento com anexos — 20/10/2026

- Publicado suporte a arquivo sem texto ou com legenda no Agendar: seleção, lista e remoção de anexos, edição e persistência Active Storage sem migration. Dispatcher nativo envia os arquivos no horário.
- API/worker de operações e web usam imagens `cbn-scheduled-media-operations`/`cbn-scheduled-media-ui` de 20/10. WAHA preservado. Builds/sintaxe, CRM 200, associação `files`, API de consulta e heartbeat conferidos; nenhuma agenda ou mensagem de teste criada.
- Plugin instalado aceita `upload_ids`, texto opcional e remoção de anexos na edição. Processos MCP abertos precisam reconectar. Guardas de autorização/UUID/estado incerto preservadas. [Detalhes e rollback](CRM_SCHEDULE_ATTACHMENTS_2026-10-20.md).

## Fila Secretária — 20/10/2026

- Por pedido do proprietário, 27 conversas pendentes encerradas via plugin CBN CRM, com ações idempotentes; consulta final retornou zero pendentes. Todas as caixas acessíveis incluídas, inclusive legada.
- Renomeação visual do estado `pending` para Secretária publicada somente no web, imagem `cbn/chatwoot:4.16.2-cbn-secretaria-label-20261020`, em filtros, ações e relatório de conversas. Não ativa agente ou webhook. [Detalhes](CRM_SECRETARIA_STATUS_2026-10-20.md).

## Cópia da data e eventos da Secretaria — 20/10/2026

- Correção em `infra/cbn-contact-date/`: nascimento exibido/copiado como `DD/MM/AAAA`, sem mudar armazenamento ou converter fuso. Publicada imagem `cbn/chatwoot:4.16.2-cbn-date-copy-20261020` somente no web; build concluído, sem teste automatizado. Build/publicação e rollback no [runbook](CRM_CONTACT_DATE_COPY_2026-10-20.md).
- Lida a conversa `Secretaria`: pedido de atendimento reativo aos 20 leads CLT, substituindo espera por consulta de 20 minutos. Plugin existente confirmado como stdio/ferramentas; não recebe eventos.
- [Desenho e dependência do destino do agente](CRM_SECRETARIA_EVENTS_2026-10-20.md). MCP Events documentado para Work/Cloud/dots; o chat Codex local atual não tem recepção comprovada. Integração ainda não ativada; nenhum envio à carteira nesta tarefa.

## Atalho Retomar bot — 20/10/2026

- Botão no cabeçalho das conversas CBN/WAHA, junto a Resolver, para retomada explícita de coleta Colatina/CLT. Aproveita dados cadastrados e respostas válidas pendentes; pergunta só a etapa necessária. Revisões de cadastro, bloqueio de contato, conversa fechada e regra desativada impedem envio.
- Endpoint autenticado nativo e política da conversa, trava/UUID/cooldown e registro mínimo de ator/horário/etapa. Exceção à intervenção humana limitada à chamada manual, sem relaxar o fluxo automático normal. Remetente continua automático.
- Imagem `cbn/chatwoot:4.16.2-cbn-bot-resume-20261020` implantada; web/worker recarregados, WAHA/configuração preservados. Build, sintaxe, rota e botão visível conferidos; sem suíte automatizada ou envio de teste pelo botão.
- [Detalhes, limites e rollback](CRM_BOT_RESUME_2026-10-20.md).

## Resposta de cadastro dentro do anúncio — 20/10/2026

- Cliente respondeu CPF válido dentro do envelope WAHA “ANÚNCIO DO FACEBOOK / MENSAGEM DO CLIENTE”. Extrator ancorado no documento inteiro não reconhecia a resposta; fluxo permanecia `aguardando_cpf`.
- `CbnLeadCapture.customer_text` agora isola somente a seção explícita do cliente quando o texto começa pelo cabeçalho conhecido. CPF, matrícula e vínculo usam esse corpo; metadados do anúncio não são tratados como dados cadastrais. Mensagens simples conservadas.
- Initializer atualizado com backup e recriação somente do worker. Configuração, regras, frontend e WhatsApp preservados. Caso indicado recuperado individualmente, com CPF salvo e pergunta nativa de matrícula confirmada como `delivered`, aguardando matrícula.
- [Detalhes e rollback](CRM_COLATINA_CADASTRO_ETIQUETAS_2026-10-19.md#respostas-dentro-do-envelope-do-anúncio).

## Formatação WhatsApp — 20/10/2026

- Retorno “não vi diferença”: barra padrão estava oculta até selecionar texto. Camada `Dockerfile.toolbar`/`toolbar.css` agora mantém controles visíveis acima do campo. Nome CSS com hash novo evita cache; web foi recriado, WAHA/worker preservados. Prévia aplicada na aba aberta sem recarregar rascunho, barra 34 px/botões 28 px conferidos por DOM e captura. Compose web usa `cbn/chatwoot:4.16.2-cbn-whatsapp-toolbar-20261020`.

- Investigação pelo plugin CBN CRM encontrou mistura de sintaxes e marcadores com espaços/quebras. Editor da caixa WAHA 5 usa capacidades WhatsApp, com regras de digitação/colagem para negrito, itálico e tachado; rascunhos permanecem CommonMark.
- Conversor de saída WAHA passa a usar árvore `markdown-it`, protegendo código/links e tratando listas, citação, linhas e estilos combinados. Imagens web e WAHA atualizadas no compose, preservando worker e automações.
- Build concluído, CRM/JS 200 e sessão `WORKING`. Sem envio de teste a clientes ou suíte automatizada; confirmar aparência no próximo envio orgânico. Recarregar navegador para novo compositor.
- [Fontes, implantação e rollback](CRM_WHATSAPP_FORMATTING_2026-10-20.md).

## Correção do envio automático Colatina — 19/10/2026

- Cinco novos leads reconhecidos e etiquetados não receberam saudação. A consulta SQL do complemento tratava `messages.content_attributes` como objeto, mas Chatwoot serializa esse campo JSON como string. A procura não encontrava a mensagem recém-criada e levantava erro dentro da transação, desfazendo o envio.
- Corrigido uso do retorno de `Messages::MessageBuilder` nas perguntas iniciais, matrícula e vínculo. Busca de perguntas CLT anteriores aceita os dois formatos e ordena pela mensagem mais recente.
- Worker atualizado com backup, sem alterar anúncios, regras, configuração, web, WAHA ou banco. Fluxo do chat ADS preservado: CPF → matrícula → vínculo numerado → humano.
- Conferência do fluxo nativo em transação revertida: quatro mensagens/etapas corretas, nenhuma persistida ou enviada nessa conferência. Recuperação pontual das cinco saudações omitidas após confirmar ausência de resposta e fluxo anterior: uma por conversa, todas com status `delivered`, aguardando CPF. Sem replay geral de eventos.
- [Procedimento e limites](CRM_COLATINA_CADASTRO_ETIQUETAS_2026-10-19.md#correção-de-envio-e-recuperação-dos-cinco-leads).

## CRM Colatina — vínculo numerado — 19/10/2026

- Etapa 11 ativa após matrícula: 1 Comissionado / 2 Efetivo / 3 Temporário. Registra autodeclaração e segue para atendente; sem decisão automática ou pedido de contracheque.
- Gatilho 8 reconhece anúncio original e V2. Código/configuração implantados com backup. 10 testes sintéticos/30 asserções aprovados, sem disparo para clientes.
- [Detalhes e rollback](CRM_COLATINA_CADASTRO_ETIQUETAS_2026-10-19.md).

## Recuperação após desconexão do HD — 02/10/2026

- Usuário autorizou reparar o original sem backup completo. `e2fsck -f -p`
  recuperou os journals do disco Ubuntu e do cofre LUKS; ambos retornaram 1
  (corrigidos), e a conferência posterior retornou `clean`.
- Ubuntu e cofre voltaram graváveis; gravação pequena com `fsync` e `sync`
  concluíram. Dez containers ativos, CRM/site local e público HTTP 200,
  API privada sem login 401 e sessão WAHA `WORKING`. Sem novo envio de mensagem.
- Keepalive e recuperação por minuto reativados. Montagem do cofre agora é
  confirmada também nos namespaces do systemd/Docker; parada segura desmonta
  essas vistas antes de fechar LUKS. Tolerância inicial do Rails passou a 5 min.
- Distro auxiliar `CBN-Recovery` instalada no Toshiba e parada após o reparo.
  Cópia parcial temporária descartada; backup independente continua pendente.
  Integridade completa de todo o histórico não foi auditada neste reparo.
- Links atuais: <https://crmcbn.up.railway.app/> e
  <https://crmcbn.up.railway.app/site/>. O endereço longo antigo foi renomeado.
  Evidências e limites em [`CRM_DISK_RECOVERY_2026-10-02.md`](CRM_DISK_RECOVERY_2026-10-02.md).

## Usuário adicional autorizado — 30/09/2026

- Criado agente humano `8`, confirmado, com acesso somente à caixa WAHA `5`,
  após pedido explícito do proprietário. A senha escolhida foi ajustada para
  atender à exigência de maiúscula, com confirmação do usuário. Correspondência
  da senha verificada no servidor; não registrar e-mail nem senha no Git.
- O CRM agora tem proprietário `1`, conta técnica WAHA `7` e agente `8`.
  Não excluir o novo agente ao repetir a limpeza antiga; o script de limpeza
  recusa usuários humanos fora da lista anteriormente autorizada.

## Disponibilidade e endereço curto — 30/09/2026

- Usuário mostrou página 404 do frp. Toshiba estava saudável, mas
  `Ubuntu-CBN` estava `Stopped` e não havia processo keepalive no Windows.
  Serviços e túnel foram retomados. A causa do encerramento anterior não
  foi determinada; não atribuir a falha ao HD ou à conversa `187`.
- Usuário exigiu continuidade dos serviços e pediu endereço começando em
  `crmcbn`. O domínio Railway do gateway CBN foi renomeado para
  <https://crmcbn.up.railway.app/>; não usar o endereço longo anterior.
  `FRP_CRM_DOMAIN`, `FRONTEND_URL` e endpoint S3 foram atualizados no cofre.
  Página/API/login e foto proxy/S3 foram reconferidos; WAHA `WORKING`.
- Windows: `CBN-WSL-Keepalive` executa WSL pelo Agendador de Tarefas, fora
  do ciclo de vida do terminal/chat. `CBN-Service-Recovery` verifica a cada
  minuto e ao entrar no Windows, com a identidade interativa do proprietário,
  sem senha armazenada nem alteração de ExecutionPolicy. Houve execução com
  resultado 0 e evento `recovered`; nova checagem devolveu `healthy: true`.
- Recuperação exige Toshiba correto/saudável e cofre montado em
  `/dev/mapper/cbn_production`. Confere dez containers, HTTP local/público,
  API privada 401 e sessão WAHA. Não ativa n8n, Telegram ou filas herdadas.
  Reinício WAHA em falha é limitado a uma tentativa por 15 minutos; não
  reinicia sessão em leitura de QR ou inicialização. Sessão expirada pode
  precisar do celular. Não prometer disponibilidade sem PC, energia ou rede.
- `maintenance.flag` em `%USERPROFILE%\.cbn` preserva parada manual:
  `stop-cbn-clone.ps1` pausa recuperação, fecha cofre e encerra WSL antes de
  retirar HD. Início manual limpa a flag; recuperação automática não limpa.
  Script de parada revisado e validado por sintaxe, sem parar os serviços
  nesta etapa. O início após logon foi configurado, sem teste de reboot.
  Eventos técnicos ficam em `.cbn/service-recovery.log`, sem dados pessoais.

## Acesso e regras de atendimento — autorização de 29/09/2026

- Usuário pediu reativar as regras do CRM, remover os outros usuários e
  retirar Basic Auth se a autenticação própria estivesse protegida. Depois
  confirmou manter a conta técnica WAHA e limitar a retomada às regras do
  CRM; adaptação de consultas Telegram e publicações n8n ficou para depois.
- Regras `1,3,4,5,6` ativas na caixa WAHA `5`, somente para mensagens de
  entrada não privadas. As condições de conteúdo foram mantidas; as duas
  alternativas de saudação agora usam uma lista no mesmo filtro, evitando
  que um `OR` ignore o filtro de caixa/tipo. Nada foi reenviado pelo agente.
- Usuários humanos `2,3,4` removidos; ficou o proprietário `1` e a conta
  técnica `7`. Um vínculo órfão de usuário já inexistente foi limpo. Contagens
  de contatos, conversas e mensagens foram preservadas. Limpeza executou só
  os callbacks dessa operação, sem consumir a fila legada `low`.
- Basic Auth removido de frpc. HTTPS/login/site retornaram 200 sem senha
  extra; APIs de inboxes/perfil retornaram 401 sem autenticação; listagem S3
  sem assinatura retornou 403. Cadastro público permanece bloqueado. Login
  sintético foi recusado e a 11ª tentativa recebeu 429 por limite de e-mail.
  São verificações funcionais, não uma auditoria completa de segurança.
- WAHA permaneceu `WORKING`; acesso API com a conta técnica retornou 200.
  O script de início exige agora página pública 200 e API privada 401.
  Não criar outro usuário sem novo pedido; membros futuros precisam de
  credenciais individuais do CRM, pois compartilhar o endereço não dá acesso.

## Decisão de canal — WAHA local (29/09/2026)

- **Pareamento e texto concluídos:** usuário leu o QR; sessão `default`
  ficou `WORKING`, com identidade correspondente ao número comercial
  esperado. Um único envio pelo CRM foi criado na conversa `185`, mensagem
  `2208`, e chegou ao estado `read`. A resposta entrou como `2209` na mesma
  conversa, reutilizando o contato existente. O banco WAHA confirmou um
  mapeamento de saída e um de entrada, sem duplicação. Reinício do container
  WAHA retornou a `WORKING` sem novo QR.
- **Foto concluída:** entrada `2217`, arquivo JPEG íntegro no S3 local.
  Usuário autorizou devolver a mesma foto como envio adicional; saída `2222`
  ficou `read`, com um mapeamento WAHA. O checkpoint privado impede repetir
  os envios iniciais. Fotos e miniaturas responderam HTTP 200 localmente e
  pelo gateway autenticado; áudio de teste respondeu HTTP 206 com Range.
- A interface local revelou falha de mídia: URLs absolutas apontavam para
  a prévia pública e recebiam 401 ao abrir pelo localhost. Corrigido por
  rotas proxy relativas ao endereço atual, nas duas aplicações Chatwoot.
  O transporte S3 do servidor usa Garage interno; assinaturas de upload
  direto continuam usando o gateway público. A ponte WAHA recebe URL
  absoluta interna de mídia. Nenhuma nova mensagem foi enviada por essa
  correção; dados e filas preservados.
- Web e worker usam a imagem local `cbn/chatwoot:4.16.2-cbn-waha-media`.
  O build offline do Vite concluiu; os helpers de áudio e imagem resolvem
  caminhos relativos com a origem da página. Fontes e novo manifest foram
  conferidos no container ativo. A política do navegador impediu a última
  conferência automatizada do player. Em seguida, o usuário testou manualmente
  e confirmou envio, recebimento e reprodução de áudio funcionando. A pendência
  funcional de áudio está encerrada por confirmação do usuário.
- Após um reinício inesperado do WSL, o início público reabriu o cofre e
  recuperou CRM, site, túnel e WAHA. A sessão voltou a `WORKING`, com identidade,
  sem novo QR; texto `2208` e foto `2222` continuaram `read`. A causa desse
  reinício não foi determinada. O helper temporário de QR foi encerrado.

- WAHA **2026.9.1 / GOWS / CORE** instalado e iniciado no PC, com imagem
  fixada por digest, Redis próprio e volumes persistentes no cofre Toshiba.
  A nova caixa **CBN WhatsApp (WAHA)** é `Channel::Api`, inbox `5`; o app
  Chatwoot interno foi criado. O teste de texto está confirmado acima;
  a sessão autenticada persiste no cofre.
- Chatwoot local passou a usar Redis DB `1`; DB `0` e os trabalhos herdados
  foram preservados. Regras automáticas `1,3,4,5,6` foram pausadas durante a
  migração e depois reativadas na caixa WAHA conforme a autorização acima.
  O worker novo processa somente `critical`, `medium` e
  `active_storage_analysis`, sem cron herdado. O canal Meta, n8n e worker
  legado continuam inertes. A conta técnica WAHA permanece agente; a
  permissão administrativa temporária usada para criar os atributos foi
  retirada após configurar o app.
- Webhook WAHA usa apenas a rede Docker interna. A exceção de acesso privado
  é limitada ao destino exato provisionado, sem redirecionamentos; o filtro
  SSRF normal segue para os demais destinos. API/admin WAHA em loopback
  `3003`; página temporária de QR em loopback `3004`, sem chave no navegador.
  Ver [`WAHA_LOCAL_RUNBOOK.md`](WAHA_LOCAL_RUNBOOK.md).

- O usuário confirmou que o WhatsApp operacional será pelo **WAHA**, não pela
  API oficial da Meta. A tentativa `hello_world` abaixo registra apenas a
  falha do canal legado; não repetir esse envio nem usar a verificação da
  conta Meta como próximo passo da migração.
- O WAHA deve rodar neste PC, com sessão persistida no Toshiba e saída para o
  WhatsApp pela conexão local brasileira. O Railway permanece como entrada
  pública do CRM/site, sem intermediar a saída do WAHA. WAHA foi acrescentado
  ao clone local; não existe serviço WAHA no projeto Railway.
- A integração atual `CBN Api` é `Channel::Whatsapp` da Meta. Preparar uma
  caixa `Channel::Api` separada para o app Chatwoot integrado do WAHA,
  preservando o histórico da caixa antiga. Antes de ativar envios, conferir
  vínculo de contatos/conversas, sessão via QR no aparelho comercial, filas,
  anexos e ida/volta com número de teste. O app integrado do WAHA usa Redis e
  não exige n8n apenas para a ponte com o Chatwoot.

## Atualização — teste funcional e custo medido (29/09/2026)

- A interface local do Chatwoot abriu a conversa de teste e salvou uma nota
  privada. A nota permaneceu após recarregar a página e foi confirmada no
  PostgreSQL como mensagem `2035`.
- Um único modelo neutro `hello_world` foi criado como mensagem `2036`. O
  trabalho de envio correspondente foi retirado da fila antes da execução
  isolada, sem iniciar Sidekiq. A primeira tentativa foi recusada pela Meta:
  o identificador de telefone salvo no clone não existia mais. A chave da API
  e a conta WhatsApp Business responderam normalmente; a lista da Meta tinha
  um único telefone correspondente ao número configurado no canal. O
  `phone_number_id` do **clone local** foi atualizado e validado contra essa
  lista.
- A repetição da mesma mensagem foi recusada com `(#133010) Account not
  registered`. A Meta retornou `code_verification_status=NOT_VERIFIED`,
  `platform_type=NOT_APPLICABLE` e `name_status=PENDING_REVIEW` para o telefone.
  A mensagem `2036` está `failed`, sem ID externo e sem trabalho de envio
  pendente. Os quatro webhooks de bot gerados pelos dois registros de teste
  foram retirados da fila; outros trabalhos foram preservados. Não há
  evidência de entrega. Não registrar o número ou mudar
  webhook/canal sem tratar o estado da conta na Meta; automações seguem inertes.
- `railway usage projects --project CBN --period current --json` indicou
  US$ 0,1951 para o projeto CBN e US$ 0,000248 para `cbn-tunnel-gateway` no
  ciclo de 21/09 a 21/10, na leitura de 29/09 às 15h BRT. A amostra do túnel
  é curta e não constitui projeção mensal.

## Atualização — túnel Railway ativo para prévia (29/09/2026)

- O usuário autorizou e foi implantado `cbn-tunnel-gateway`. O cliente frpc
  iniciou conexão de saída do PC. A prévia pública protegida por senha está em
  <https://cbn-tunnel-gateway-production.up.railway.app/>. HTTP 200 com
  credencial, HTTP 401 sem credencial, URL S3 assinada e WebSocket foram
  validados. Segredos permanecem no cofre LUKS e nas variáveis do gateway;
  detalhes em [`RAILWAY_TUNNEL_PLAN.md`](RAILWAY_TUNNEL_PLAN.md).
- O site CBN tem prévia no mesmo domínio, em `/site/`; seu HTML foi comparado
  com o local e é idêntico. O domínio público original do site não mudou.
- Início após reinício: [`start-cbn-public.ps1`](../infra/scripts/start-cbn-public.ps1).
  Antes de retirar o Toshiba, [`stop-cbn-clone.ps1`](../infra/scripts/stop-cbn-clone.ps1)
  para o túnel e fecha o cofre. O ciclo de parada e retorno público foi executado
  com sucesso. Domínios originais e automações não mudaram.
- A cópia de segurança independente foi adiada por decisão do usuário. Não
  armazenar backups reais nem segredos no repositório GitHub CBN.

## Atualização — clone retomado após reconexão (29/09/2026)

- Toshiba reconhecido novamente em `D:`; WSL e cofre LUKS2 reabertos.
  PostgreSQL, Redis, Garage, Chatwoot Web e site CBN operam localmente. Web
  respondeu HTTP 200 e o dashboard CBN abriu em `http://127.0.0.1:3000/`;
  site em `:3002/`. Pilha sintética anterior parada, com volumes preservados.
- Os 56 objetos S3 foram relidos com SHA-256 idêntico. Dos 64 blobs no banco,
  dois S3 já faltavam na origem, quatro arquivos locais estão no volume Sidekiq
  separado, e 58 são acessíveis pelo Web. Volumes originais preservados.
- n8n confirmou 6 workflows, 10 credenciais e 5.091 execuções em modo inerte.
  Sidekiq e Telegram não foram ativados.
- Scripts de início/parada segura: [`start-cbn-clone.ps1`](../infra/scripts/start-cbn-clone.ps1)
  e [`stop-cbn-clone.ps1`](../infra/scripts/stop-cbn-clone.ps1). O ciclo real
  parar/desmontar/remontar/iniciar foi concluído com Web e site HTTP 200. Recuperação
  independente da chave, backup externo e validação funcional ainda pendentes.

## Atualização — clone Railway local (29/09/2026)

- A cópia física PgVector, Redis, os volumes Chatwoot/n8n/Sidekiq e os 56 objetos
  S3 foram obtidos e restaurados em cofre LUKS2 no Toshiba. A interface real do
  Chatwoot respondeu na porta 3001 e o site CBN na porta 3002. Sidekiq,
  gateway Telegram e workflows n8n continuam inertes.
- Seis de 64 referências ActiveStorage não foram encontradas no S3 local;
  comparar com a origem para separar lacuna de dados preexistente de erro de
  migração. O comando de comparação foi interrompido na reinicialização.
- Após a reinicialização do Windows às 08:36, o Toshiba deixou de constar em
  `Get-Disk`/`Get-Volume`; `D:` e o WSL `Ubuntu-CBN` ficaram indisponíveis.
  Reconectar a unidade e verificar integridade antes de reabrir o cofre e
  reiniciar serviços. O estado anterior de 28/09 abaixo foi superado.
- A origem Railway voltou a não ter deploy ativo nos serviços extraídos; Git e
  comandos originais foram restaurados. Nenhum DNS/webhook foi alterado.
  Detalhes: [`CRM_INFRA_MIGRATION_STATUS.md`](CRM_INFRA_MIGRATION_STATUS.md).

## Atualização — preparação de migração do CRM (28/09/2026)

- A meta foi confirmada como clone fiel do estado Railway. O inventário atual
  identificou nove serviços sem deploy ativo antes da extração, cinco volumes
  preservados e bucket S3 com 56 objetos. Consulte
  [`RAILWAY_PARITY_INVENTORY.md`](RAILWAY_PARITY_INVENTORY.md).
- Por autorização posterior do usuário, PgVector foi iniciado para uma cópia
  lógica via SSH. O dump foi cifrado com DPAPI no HD externo, verificado e o
  serviço Railway voltou ao estado sem deploy ativo. Não houve cutover.
- A tentativa de cofre LUKS em arquivo NTFS/WSL falhou; a imagem incompleta de
  50 GB permanece em `D:\CBN\vault`, sem dados reais. A restauração aguarda
  proteção de disco confiável. Após reiniciar a distro, o stack sintético
  voltou a ficar saudável.
- Ubuntu 24.04.5 foi verificado pelo SHA-256 oficial e importado como
  `Ubuntu-CBN` em `D:\CBN\wsl\Ubuntu-CBN`, no HD Toshiba externo.
- Docker Engine 29.8.1 e Compose 5.5.1 foram instalados dentro do WSL; o serviço
  está ativo e o contêiner oficial `hello-world` executou com sucesso.
- A composição sintética de Postgres/pgvector, Redis, Chatwoot CBN e um Sidekiq
  está saudável; `http://127.0.0.1:3000/` redireciona ao onboarding inicial.
  Nenhuma conta foi criada. Os gates BKL-016 para aplicação produtiva seguem.
- Detalhes e próximos bloqueios: [`CRM_INFRA_MIGRATION_STATUS.md`](CRM_INFRA_MIGRATION_STATUS.md).

## Atualização — preparação de migração do CRM (25/09/2026)

- A Etapa 0 de leitura da infraestrutura Railway e do host local foi concluída;
  nenhuma configuração de produção ou dado foi alterado/exportado.
- A Etapa 1 aguarda espaço local suficiente e confirmação antes de instalar WSL2
  e Docker Desktop, pois isso modifica componentes do Windows e pode exigir
  privilégios administrativos e reinicialização.
- A migração de dados reais continua bloqueada pelos gates externos da BKL-016.
- Plano e estado da trilha: [`CRM_INFRA_MIGRATION_STATUS.md`](CRM_INFRA_MIGRATION_STATUS.md).
## Agendamento do plugin — 20/10/2026

- Falha 404 identificada como rota antiga `/cbn/v1/...`. Frontend/proxy/API atuais usam `/site/cbn-api/...`.
- Consulta, criação, alteração e cancelamento usam `Crm.schedulesRoute`, com autenticação/UUID e guardas existentes preservados. Consulta autenticada à conversa técnica confirmou 200 na rota atual contra 404 na antiga.
- Correção local do plugin; nenhum agendamento de teste, envio, alteração da fila da campanha ou deploy na VPS. Não foram executados testes automatizados. [Detalhes e instalação](CRM_PLUGIN_SCHEDULE_FIX_2026-10-20.md).

## Plugin CBN CRM — 16/10/2026

- Criado `tools/cbn-crm`, CLI/MCP stdio com SDK MCP oficial v2, 13 ferramentas
  tipadas para atendimento via HTTPS, mídia, transcrição offline, agendamento e
  automação nativa. Branch isolada `codex/cbn-crm-plugin`, baseada em origin/main;
  alterações da frente Rebeca no checkout anterior permanecem preservadas.
- Plugin `cbn-crm@cbn-local` v0.1.0 instalado localmente no Codex. Conexão
  autenticada a `crm.cbncredito.tech`, conta 1, com a credencial já existente do
  proprietário. Token/configuração/cache ficam na pasta privada LOCALAPPDATA,
  fora do repositório/OneDrive. Nenhum usuário/token novo criado no servidor.
- Escritas disponíveis com preparação persistida, referência à autorização
  humana e validação de contexto. Repetição da mesma ação não reenvia; resultado
  incerto requer conferência. Não é autorização permanente para envios/campanhas.
- 15 testes sintéticos aprovados, handshake/call MCP real aprovado, identidade,
  quatro caixas e API de regras conferidas sem mutação. Rotas privadas de
  mensagens/agendamento responderam 404 autenticado para conversa inexistente.
  Áudio sintético transcrito via ferramenta com Whisper local já disponível.
- Não houve envio a clientes, ativação/alteração de regras, deploy ou mudança
  na VPS. Homologação de envio/entrega/mídia real continua pendente. StdIO atende
  Codex local; ChatGPT web/mobile requer uma implantação MCP HTTPS separada.
- Após instalação, abrir nova conversa/recarregar o Codex para carregar ferramentas.
  Detalhes e limites: [CRM_CODEX_PLUGIN.md](CRM_CODEX_PLUGIN.md).

## CHECKPOINT OFICIAL PARA RETOMADA — 17/07/2026

Este repositório, na branch `main`, é a **fonte oficial** do projeto:

```text
https://github.com/Sholdam/cbn
```

Para continuar em outro computador, siga
[`CONTINUAR_EM_OUTRO_COMPUTADOR.md`](CONTINUAR_EM_OUTRO_COMPUTADOR.md) e leia o
[`AGENTS.md`](../AGENTS.md). Não use ZIPs ou cópias locais antigas como fonte.

### Estado consolidado

- **BKL-018 concluída e integrada:** fundação local de autenticação, perfis e
  permissões humanas para `admin`, `operations`, `support` e `auditor`.
- **BKL-016 — fundação concluída:** RLS, Storage privado, envelope local,
  backup/restauração sintética, retenção/legal hold e identidades técnicas de
  menor privilégio foram validados e integrados.
- **BKL-016 geral permanece Em andamento:** KMS real está bloqueado por
  faturamento; aprovação jurídica dos prazos, estratégia remota de
  backup/produção e revisão independente continuam pendentes.
- **Telegram MTProto validado:** sessão persistente, comunicação com o bot e
  proteção de idempotência comprovadas.
- **Dados reais e produção continuam proibidos** até a aprovação explícita dos
  gates restantes.

### Próxima tarefa principal

**BKL-020 — trilha de auditoria canônica no PostgreSQL.**

Antes de implementá-la, revisar a auditoria já criada nas BKL-016 e BKL-018,
evitar duplicação de estruturas e definir uma única fonte append-only sem PII.

### Tarefas paralelas ainda vivas

- BKL-007 e BKL-011: regras e catálogo são completados durante atendimentos.
- BKL-012: falta comprovar os campos pós-oferta do FGTS com cliente autorizado.
- BKL-013: acompanhamento de proposta, assinatura, análise e pagamento continua
  sendo completado por evidências reais autorizadas.

### Regras para a retomada

1. Confirmar `main`, árvore limpa e sincronização com `origin/main`.
2. Criar branch `codex/<tarefa>` antes de alterar arquivos.
3. Informar esforço como **Médio, Alto, Extralto ou Ultra**, usando o menor nível
   compatível com o risco.
4. Usar somente dados sintéticos em banco, Storage e testes.
5. Não versionar `.env`, sessões, tokens, JWTs, chaves, URLs assinadas ou PII.
6. Não alterar migrations já aplicadas; criar migrations incrementais.
7. Não fazer merge, deploy ou conexão remota sem autorização expressa.
8. Executar primeiro testes afetados e a suíte completa apenas uma vez ao final,
   quando suficiente.

### Arquivos de orientação

- `README.md` — visão rápida e ponto de entrada.
- `AGENTS.md` — regras automáticas para o próximo Codex.
- `docs/BACKLOG_CHECKPOINT.md` — situação das tarefas.
- `docs/ARQUITETURA_TECNICA.md` — decisões arquiteturais.
- `docs/BKL-018_AUTH_PROFILES_RUNBOOK.md` — última fundação implementada.
- `docs/RELATORIO_BKL-018_AUTH_PROFILES_LOCAL.md` — evidências da última fase.

Os registros abaixo preservam o histórico detalhado das etapas anteriores.

## Correção localizada da auditoria de identidade — 16/07/2026

- Migration incremental `20260721_001` completa a auditoria dos wrappers de
  retenção, revisão de hold e conclusão de descarte no modelo
  `BKL016_BACKEND_IDENTITY_V1`.
- Papéis, grants e matriz de permissões permanecem inalterados; a função interna
  de auditoria não foi concedida aos papéis operacionais.
- O teste focado de identidade foi aprovado antes da regressão completa.
- Nenhuma conexão remota, deploy ou merge faz parte desta correção.

## Identidade mínima do backend — 16/07/2026

- Branch `codex/bkl-016-backend-identity` preparada, sem merge ou aplicação remota.
- Quatro papéis `NOLOGIN` separam Gateway, operador de retenção, revisor de hold
  e executor de descarte; nenhum possui acesso direto a tabelas privadas/auditoria.
- Operações sensíveis usam somente wrappers `SECURITY DEFINER` tipados, com
  `search_path = ''` e grants mínimos.
- O operador que prepara o descarte não consegue concluí-lo; remoção de hold
  permanece dependente de revisor técnico distinto.
- 44 testes Node, cinco suítes SQL, rollback fail-closed, rollback limpo e
  reaplicação passaram em Supabase local descartável.
- Nenhuma credencial real foi criada. `service_role` não é a identidade final.
- BKL-016 continua **Em andamento**: login técnico futuro, KMS real, jurídico,
  backup remoto, aplicação autorizada e revisão independente seguem pendentes.

## Revisão corretiva da retenção — 16/07/2026

- Corrigidos os bloqueadores de auditoria, inventário de anonimização e escopo do
  legal hold em migration incremental `20260719_001`.
- Negações de política agora persistem `RETENTION_EVALUATED allowed=false` e o
  evento `ANONYMIZATION_DENIED` ou `DELETION_DENIED` sem continuar o descarte.
- Hold de cliente protege payload/arquivo relacionado e é revalidado antes do
  Storage e da conclusão do banco.
- Reidentificação pública ou privada de cliente anonimizado é bloqueada por
  triggers; dependências que exigem política própria recusam anonimização.
- Solicitante e aprovador da remoção do hold precisam ser distintos.
- Quatro suítes SQL, 36 testes Node, runtime Storage, rollback e reaplicação
  passaram localmente; nenhum ambiente remoto foi acessado.
- BKL-016 continua **Em andamento** e a branch não foi mesclada.

## Atualização 16/07/2026 — retenção e legal hold local

- Branch `codex/bkl-016-retention-legal-hold` preparada sem merge.
- Migration incremental `20260718` adiciona políticas configuráveis, controles
  privados, legal hold, anonimização idempotente e descarte em duas fases.
- Runtime local comprovou remoção do objeto Storage e só concluiu o banco após a
  verificação de ausência; falha simulada permaneceu pendente.
- Backup posterior à anonimização foi restaurado sem reintroduzir identificadores.
- Rollback recusou estado novo e funcionou em base descartável limpa.
- Nenhum prazo jurídico foi definido. Dados reais e produção continuam proibidos.
- Google Cloud KMS real segue bloqueado temporariamente por faturamento.
- BKL-016 permanece **Em andamento**, aguardando política jurídica, KMS real,
  identidade backend mínima, aplicação remota autorizada e revisão independente.

**Atualizado em:** 16/07/2026, após backup, restauração e recuperação sintética local da BKL-016
**Projeto:** CBN — operação autônoma de varredura e venda de crédito  
**Escopo inicial:** FGTS + Crédito do Trabalhador (CLT)

## Objetivo

Construir uma operação autônoma com captação pela Meta, atendimento no WhatsApp, consentimento, consulta dos dois produtos, consolidação das ofertas, digitação das propostas aceitas, acompanhamento e intervenção humana somente em exceções.

## Decisões estruturais vigentes

1. A varredura padrão consulta **FGTS e CLT** após consentimento e dados suficientes.
2. As ofertas devem vir somente dos sistemas reais; o agente não inventa banco, valor, prazo ou taxa.
3. O atendimento não fala diretamente com Telegram ou Prospecta. O n8n utilizará um **Gateway interno**.
4. Cada sessão Telegram processará somente uma operação ativa por vez.
5. Cada operação terá `operation_id` persistente para impedir duplicidade em timeout ou retry.
6. Proposta real somente com autorização final expressa do cliente/operador.
7. Status bruto, status normalizado, ação pendente, motivo e link são campos independentes.
8. CPF, RG, endereço, dados bancários, sessão Telegram e links operacionais ficam fora de planilhas e logs abertos.
9. **Supabase/PostgreSQL será a fonte principal de dados e memória operacional.**
10. **Appsmith será o sistema interno da equipe**, usado para clientes, consultas, ofertas, propostas, pendências, filas e monitoramento.
11. **n8n e Gateway continuam responsáveis por regras, integrações e execução.** A interface não deve concentrar lógica crítica.
12. **Power BI será opcional e somente analítico**, após existir volume real e dados confiáveis. Não será CRM nem sistema operacional.
13. **Toda atividade recebe uma estimativa de esforço de 1 a 10 antes da execução.**
14. **Atividades com esforço de 1 a 6 podem ser executadas diretamente no ChatGPT/conectores.**
15. **Atividades com esforço de 7 a 10 devem ser transformadas em prompt estruturado para o Codex**, executadas em branch própria e revisadas antes de merge ou deploy.
16. Codex não substitui revisão: toda entrega complexa passa por inspeção do diff, testes, segurança, documentação e aceite do usuário.

## DE-002 — Supabase + Appsmith + n8n; Power BI analítico

A implantação será progressiva, sem interromper a construção do fluxo principal:

- BKL-016: Supabase/PostgreSQL, criptografia, tokenização, RLS, backup e secrets;
- BKL-018: Supabase Auth/RLS e perfis equivalentes no Appsmith;
- BKL-020: trilha de auditoria canônica no PostgreSQL;
- BKL-024: memória e máquina de estados persistidas na base;
- BKL-035: tela Appsmith de monitoramento operacional;
- BKL-048: indicadores no Appsmith e avaliação posterior do Power BI.

O protótipo começa em ambiente isolado, sem dados reais. O Google Sheets permanece como apoio, exportação e contingência durante a transição.

## DE-003 — Escalonamento por esforço ao Codex

### Escala adotada

- **1–3:** atividade simples, localizada e de baixo risco;
- **4–6:** atividade moderada, com poucas dependências e revisão direta;
- **7–8:** atividade complexa, com múltiplos arquivos, integrações, migrations, testes ou risco de regressão;
- **9–10:** atividade crítica, com segurança, dados sensíveis, infraestrutura, arquitetura ou impacto amplo.

### Regra operacional

1. estimar o esforço antes de iniciar;
2. informar a nota no começo da atividade quando ela for relevante;
3. para esforço **7 ou maior**, criar `docs/PROMPT_CODEX_<TAREFA>.md`;
4. o prompt deve conter contexto, escopo, restrições, critérios de aceite, testes, segurança, arquivos esperados e formato do relatório final;
5. o Codex trabalha em branch própria, sem merge e sem deploy automático;
6. após a execução, revisar diff, testes, migrations, documentação, segredos e riscos;
7. somente depois da revisão e do aceite do usuário a mudança pode ser integrada.

### Exceções

- ações que dependem de login, segredo, pagamento, autorização, ambiente real ou interface do usuário continuam manuais;
- o Codex pode preparar código, scripts e instruções, mas não deve receber credenciais reais;
- uma urgência só pode quebrar essa regra com autorização explícita do usuário.

A BKL-016 foi classificada como **9/10** e já possui o arquivo `docs/PROMPT_CODEX_BKL-016.md`.

## Checkpoint técnico concluído

- três contas Telegram vinculáveis;
- CLT e FGTS simultâneos, sem mistura de contexto;
- conta de status com acesso cruzado às propostas;
- sessão MTProto persistente após reinício;
- retry idempotente com o mesmo `operation_id` e somente uma mensagem enviada.

A rota provisória do MVP é:

1. API oficial da fornecedora, quando disponível e comprovada;
2. MTProto com contas separadas enquanto isso;
3. Telegram Web RPA apenas como contingência.

A **BKL-014** está concluída.

## BKL-012 — mapeamento das propostas

### CLT confirmado

1. banco e oferta;
2. RG somente números; RG novo pode usar CPF;
3. órgão emissor;
4. UF emissora;
5. data `DD/MM/AAAA`, rejeitando data inválida ou futura;
6. código COMPE;
7. agência sem dígito ou possibilidade de pular;
8. conta com dígito e separador;
9. tipo de conta;
10. revisão e correção;
11. confirmação final;
12. criação e protocolo.

O endereço veio automaticamente do cadastro no fluxo observado. Só deve ser solicitado se o sistema pedir correção.

### FGTS pendente

A consulta, os pré-requisitos e os retornos sem oferta foram confirmados. Os campos pós-oferta continuam como **A confirmar FGTS** até surgir cliente autorizado com oferta real.

## BKL-013 — acompanhamento CLT

Já foram observados:

- proposta criada;
- consulta por número de contrato;
- status `Em análise de compliance`;
- assinatura pendente;
- motivo operacional;
- link de assinatura/coleta.

O parser deve manter separados:

- `status_raw`;
- `status_normalizado`;
- `acao_pendente`;
- `motivo_raw`;
- `link_assinatura_ref`;
- `last_checked_at`.

## BKL-015 — Dicionário de Dados multiproduto

**Status: Concluído v1.**

Foi criada na planilha a aba `Dicionário de Dados`, com `DD-001` a `DD-072`, cobrindo:

1. Cliente;
2. Consulta;
3. Oferta;
4. Proposta;
5. Interação;
6. Pendência;
7. Operação técnica.

Também foram alinhadas as estruturas operacionais:

- `Clientes`;
- `Consultas`;
- `Ofertas`;
- `Propostas`;
- `Interações`;
- `Pendências`;
- `Operações Técnicas`.

As abas agora usam identificadores próprios, referências entre entidades, produto separado, `operation_id`, aliases, códigos, estados normalizados e versões mascaradas.

### Regras de segurança incorporadas

- CPF completo: referência segura ou tokenização;
- planilha: somente CPF mascarado;
- RG, endereço e conta bancária: storage criptografado;
- sessão MTProto: cofre de secrets; operação usa somente `session_alias`;
- link de assinatura: referência protegida;
- retorno bruto e logs: storage protegido, mascaramento e retenção;
- retry: mesmo `operation_id`; `random_id` determinístico na rota MTProto.

Campos FGTS ainda não observados entram como manutenção do dicionário, sem reabrir a arquitetura.

## Próxima tarefa

### BKL-016 — Base protegida e fundação do sistema interno

**Status: Em andamento.**

**Esforço estimado: 9/10 — execução pelo Codex, com revisão obrigatória.**

Decisão inicial aprovada:

- Supabase/PostgreSQL como base principal;
- Appsmith como interface interna futura;
- Sheets como apoio temporário;
- Power BI somente depois, para dashboards gerenciais.

Próximas ações:

1. o usuário cria ou seleciona manualmente um projeto Supabase exclusivo de desenvolvimento, vazio e sem integrações;
2. o usuário confirma somente a criação e o project ref não secreto;
3. após autorização explícita, executar o preflight na fase `LinkInspection` e conferir o alvo duas vezes;
4. vincular somente ao projeto confirmado, inspecionar sem alterar e executar `supabase db push --dry-run`;
5. parar novamente para revisão e nova autorização antes de qualquer migration remota;
6. validar RLS, Storage e integridades somente com transações/fixtures sintéticas removíveis;
7. registrar a decisão de KMS/cofre, backup, retenção, anonimização e recuperação;
8. manter Appsmith e n8n desconectados durante toda esta tarefa.

### Preparação em código realizada em 15/07/2026

- criada migration reversível/revisável para schemas `public`, `app_private` e `audit`;
- criadas as estruturas mínimas operacionais, privadas, perfis e auditoria append-only;
- RLS ativada com negação por padrão e papéis iniciais conservadores;
- buckets privados preparados sem policy pública;
- criado seed exclusivamente sintético;
- criados teste SQL e varredura estática de segredo/CPF;
- criada documentação de acesso, Storage, cofre, retenção, anonimização, backup e aplicação.

Naquela preparação inicial a migration ainda não havia sido aplicada. Posteriormente ela foi aplicada somente no projeto isolado `cbn-dev`; produção, usuários reais, KMS/cofre, policies finais de Storage, restauração e retenção legal permanecem intocados ou pendentes. A BKL-016 continua **Em andamento** até essas validações e revisão independente.

### Correções da revisão técnica preparadas

- corrigida a constraint de `interactions.event_type`;
- máscaras de CPF e telefone agora exigem `*` e rejeitam sequências completas;
- proposta exige evidência de autorização vinculada a `app_private.protected_payloads`;
- a FK da autorização final compara payload, cliente, operação e tipo; uma evidência de outro dono não pode ser reutilizada;
- a evidência final nasce ligada ao cliente e à operação antes da proposta, evitando dependência circular;
- consultas e propostas validam `operation_id`, cliente e produto por FK composta, impedindo reutilização cruzada de operação;
- rollback local respeita a proteção do Supabase Storage e remove somente buckets vazios;
- rollback reordenado para remover dependências privadas antes das tabelas públicas;
- testes SQL passaram a usar usuários Auth sintéticos, troca de role/claims e operações reais de RLS;
- `anon` perdeu permissões de execução desnecessárias;
- escrita futura de ciphertext foi definida como conexão PostgreSQL backend dedicada, fora do PostgREST.

Em 15/07/2026, migration, seed, suíte SQL/RLS, rollback com preservação de bucket contendo objeto e reaplicação foram aprovados em Supabase local descartável. A suíte terminou duas vezes com `BKL-016 database and RLS checks passed`. Nenhum projeto remoto foi vinculado, e nenhum deploy foi realizado.

### Preparação da fase remota realizada em 15/07/2026

- criada a branch `codex/bkl-016-remote-dev` a partir da `main` atualizada por fast-forward;
- diagnóstico confirmou Docker 29.6.1, Compose 5.3.0, Supabase CLI 2.109.1 e psql 17.10;
- a CLI Supabase foi autenticada interativamente pelo usuário e o projeto isolado `cbn-dev` foi confirmado duas vezes pelo ref não secreto;
- o vínculo local corresponde ao alvo confirmado e seus metadados permanecem ignorados em `supabase/.temp`/`.branches`;
- criado `docs/BKL-016_REMOTE_DEV_RUNBOOK.md` com duas paradas humanas e proibição de credenciais no chat;
- criados preflight, validador remoto, limpeza por manifesto sintético e teste estrutural remoto;
- o preflight falha de forma segura sem ambiente, alvo, confirmação e revisão do dry-run;
- `app_private` e `audit` continuam fora da lista local de schemas expostos;
- `.gitignore` já protegia os metadados locais da CLI e não precisou ser alterado.

Após autorização, o `supabase link` foi concluído sem senha em argumento. A inspeção somente leitura confirmou histórico remoto de migrations vazio, migration local `20260715` pendente e nenhuma tabela reportada pelo inspetor. Com autorização separada, `supabase db push --dry-run --linked` listou somente `20260715_001_bkl016_secure_storage.sql` e não fez escrita.

Após uma terceira autorização explícita, `supabase db push --linked` aplicou somente `20260715_001_bkl016_secure_storage.sql`, sem seed. A primeira validação remota encontrou grant indevido de `anon`; a migration corretiva `20260716_001_bkl016_revoke_anon_operational_grants.sql` passou em dry-run, foi aplicada sem seed e conciliou o histórico local/remoto.

Depois da correção, a validação estrutural e a suíte transacional completa passaram. RLS e integridades foram exercitadas com claims/papéis sintéticos; todas as fixtures terminaram em `ROLLBACK`, nenhum usuário Auth foi criado e as 13 tabelas ficaram com zero linhas estimadas. Os buckets privados e a ausência de policy pública foram confirmados.

O primeiro upload pela CLI experimental foi recusado antes de criar objeto; essa lacuna foi posteriormente fechada pelo runtime backend validado abaixo. O plano Free não oferece backup agendado nem PITR; dump manual somente de schema passou, mas restauração não foi comprovada. KMS gerenciado com envelope encryption é a recomendação técnica, ainda pendente de provedor/aprovação. A BKL-016 continua **Em andamento**, sem integração n8n/Appsmith e sem alteração em produção.

### Runtime de Storage validado

A branch `codex/bkl-016-storage-runtime` parte da `main` atualizada e contém preflight reforçado, wrapper PowerShell com entrada oculta e teste Node.js backend usando `@supabase/supabase-js` `2.110.6`. O fluxo está limitado ao bucket temporário, a objeto UUID/conteúdo sintético em memória, URL assinada nominal de 30 segundos, hash SHA-256, negação anônima, varredura de vazamento e limpeza em `finally`.

Os 9 testes negativos locais e o preflight remoto sanitizado passaram. Após o gate humano, o ciclo real aprovou upload de 94 bytes, negação anônima `4xx`, SHA-256 antes da expiração, falha `4xx` após 36 segundos para TTL de 30 segundos, varredura local, limpeza e revalidação SQL `complete/passed`. A listagem recursiva final encontrou zero objetos; chave, senha e URL não foram impressas nem persistidas.

Os seis marcadores finais do runtime foram atingidos. **Ponto exato de retomada:** decidir KMS/cofre e rotação, comprovar restauração, definir retenção/legal hold e revisar policies finais. Não houve produção, n8n, Appsmith, usuário Auth, fixture persistente ou dado real. BKL-016 segue **Em andamento** até essas pendências e revisão independente.

### KMS e envelope validados somente em ambiente local

A branch `codex/bkl-016-kms-envelope` acrescenta contrato KMS neutro, adaptador local bloqueado fora de teste e serviço de envelope com primitivas nativas do Node.js. O formato v1 usa AES-256-GCM, DEK de 32 bytes e nonce de 12 bytes aleatórios por gravação, tag obrigatória e AAD de contexto sem PII. Logs/auditoria ficam limitados a evento, algoritmo, alias e versões.

A migration nova `20260717_001_bkl016_envelope_metadata.sql` foi criada em vez de editar migrations já aplicadas. Ela preserva linhas legadas, rejeita envelope parcial e cobre payloads e referências de arquivos. O rollback incremental falha fechado quando existirem envelopes novos.

Rotação de KEK foi modelada como rewrap da mesma DEK, sem tocar no ciphertext; rotação de DEK descriptografa/recriptografa em memória e conserva o envelope anterior em falha. Testes locais exercitam ambos os fluxos e recuperação. O runbook e relatório desta fase são `docs/BKL-016_KMS_ENVELOPE_RUNBOOK.md` e `docs/RELATORIO_BKL-016_KMS_ENVELOPE_LOCAL.md`.

A comparação oficial de 15/07/2026 mantém três caminhos: KMS gerenciado, Vault Transit e cofre de credenciais mais envelope próprio. A recomendação técnica preliminar é avaliar KMS gerenciado primeiro, mas **nenhum provedor foi escolhido ou acessado e nenhuma chave real foi criada**.

**Ponto exato de retomada:** Guilherme decide provedor/região/custo/IAM/auditoria/recuperação. Parar antes de autenticar, ativar API/billing, criar/importar KEK, criar Vault ou gravar segredo Railway. Depois disso, abrir tarefa separada para adaptador remoto sintético. BKL-016 segue **Em andamento**.

### Backup/restauração sintética local — 16/07/2026

A branch `codex/bkl-016-backup-restore` comprovou, sem conexão remota, backup de schema/dados sintéticos, reconstrução do schema por migrations, restauração do dump, backup/restauração de objeto Storage por hash e recuperação de envelope com KEK local efêmera. A ausência da versão da KEK e a adulteração falharam fechadas; o rollback incremental preservou o envelope.

As suítes SQL/RLS e constraints passaram dentro da prova. RTO local final: **105,08 s**. RPO do teste: snapshot exato; em operação será o intervalo entre backups até haver PITR. Todos os artefatos, objetos e containers foram removidos. Google Cloud KMS real permanece bloqueado por faturamento; dados reais e produção continuam proibidos.

**Ponto de retomada:** retenção/legal hold e policies finais podem avançar localmente. KMS real só retoma após disponibilidade financeira e nova autorização humana. A BKL-016 geral permanece **Em andamento**.

## Tarefas vivas paralelas

- BKL-007 — validação regulatória e operacional;
- BKL-011 — catálogo de produtos contínuo;
- BKL-012 — fluxo FGTS pós-oferta;
- BKL-013 — assinatura, análise, aprovação, pagamento ou cancelamento.

## Arquivos do repositório

- `telegram-gateway/src/auth.js`
- `telegram-gateway/src/check-session.js`
- `telegram-gateway/src/idempotency-test.js`
- `docs/DICIONARIO_DADOS.md`
- `docs/BACKLOG_CHECKPOINT.md`
- `docs/ARQUITETURA_TECNICA.md`
- `docs/PROMPT_CODEX_BKL-016.md`
- `docs/PROMPT_CODEX_BKL-016_REMOTE_DEV.md`
- `docs/BKL-016_REMOTE_DEV_RUNBOOK.md`
- `docs/BKL-016_BACKUP_RESTORE_RUNBOOK.md`
- `docs/PROMPT_CODEX_BKL-016_BACKUP_RESTORE.md`
- `scripts/supabase-remote-preflight.ps1`
- `scripts/supabase-remote-validate.ps1`
- `scripts/supabase-remote-cleanup.ps1`
- `scripts/supabase-storage-runtime-run.ps1`
- `scripts/supabase-storage-runtime-test.mjs`
- `scripts/supabase-storage-runtime-test.test.mjs`
- `.env.example` sem credenciais

## Regras para retomar

1. abrir este handoff;
2. estimar o esforço da próxima atividade em escala de 1 a 10;
3. se o esforço for 7 ou maior, criar prompt para o Codex antes da execução;
4. continuar pela BKL-016;
5. revisar a preparação remota e criar/selecionar somente um Supabase de desenvolvimento isolado, sem dados reais;
6. informar ao Codex apenas a confirmação e o project ref não secreto, nunca senha ou token;
7. implementar Appsmith progressivamente nas tarefas correspondentes, sem parar o fluxo principal;
8. manter BKL-012 e BKL-013 como tarefas vivas não bloqueantes;
9. não gerar nova sessão Telegram sem necessidade;
10. não registrar segredo ou dado completo de cliente em código, planilha, print ou chat;
11. não criar proposta sem autorização final expressa.

### BKL-018 — Fundação local de autenticação e perfis

Em 16/07/2026 foi validada localmente a fundação de perfis humanos. `admin`,
`operations`, `support` e `auditor` permanecem separados dos quatro papéis
técnicos `NOLOGIN` da BKL-016. Perfis possuem estado `ACTIVE`, `DISABLED` ou
`PENDING_REVIEW`; somente `ACTIVE` participa das policies operacionais.

A gestão de `user_profiles` não aceita DML web direto e ocorre por RPCs
controladas, com bloqueio de autoelevação, papel técnico e `service_role` como
identidade humana. Migration, RLS, auditoria mínima, rollback fail-closed,
rollback limpo e reaplicação passaram somente com fixtures sintéticas locais.

**Ponto de retomada:** após revisão e merge da branch, a BKL-020 cria a
auditoria canônica. Appsmith, usuários reais, convites, MFA e produção continuam
fora do escopo e proibidos nesta fase.
