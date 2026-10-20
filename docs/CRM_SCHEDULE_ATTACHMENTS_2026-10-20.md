# Anexos em agendamentos

## Pedido e experiência

O proprietário solicitou anexos no agendamento, com texto dispensável quando
houver arquivo. A tela agora oferece **Adicionar anexos**, nomes/tamanhos dos
selecionados e remoção antes de salvar. A lista de agendamentos exibe os arquivos.
Editar permite manter anexos, remover arquivos e acrescentar outros.

São aceitos texto, arquivo sem texto ou arquivo com legenda. Tudo vazio é
rejeitado na interface e no servidor. Limites: 10 arquivos, 20 MiB por arquivo,
50 MiB por agendamento; horário continua Brasília, futuro de 1 minuto a 180 dias.

## Servidor e persistência

- `ScheduledMessage.has_many_attached :files` reutiliza Active Storage e o
  armazenamento privado existentes. Nenhuma coluna/tabela/migration nova.
- Upload multipart `attachments[]`; edição aceita `remove_attachment_ids[]`
  somente de anexos do agendamento/conversa/conta autorizados. A API não aceita
  URLs, chaves de objetos ou IDs de blobs arbitrários enviados pelo usuário.
- Conteúdo, arquivos, tipos, tamanhos e SHA-256 compõem a conferência de retry
  da criação com o mesmo `request_id`. Upload ocorre antes do commit do
  agendamento, e blobs sem associação são limpos em falha. Append na edição
  ignora arquivos idênticos já retidos, evitando repetição após retry.
- Autor humano, política da conversa, caixa CBN 5, contato bloqueado, lock do
  agendamento e guardas de prazo/permissão permanecem. Campos de upload são
  filtrados dos parâmetros de log; erro técnico registra somente classe.
- Dispatcher mantém a transação mensagem/estado e passa os blobs como anexos ao
  `Messages::MessageBuilder`. O worker WAHA existente processa o envio nativo.
  Signed IDs são gerados no despacho; a referência ao arquivo não depende de
  uma URL temporária emitida na criação do agendamento.
- Estado queued continua distinguido de delivered/read. Não há retry de envio
  automático novo, replay de histórico ou modificação de campanhas/automação.

## Plugin

- `crm_stage_upload` prepara cada arquivo local permitido e retorna `upload_id`.
- `schedule_create`/`schedule_update` aceitam `upload_ids` (máximo 10). `content`
  pode ser omitido/vazio com anexos. Edição pode conservar anexos existentes
  mesmo sem novos uploads e sem texto.
- `remove_attachment_ids` remove apenas anexos encontrados no agendamento
  consultado na prévia. UUIDs, hashes, estado incerto, expiração e autorização
  continuam protegidos. Previews antigos recebem os defaults novos de forma
  canônica, sem desbloquear/repetir ações incertas.
- Runtime persistente e cache instalados receberam `crm.mjs`, `schemas.mjs` e
  `tools.mjs`, preservando credenciais e estados. Backups de código ficam em
  `%LOCALAPPDATA%/CBN/crm-plugin/updates/scheduled-media-20261020/`.
- CLI nova carrega o código atualizado; MCP já aberto precisa reconectar.

## Publicação e evidência

- Imagens web `cbn/chatwoot:4.16.2-cbn-scheduled-media-ui-20261020` e operações
  `cbn/chatwoot:4.16.2-cbn-scheduled-media-operations-20261020`.
- Builds concluídos e sintaxe Ruby/JavaScript conferida. Sem testes automatizados
  ou agendamento/disparo de teste para clientes, conforme escopo autorizado.
- Backup e manifesto em `/opt/cbn/builds/schedule-media-20261020/`, backup inicial
  `before-20261020T211710Z/`. Worker de operações atualizado antes da API, depois
  web. WAHA e worker de integração não foram reiniciados.
- Após publicação: web, API e dispatcher rodando sem reinícios; CRM HTTP 200;
  API instalada consultou a conversa técnica e retornou array vazio com sucesso.
  Reflection Rails confirmou associação `files`; heartbeat recente do agendador.
  As 21 agendas pendentes existentes foram preservadas.
- Confirmação de recebimento de arquivo pelo destinatário ficará para o primeiro
  envio operacional autorizado; build/heartbeat não são evidência de entrega.

## Retorno seguro

Rollback visual pode restaurar somente web anterior
`cbn/chatwoot:4.16.2-cbn-secretaria-label-20261020`. Depois de existirem agendas
com arquivos, não restaurar dispatcher/API antigos: eles não reconhecem anexos.
Manter backend novo e corrigir adiante, ou cancelar/reconciliar essas agendas por
ação humana antes de downgrade. Não apagar blobs, mensagens ou agendas para
contornar erro. Imagens e snapshot do compose permanecem disponíveis.
