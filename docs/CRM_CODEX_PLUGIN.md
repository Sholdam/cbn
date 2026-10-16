# CBN CRM — integração Codex por plugin — 16/10/2026

## Objetivo e entrega

O proprietário solicitou um plugin CLI/MCP para o Codex atender clientes pela
API do CRM `crm.cbncredito.tech`, evitando depuração no computador/servidor a
cada resposta. Implementação em `tools/cbn-crm`, branch `codex/cbn-crm-plugin`,
em worktree isolado de origin/main. A frente Rebeca preexistente não foi alterada.

Plugin privado `cbn-crm@cbn-local` v0.1.0 instalado no Codex. Treze ferramentas:
status, caixas, busca de contatos, lista/detalhe de conversas, mensagens com
cursores, anexos (imagem/áudio inline, download e transcrição), upload de mídia,
agendamentos, automações, preparação, estado e execução de ações.

A implementação é a mesma no CLI e no MCP stdio. O runtime fica em
`%LOCALAPPDATA%\CBN\crm-plugin\plugins\cbn-crm`; marketplace privado em
`%LOCALAPPDATA%\CBN\crm-plugin\.agents\plugins\marketplace.json`. No Codex o
cache do pacote é `~/.codex/plugins/cache/cbn-local/cbn-crm/0.1.0`.
O mcp.json instalado aponta para o runtime persistente, sem depender do worktree.

Configuração, credencial, prévias e mídia ficam fora do repositório/OneDrive,
sob ACL do usuário/SYSTEM. Reutilizada credencial existente do proprietário na
conta 1; nenhuma identidade, token ou permissão criada/ampliada no servidor.
Autoria/permissões são as do usuário do CRM. Escritas habilitadas no config local
não autorizam contatos ou campanhas não solicitados.

## Contratos e limites

- Chatwoot Application API: perfil, caixas, contatos, conversas, mensagens,
  multipart `attachments[]`, status e regras nativas de automação.
- Agendamentos usam `/cbn/v1/accounts/{account}/conversations/{conversation}/scheduled_messages`
  da implementação CBN existente, com UUID estável e horário de Brasília.
- A VPS filtra cabeçalhos com underscore. Usar `api-access-token`, que Rack
  normaliza para `HTTP_API_ACCESS_TOKEN`; autenticação validada no domínio público.
- Áudio: Whisper base/faster-whisper e Python 3.12 já existentes, configurados
  por caminhos privados absolutos. Transcrição offline, sem download de modelo
  ou API paga. Depende dessas bibliotecas/modelo continuarem disponíveis em disco.
- Imagens/áudios podem ser retornados inline via MCP; suporte do cliente varia.
  Vídeos/documentos retornam arquivo local. Voz como push-to-talk no WhatsApp
  depende do canal; o plugin envia anexo e não promete essa apresentação.
- API privada autenticada; token não é enviado ao baixar mídia/redirecionar.
  URLs vêm do anexo da conversa, com allowlist de origens HTTPS e limite de tamanho.
- Prévia de 30 minutos, conferência do operador/destinatário/caixa/novas mensagens,
  snapshot de mídia e agendamento/regra antes de alteração. Autorização real do
  usuário deve ser respeitada pelo chamador; a referência textual não prova
  aprovação criptográfica. Pode citar autorização de atendimento já em vigor.
- Deduplicação por UUID/instalação persiste entre processos. Estado incerto ou
  execução interrompida bloqueia repetição cega. Não há lock atômico entre plugin,
  agentes humanos/Rebeca ou diferentes dispositivos. Auditoria local sem conteúdo
  não substitui BKL-020. Não há limpeza automática do cache/prévias.
- Consultas recebem mensagens por paginação/cursor, sem listener ou monitor 24h.
  Automações/agendamentos nativos criados no CRM rodam na VPS. O runtime stdio
  exige Codex e computador disponíveis para as chamadas. ChatGPT web/celular
  exige MCP HTTPS com autenticação própria e implantação separada, ainda não feita.

## Evidências

- `npm test`: **15/15 aprovados** com dados sintéticos; cobre estado persistido,
  concorrência/repetição, timeout, autorização/configuração, destinatário obsoleto,
  multipart, privacidade, redirecionamento/limites de mídia, agenda e handshake MCP.
- `node scripts/verify-installed.mjs`: cliente SDK abriu o MCP do pacote instalado,
  descobriu 13 ferramentas e confirmou autenticação, conta 1, quatro caixas e API
  de automações somente leitura. Histórico/agendamentos de ID inexistente
  retornaram 404 autenticado; nenhum histórico de cliente usado no teste.
- `scripts/verify-local-audio.mjs`: áudio WAV sintético, gerado por voz Windows,
  passou pela ferramenta de anexo até transcrição offline. Também validado bloco
  de áudio MCP inline. Texto transcrito identifica CRM; houve erro de palavra,
  reforçando a necessidade de conferir valores/números e informação crítica.
- Instalação de dependências: npm sem vulnerabilidades reportadas na execução;
  scripts de instalação desabilitados e versões resolvidas no package-lock.
- Nenhum envio a cliente, criação/ativação de automação, gravação de agendamento,
  deploy, reinício, migração ou alteração remota executado.

## Próximo uso

Abrir uma nova conversa/recarregar Codex para carregar `CBN CRM`. Solicitar:
“Use o CBN CRM para consultar os clientes aguardando resposta. Leia o histórico
e transcreva os áudios antes de preparar as respostas.” Uma instrução explícita
de envio pode autorizar as respostas dentro de um escopo delimitado.

Envio/entrega reais e convivência com Rebeca ainda precisam de homologação com
destinatário e mensagem autorizados. Instalação e conexão não significam que
esses testes externos já foram feitos. Guia de operação/reinstalação:
`tools/cbn-crm/README.md`.
