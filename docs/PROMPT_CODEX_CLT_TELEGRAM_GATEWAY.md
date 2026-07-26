# Prompt executado — Gateway Telegram CLT

## Nível de esforço: Alto

Implementar, sem deploy, um Gateway Node.js interno que reutilize a sessão
MTProto já validada para consultar o módulo CLT do bot operacional.

Requisitos:

- uma fila por sessão e uma operação ativa;
- `operation_id` idempotente;
- comandos com `random_id` determinístico por etapa;
- aceitar CPF válido e telefone do contato no CRM;
- navegar pelo menu CLT e selecionar todos os bancos;
- responder automaticamente ao pedido opcional de telefone;
- aguardar o término sem enviar durante processamento;
- devolver o texto sanitizado ao callback fixo do n8n;
- exigir que o n8n grave o retorno como nota privada;
- falhar fechado em fluxo inesperado, especialmente C6;
- não persistir CPF, telefone, sessão ou retorno bruto no filesystem;
- não registrar segredo ou PII em logs;
- não criar proposta, enviar resposta ao cliente ou fazer deploy;
- testar validação, serialização, idempotência lógica, telefone opcional e
  revisão humana.

Limite aceito no piloto: fila e dados em voo ficam em memória. A persistência
canônica de locks e estados será implementada na BKL-024.
