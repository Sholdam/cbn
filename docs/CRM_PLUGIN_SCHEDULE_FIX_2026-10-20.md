# Correção de agendamento no plugin CBN CRM

## Diagnóstico

O proprietário relatou que não conseguia agendar pelo plugin. A conversa
`Secretaria` também registrou HTTP 404 ao tentar o agendador, sem criação de
mensagem; o atendimento usa outra fila autorizada, que não foi alterada aqui.

Fonte do frontend ativo `CbnScheduleMessage.vue`, proxy Caddy e serviço
`cbn-operations-api` confirmaram a rota pública atual:

`/site/cbn-api/accounts/{account}/conversations/{conversation}/scheduled_messages`

O plugin v0.1.0 usava `/cbn/v1/...`, que não é encaminhado ao serviço de operações
na VPS. Uma consulta autenticada à conversa técnica existente retornou 404 na
rota antiga e 200/array vazio na atual. Não se tratava de falta de permissão.
O diagnóstico inicial de 16/10 usou somente ID inexistente: um 404 não distinguia
conversa ausente de rota ausente e não comprovava o funcionamento do agendador.

## Correção

- `Crm.schedulesRoute` concentra o endereço atual, usado pela consulta e pelas
  ações `schedule_create`, `schedule_update` e `schedule_cancel`.
- Corpo das chamadas permanece igual ao usado pela tela: conteúdo,
  `scheduled_local` em Brasília e UUID estável como `request_id` na criação.
- Autenticação `api-access-token`, permissões, prévia, autorização e estados
  idempotentes foram preservados. Não há fallback/retry automático de escrita.
- Expectativa da asserção já existente foi alinhada à rota atual. Não foram
  adicionados ou executados testes automatizados nesta tarefa.
- A alteração não modifica a VPS, o agendador ou a fila da campanha em execução.

## Instalação e uso

Arquivo `src/crm.mjs` corrigido aplicado no runtime persistente e cache do plugin
instalado, com backup do código anterior e comparação de SHA-256. Configuração,
credencial, estado das ações, prévias e mídias preservados. Hash instalado:
`3b051643011b081bb93f21b8276a31428d88e297d9531ea71da8573027ff8dc7`.
Backup do código em `%LOCALAPPDATA%/CBN/crm-plugin/updates/schedule-route-20261020/`.
A chamada `crm_list_schedules` pela CLI do pacote instalado consultou a conversa
técnica e retornou `[]` com sucesso. Novas invocações da
CLI carregam a correção; processo MCP já aberto precisa reconectar para carregar
o módulo novo. Não encerrar o aplicativo ou atendimentos em andamento.

Reconciliar qualquer tentativa antiga antes de nova criação. Ações antigas
`unknown` ou `dispatching` continuam bloqueadas; não apagá-las nem repetir com
outro UUID para contornar o bloqueio.

Nenhum agendamento ou envio a cliente foi criado como parte da correção. Isso
evita acionar mensagens e alterar a cadência da campanha existente. Criação,
alteração e cancelamento ficam para o próximo uso operacional autorizado.
