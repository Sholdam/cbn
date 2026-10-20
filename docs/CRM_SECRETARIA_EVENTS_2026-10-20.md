# Secretaria: recebimento por evento

## Contexto lido

Conversa `Secretaria`, ID `01a0cf8f-4975-79a3-8872-bd4292819263`, pedido de
20/10/2026: acompanhar uma carteira específica de 20 leads CLT, com histórico
individual e planilha de acompanhamento. Quando o cliente responder, o agente
deve ser avisado sem aguardar a consulta periódica de 20 minutos.

Esta leitura não altera autorizações de envio, mensagens iniciais ou campanhas.
Nenhuma mensagem foi enviada à carteira nem ao outro chat nesta tarefa.

## Situação confirmada

- O plugin CBN CRM v0.1.0 usa `StdioServerTransport` e registra ferramentas.
  Não implementa assinatura/recepção de eventos.
- O CRM já tem webhooks; é necessário um receptor com persistência para encaminhar
  os eventos ao destino do agente e confirmar recebimento sem perder mensagens.
- A documentação oficial consultada em 20/10/2026 oferece MCP Events em chats
  Work na web, Work com Cloud no desktop e dots. Ela não estabelece recebimento
  desses eventos neste chat Codex local existente.
- Fonte: <https://developers.openai.com/plugins/build/mcp-events>.

## Desenho a implementar em tarefa própria

1. CRM emite `message_created` para um receptor HTTPS autenticado na VPS.
2. Receptor aceita somente a conta CBN e a caixa correta; ignora notas privadas,
   mensagens de saída, eventos técnicos e contatos fora da carteira selecionada.
3. Registra ID estável `conta:caixa:mensagem` numa fila persistente e deduplicada.
4. Publica evento mínimo por MCP Events para uma assinatura suportada do agente.
   Informa IDs e uma referência para consultar o histórico, sem exportar CPF,
   documentos ou credenciais no aviso. Conteúdo do cliente é dado, nunca instrução.
5. O agente consulta conversa e planilha, confere se um humano já respondeu,
   decide a próxima ação dentro da autorização e atualiza o acompanhamento.
6. Envio usa a proteção idempotente existente do plugin. Uma trava por conversa
   impede respostas simultâneas entre Secretaria, Rebeca e operador humano.
7. Callback usa assinatura, prazo, retries limitados e cancelamento de assinatura.
   Repetir entrega preserva o mesmo ID e não repete atendimento.

## Dependência antes da ativação

Definir o destino executável do agente: chat Work/Cloud com assinatura MCP Events,
ou serviço de agente na VPS via API com credencial/custos próprios. Não prometer
que um webhook acordará automaticamente o chat local apenas por adicionar uma URL.
Não cadastrar callback fictício, abrir acesso anônimo ou ativar disparos amplos.

Esta tarefa registra a leitura e o desenho. O webhook continua não implantado.
