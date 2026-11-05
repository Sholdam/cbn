# Bot parava após o CPF e alguns anúncios não iniciavam — 05/11/2026

## Diagnóstico

- WhatsApp estava `WORKING`, containers ativos, memória e disco com folga. Fila crítica vazia e sem retries; o bloqueio não era uma desconexão geral.
- Vários atendimentos INSS tinham CPF salvo e etapa `dados_recebidos`, sem confirmação automática. Logs mostraram `conversation.updated` atribuído à regra 12 (menu), embora fosse a captura de uma resposta do cliente.
- `AutomationRules::ActionService.initialize` nativo define `Current.executed_by`. O complemento do menu retornava sem chamar o `perform` nativo em condições de exclusão; esses caminhos não restauravam o executor. O marcador da regra vazava para outros eventos. O listener nativo ignora eventos atribuídos a outra automação para prevenir ciclos, bloqueando a regra de confirmação.
- Um criativo INSS tinha mensagem diferente das duas frases da regra 5; não iniciava a coleta. O menu também excluía qualquer anúncio, deixando esse cliente sem resposta.

## Correção

- Complemento do menu captura o executor antes da inicialização nativa e o restaura em `ensure` em todos os caminhos que controla, inclusive exclusão, pausa e confirmação sem comando. Outras regras continuam com o comportamento nativo.
- Anúncio sem coleta e sem regra de campanha correspondente pode iniciar o menu padrão. Campanhas reconhecidas (inclusive regras pausadas) e coletas já iniciadas continuam protegidas. Retomada manual também aceita anúncio sem regra correspondente.
- Regra nativa 5 passou a reconhecer o ID do criativo INSS observado, mantendo a mensagem editável e as frases existentes. Não houve troca de textos comerciais nem de credenciais.
- Mesmo initializer corrigido persistido no web e no worker. Web recebeu bind somente leitura para o arquivo já montado no worker; imagens Luna/Transcribe, sessão WhatsApp e demais serviços foram preservados.

## Validação e recuperação

- Teste com a versão anterior reproduziu quatro vazamentos de identidade. Candidata: **9 testes / 13 asserções** aprovados; sete verificações sintéticas anteriores de INSS/CLT aprovadas.
- Após publicação, os nove testes passaram novamente no worker em execução. Testes não criaram registros ou mensagens reais.
- Recuperação operacional separada: revisão de onze conversas recentes, trava por conversa, conferência de estado e última mensagem pública. Somente quatro casos ainda abertos e sem intervenção humana foram retomados pelo serviço nativo, com UUID estável e confirmação de exatamente uma mensagem automática por caso.
- Três receberam somente a confirmação de encaminhamento, aproveitando o CPF já salvo. Um recebeu a saudação/pergunta inicial que não havia sido enviada. Mensagens com remetente automático, sem assinatura de operador. Casos assumidos pelo humano, encerrados ou aguardando resposta do cliente não foram reprocessados.
- A recuperação foi do fluxo de mensagens já solicitado pelo proprietário; não houve disparo de teste, replay global de histórico ou drenagem das filas antigas.
- Releitura confirmou as quatro mensagens `delivered`. Novo atendimento orgânico após publicação completou saudação → CPF válido → confirmação automaticamente; mensagens constavam `read`. Evento da captura sem executor de automação, sem erros novos, sem retries, fila crítica vazia e WhatsApp `WORKING`. Nenhuma conversa recente permanecia em `dados_recebidos` nessa verificação.

## Publicação e evidências

- Backup consistente: `/srv/cbn-production/crm-deploy-backups/bot-context-20261105T230113Z` (dump, compose, fonte e condições anterior/posterior da regra 5).
- Build/revisão: `/opt/cbn/builds/bot-context-20261105T225940Z`, com testes, plano, resultados da recuperação e verificação operacional.
- SHA-256 publicado: `4f49e2b343c4a17dbd4a04b02664ec9fd17562dc2ca6b462de0dcff5cd13b326`.
- CRM/site HTTP 200 e API privada 401 sem sessão. Serviço de sessão WhatsApp não foi reiniciado.
- Retorno: restaurar somente fonte/compose e condições desta edição se ainda não alteradas por outro operador; recriar web/worker. Não restaurar o dump sobre novos atendimentos como rotina.

## Limite de escopo

Erros de dados, contato bloqueado, campanha pausada e intervenção humana continuam interrompendo a automação conforme o fluxo existente. A correção não altera a validação de CPF nem inicia empréstimos ou simulações.
