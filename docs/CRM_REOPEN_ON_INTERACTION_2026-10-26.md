# Reabrir conversa resolvida ao enviar/receber — 26/10/2026

## Pedido e estado

O proprietário identificou que enviar mensagem a cliente em conversa resolvida não reabria o atendimento. Pediu reabertura para qualquer interação com o cliente. Consideradas mensagens públicas recebidas/enviadas, inclusive anexos; notas internas e atividades administrativas não são interação com o cliente.

**Aplicado:** regra nativa 15 ativa, na conta CBN 1, em todas as caixas, editável em Configurações → Automações. Registro exato da regra em `infra/cbn-reopen/rule.json`.

**Pendente para a garantia absoluta:** complemento no servidor para mensagens públicas criadas por outra automação. A infraestrutura nativa ignora eventos encadeados de automações. O acesso SSH existente ao VPS expirou em duas tentativas nesta sessão; site e CRM responderam HTTP 200. Solicitado ao proprietário informar alteração/restrição do acesso. Não atribuir a indisponibilidade do SSH a queda do CRM.

## Regra 15

- Nome: **CBN — Reabrir resolvida ao enviar ou receber mensagem**.
- Evento: `message_created`.
- Condições em AND: `status = resolved`, `message_type IN [incoming, outgoing]`, `private_note = false`.
- Ação: `open_conversation`, parâmetros vazios.
- Abrange a interface, API/plugin e dispatcher de agendamento quando o evento segue o listener nativo de automações. Não depende do conteúdo de texto, portanto admite arquivo/áudio/imagem sem legenda.
- Não muda agente/time/etiquetas/cadastro nem cria mensagens públicas; a mudança de status segue o serviço nativo, com eventos e atividade interna usuais.
- Somente novos eventos. Não reabre em massa conversas históricas e não usa `conversation_updated`, evitando reabertura em resposta à simples alteração de dados ou à ação Resolver.

## Limites conhecidos

A regra não deve ser apresentada como garantia universal para robôs. O listener nativo evita ciclos ao ignorar eventos cujo `performed_by` é `AutomationRule`; também ignora certos tipos de resposta automática de e-mail. Dependências do worker/fila continuam presentes. Sem acesso ao backend, não foi possível inspecionar a implementação instalada atual nem acrescentar uma política síncrona em todos os criadores de mensagens.

O complemento deverá preservar os demais estados e a autorização nativa, atuar somente em novas mensagens públicas de entrada/saída da conta CBN, fazer a transição de resolvida para aberta pelo modelo nativo e cobrir web, worker WhatsApp, API e worker de operações. Antes de publicar, inspecionar callbacks e imagens efetivas; não trocar imagens com base em versões antigas dos runbooks. Não reprocessar histórico, reenviar mensagens ou recriar dados.

## Conferências e retorno

- Consulta nativa anterior: sem regra equivalente; regras existentes preservadas.
- Criação inativa e ativação pelo plugin CBN CRM, com UUIDs idempotentes e referência ao pedido real do proprietário. Leitura final confirmou ID 15, condições/ação corretas e `active: true`; API aceitou `open_conversation` na versão instalada.
- Nenhum teste ou mensagem ao cliente, alteração remota por SSH ou reabertura manual de conversa nesta tarefa. Funcionamento completo ainda não observado em nova interação real.
- Desativar a regra 15 desfaz a política para novos eventos; conversas eventualmente reabertas por ela não devem ser fechadas em massa automaticamente.

Referências técnicas primárias consultadas, como orientação (não substituem inspeção da versão instalada):

- [Guia de automações](https://www.chatwoot.com/hc/user-guide/articles/1677238266-lesson-4-complete-your-customer-engagement-suite).
- [Ação nativa open_conversation](https://github.com/chatwoot/chatwoot/blob/develop/app/services/action_service.rb).
- [Ciclo nativo de criação e reabertura de mensagens](https://github.com/chatwoot/chatwoot/blob/develop/app/models/message.rb).
