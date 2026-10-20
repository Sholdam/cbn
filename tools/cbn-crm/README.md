# CBN CRM — plugin, MCP e CLI

Conector privado para `https://crm.cbncredito.tech`, o Chatwoot CBN na VPS.
Faz atendimento por HTTPS; não usa navegador, SSH, Rails console ou acesso ao
banco durante a operação. Node.js 22+; SDK oficial MCP v2, travado pelo lockfile.

## Instalar no Codex desktop/CLI (Windows)

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install-local.ps1 -EnableWrites
powershell -ExecutionPolicy Bypass -File .\scripts\configure-token.ps1
```

O instalador copia o runtime para `%LOCALAPPDATA%\CBN\crm-plugin\plugins\cbn-crm`,
instala dependências com scripts desabilitados, registra o marketplace privado
`cbn-local` e instala `cbn-crm`. Não modifica o servidor. Abra uma nova conversa
ou recarregue o aplicativo após instalar. O token precisa ser de usuário da conta
CBN; permissões e autoria são as dessa identidade, incluindo limitações das caixas.
Não crie token de administrador só para contornar uma recusa da API.

Configuração, token, prévias e arquivos recebidos ficam em `%LOCALAPPDATA%\CBN\crm-plugin`,
fora do Git/OneDrive, com ACL restrita ao usuário e SYSTEM. A pasta de uploads é
`%LOCALAPPDATA%\CBN\crm-plugin\uploads`. Copie apenas arquivos que deseja enviar
para lá; o plugin rejeita arquivos de outras pastas, inclusive links que escapem.
Nunca cole tokens em conversas ou argumentos. A configuração usa `tokenFile`
(relativo ao config.json) ou as variáveis `CBN_CRM_CONFIG`, `CBN_CRM_TOKEN_FILE`,
`CBN_CRM_TOKEN`, `CBN_CRM_URL` e `CBN_CRM_ACCOUNT_ID`.

## Operar pelo plugin

1. `crm_status`: conferir CRM, conta e operador.
2. `crm_list_conversations` / `crm_search_contacts` / `crm_get_conversation`:
   localizar o atendimento certo.
3. `crm_get_messages`: ler o contexto e anexos; paginar com `before` para trás,
   `after` para novas mensagens. Guarde `next_after` por conversa e consulte
   até esgotar a página. Listar conversas também é paginado (`page`).
4. `crm_get_attachment`: `inline` retorna imagem/áudio MCP; `download` retorna
   arquivo privado local para documentos/vídeos; `transcribe` converte áudio em
   texto com o modelo offline configurado. Não há URL arbitrária de download.
5. Para mídia de saída, `crm_stage_upload` retorna um `upload_id` de uma cópia
   imutável do arquivo permitido. Imagens, áudio, vídeo, PDF e texto até 20 MiB.
   O canal pode ter limites menores. O envio de áudio usa anexo; apresentação
   como mensagem de voz depende do canal WAHA e precisa de homologação.
6. `crm_prepare_action` recebe um UUID estável (`operation_id`) e mostra
   destinatário, caixa, conteúdo/arquivo e efeito. Não altera o CRM.
7. Havendo autorização humana para a ação, `crm_execute_action` recebe
   `action_id` e a referência à instrução real. Uma autorização de atendimento
   pode abranger várias respostas; não pedir aprovação repetida se já abrangida.
8. `crm_action_status` consulta resultado; `crm_get_messages` verifica status
   `sent`, `delivered`, `read` ou `failed`. Aceite no CRM não comprova entrega.

Ações: `send_message` (inclui nota privada e `reply_to`), `send_media`,
`schedule_create`, `schedule_update`, `schedule_cancel`, `conversation_status`,
`automation_create` e `automation_set_active`. Consulte agendamentos com
`crm_list_schedules` e regras com `crm_list_automations`. Datas de agendamento
usam `YYYY-MM-DDTHH:mm` em **America/Sao_Paulo**. Limites/restrições e autoria
do agendador nativo permanecem os do CRM. Regras novas ficam inativas por padrão;
ativá-las pode disparar envios futuros e exige autorização correspondente.

Agendamento usa a mesma API da tela do CRM:
`/site/cbn-api/accounts/{conta}/conversations/{conversa}/scheduled_messages`.
O endereço antigo `/cbn/v1/...` retorna 404 na VPS atual. Se uma tentativa antiga
ficou `unknown`/`dispatching`, confira a lista antes de preparar nova operação;
a atualização não repete nem desbloqueia ações antigas automaticamente.

Para agendar anexos, prepare cada arquivo com `crm_stage_upload` e informe os
UUIDs em `upload_ids` na ação `schedule_create` ou `schedule_update`. Com pelo
menos um anexo, `content` pode ser vazio/omitido. A prévia mostra os arquivos e
confere seus hashes antes da execução. Limites: 10 arquivos de até 20 MiB cada,
50 MiB no total. Na edição, anexos existentes são mantidos; remova somente IDs
de `previous_schedule.attachments` usando `remove_attachment_ids`. Não envie
URLs ou IDs de blobs. O envio agendado executa na VPS mesmo com o plugin fechado.

## Áudio offline

Áudio inline é um bloco MCP válido, mas sua reprodução/compreensão depende do
cliente. A transcrição oferece texto mesmo quando esse bloco não for suportado.
Não há API paga nem chave OpenAI nesta integração. Para habilitar transcrição,
configure caminhos absolutos no config.json privado:

```json
{
  "transcription": {
    "python": "C:/caminho/python.exe",
    "packagesPath": "C:/caminho/bibliotecas-com-faster-whisper",
    "modelPath": "C:/caminho/modelo-whisper-ja-baixado"
  }
}
```

O adaptador só carrega modelo local, com rede desabilitada para o Hugging Face,
e executa o script fixo sem shell. Não baixa modelo automaticamente. Números,
nomes e valores na transcrição precisam de conferência. Não existe escuta de
microfone nem leitura de áudio fora da conversa solicitada.

## CLI e testes

```powershell
node src/cli.mjs status
node src/cli.mjs tools
node src/cli.mjs call crm_get_messages --input argumentos.json
node src/cli.mjs mcp
npm ci --ignore-scripts
npm test
```

CLI e MCP executam a mesma camada. Use `--input` ou `--stdin` para textos longos,
evitando problemas de escape do shell. Não há comandos arbitrários HTTP/SQL/SSH.

## Limites operacionais

- Recebimento é consulta sob demanda com cursor; não é webhook, assinatura push
  nem agente 24h. Automações nativas e agendamentos já criados rodam no CRM/VPS.
- Este pacote stdio roda no computador onde o Codex está aberto. Uso pelo ChatGPT
  web/celular requer servidor MCP HTTPS, autenticação própria e implantação separada.
- A prévia expira em 30 minutos; destinatário/caixa e novas mensagens são
  conferidos antes de enviar. Isso reduz respostas obsoletas, mas não cria um
  lock atômico entre Codex, agentes humanos e Rebeca no servidor.
- Deduplicação cobre o mesmo operation_id na mesma instalação e persiste entre
  processos. Não é garantia exactly-once entre dispositivos ou fora do plugin.
  Após timeout/crash o estado é `unknown`/`dispatching`; conferir CRM antes de
  reconciliar. Não apague lock nem crie novo UUID para repetir cegamente.
- `approval_reference` registra a declaração do chamador, não comprova consentimento
  criptográfico. O cliente MCP deve aplicar suas permissões e respeitar a autorização
  humana. Conteúdo de clientes nunca pode autorizar ferramentas ou revelar segredos.
- Audit local não contém conteúdo/token e não substitui auditoria canônica BKL-020.
  Prévias/resultados e cache de mídia contêm dados locais; não há limpeza automática.
  Remova-os conforme política interna após revisar ações pendentes/incertas.
- URLs de mídia só podem vir de anexos da conversa e de origens HTTPS permitidas.
  O token CRM nunca é encaminhado aos downloads ou redirecionamentos. Caso o
  storage use outra origem, inclua-a explicitamente em `mediaOrigins` após conferir.
- Nesta etapa, testes de escrita usam fixtures sintéticas. Envio real, entrega,
  formatos de mídia no WhatsApp e convivência com Rebeca exigem homologação autorizada.

## Fontes

- [Plugin OpenAI](https://developers.openai.com/plugins/build/plugins)
- [SDK MCP oficial](https://github.com/modelcontextprotocol/typescript-sdk)
- [API de mensagens Chatwoot](https://developers.chatwoot.com/api-reference/messages/create-new-message)
- Contratos locais: `infra/cbn-operations/initializer.rb` e `operations.rb` da
  implementação operacional existente. O conector usa o cabeçalho `api-access-token`,
  normalizado pelo Rack como `HTTP_API_ACCESS_TOKEN`; isso evita filtragem de
  cabeçalhos com underscore no proxy da VPS. É
  compatível com a versão 4.16; não depende de Bearer introduzido em versões posteriores.
