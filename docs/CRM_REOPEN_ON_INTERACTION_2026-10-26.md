# Reabrir conversa resolvida ao enviar/receber — 26/10/2026

## Estado final: publicado no servidor

O proprietário pediu reabertura em qualquer interação com o cliente após observar que um envio seu mantinha a conversa resolvida.

Política `CbnReopenOnInteraction` publicada nos quatro serviços Rails criadores de mensagens: **web, worker WhatsApp, API de operações e worker de operações**. Atua em todas as caixas da conta CBN 1, diretamente no ciclo nativo de criação de `Message`. Inclui interface, plugin/API, agendador e bots/automações, sem depender de encadeamento de regras.

### Comportamento

- Nova mensagem pública `incoming` ou `outgoing` em conversa resolvida: transição para `open`, com trava de linha e método nativo `open!`, antes dos eventos de mensagem e despacho de entrega.
- Não depende de texto: inclui áudio, imagem, documento e anexo sem legenda. Reabre na criação da mensagem, sem aguardar confirmação de entrega do WhatsApp.
- Origem humana, AgentBot ou AutomationRule não impede a reabertura. Nenhuma outra conta recebe a política.
- Preserva a atribuição nativa do ator na entrada por caixa API e os callbacks de mudança de status. Não altera agente/time/etiquetas/cadastro diretamente.
- Atua somente na criação. Recibos de entrega/leitura e edição de mensagem antiga não reabrem a conversa.
- Notas privadas, atividades administrativas e mensagens internas `template` (por exemplo CSAT) não são novas interações públicas incoming/outgoing e não disparam a política.
- Para outros estados/contas, continua o método nativo. Resolvida e silenciada ou com bot ativo abre na entrada/saída pública, conforme o pedido; o silenciamento em si não é alterado.
- Sem replay, reabertura em massa ou nova mensagem criada pela implantação. Escritas SQL/importações que deliberadamente ignorem callbacks ficam fora desse caminho de execução.

## Implementação e implantação

Fonte versionada: `infra/cbn-reopen/cbn_reopen_on_interaction.rb`.

Fonte no VPS: `/opt/cbn/infra/cbn-reopen/cbn_reopen_on_interaction.rb`, SHA256 `a49e413c4d9f0db3cf192cb7f5f436e8c12a13033750a1d2a6f76cd3fdd70508`.

Volume adicional nos quatro serviços do compose atual:

```yaml
- ./cbn-reopen/cbn_reopen_on_interaction.rb:/app/config/initializers/cbn_reopen_on_interaction.rb:ro
```

O initializer faz `Message.prepend` uma vez no boot. Inspeção instalada confirmou `after_create_commit :execute_after_create_commit_callbacks`, que chama `reopen_conversation` antes dos eventos e envio. O comportamento padrão atendia incoming, com exceções para silêncio/bot; não cobria envios públicos comuns.

Imagens preservadas:

- Web: `cbn/chatwoot:4.16.2-cbn-generic-menu-resume-20261022`.
- Worker WhatsApp: `cbn/chatwoot:4.16.2-cbn-contact-schedule-r5-20261006`.
- API/worker de operações: `cbn/chatwoot:4.16.2-cbn-scheduled-media-operations-20261020`.

Recriados apenas esses quatro serviços. Banco, Redis e WAHA não reiniciados. Sem migration ou mudança de credenciais/configurações dos bots.

Publicado às `2026-10-26T21:40:18Z` (18h40 de Brasília). Backup do compose e manifesto em `/opt/cbn/builds/reopen-on-interaction-20261026/`, backup `before-20261026T213853Z/`. Manifesto contém imagens e hashes das fontes/configurações preservadas.

## Regra provisória 15

**CBN — Reabrir resolvida ao enviar ou receber mensagem** foi criada/ativada inicialmente enquanto o SSH estava indisponível. Condições: status resolved, message_type incoming/outgoing e private_note false; ação open_conversation.

Após confirmar o complemento nos quatro serviços, a regra foi **desativada** e sua descrição atualizada. Isso evita reaberturas tardias por eventos em fila depois que um atendente já voltou a encerrar a conversa. A política obrigatória está no servidor e não depende desse toggle. Registro final em `infra/cbn-reopen/rule.json`.

## Recuperação do SSH

Site/CRM respondiam HTTP 200 enquanto SSH/TCP 22 expiravam. Após login do proprietário no painel, o firewall 378542 `CBN-web-ssh-20261015` mostrou uma origem /32 antiga, diferente do IP público atual.

O proprietário autorizou explicitamente **trocar somente esse IP**. A origem TCP 22 foi substituída pela atual /32 e sincronizada; HTTP/HTTPS e bloqueio geral preservados. Nenhuma senha/chave mudou. SSH com a chave existente voltou e permitiu implantar.

O console web alternativo exigia login próprio e não foi usado para comandos. Capturas de revisão/aplicação em `outputs/ssh-current-ip-review-20261026.png` e `outputs/ssh-current-ip-applied-20261026.png`, fora do Git.

## Conferências e limites

- Ruby -c aprovado antes da implantação; git diff --check conferido.
- Nos quatro serviços, inspeção Rails confirmou método pertencendo ao novo módulo, original disponível via super e callback nativo preservado. Hash do initializer igual ao publicado em cada container; todos em execução.
- Fontes/configurações dos bots de coleta/menu preservadas por hashes. Regra 15 consultada e confirmada inativa após substituição.
- Site e CRM HTTP 200; WhatsApp WORKING após implantação.
- Nenhuma suíte, simulação de atendimento ou mensagem de teste. Efeito funcional completo ainda não observado em uma nova interação real. Conferências de carregamento/sintaxe não são teste de atendimento ou garantia de disponibilidade do canal.

## Retorno

1. Remover somente o volume do novo initializer nos quatro serviços e recriá-los com --no-deps. Não restaurar compose inteiro se outras tarefas o modificaram depois.
2. Para voltar à cobertura parcial por automação, reativar regra 15. Não cobre mensagens de outras automações e pode sofrer atraso da fila.
3. Preservar estados já alterados; não encerrar conversas em massa para desfazer reaberturas.
4. A troca do IP SSH é independente do recurso. Não restaurar automaticamente a origem antiga, que não corresponde à conexão atual.

Referências primárias usadas como orientação, complementadas pela inspeção instalada:

- [Guia de automações](https://www.chatwoot.com/hc/user-guide/articles/1677238266-lesson-4-complete-your-customer-engagement-suite).
- [Ação nativa open_conversation](https://github.com/chatwoot/chatwoot/blob/develop/app/services/action_service.rb).
- [Ciclo de criação e reabertura](https://github.com/chatwoot/chatwoot/blob/develop/app/models/message.rb).
