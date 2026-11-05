# Atualização de mensagens sem F5 — 05/11/2026

## Evidência e diagnóstico

- Navegador autenticado tinha aviso de desconexão mesmo recebendo pings, presença e eventos `message.created`/`message.updated`. Isso separa o estado visual de conexão da entrega pelo servidor naquela observação.
- Uma interrupção simples em aba de teste recuperou na versão anterior: o sintoma é intermitente, não uma queda permanente de todos os WebSockets.
- Caminho nativo de reconexão executava lista, mensagens e caches em sequência, sem retentativa de sincronização. Falha em uma etapa podia impedir as seguintes e a confirmação visual. Não havia conferência periódica da conversa ativa nem retomada ao voltar à aba para cobrir um evento de desconexão perdido.
- Conector anterior não era guardado/descartado na reinicialização da conta; seus timers de presença/reconexão também não eram limpos no descarte. Corrigido sem alterar autenticação ou destinos de conexão.

## Implementação

- `CbnRealtimeRecovery`: mantém WebSocket como transporte imediato; recupera pela API nativa ao reconectar, voltar à aba, retornar online ou restaurar a página.
- Conferência das mensagens da conversa visível a cada 15 segundos e da lista a cada 60 segundos, como contingência. Sem consultas periódicas em aba oculta/offline; ao retornar, busca imediatamente. Não recarrega o documento.
- Consultas independentes: falha da lista não impede buscar mensagens, e caches opcionais não bloqueiam a conclusão. Falha de sincronização mantém marcador e agenda nova tentativa limitada, sem requisições concorrentes duplicadas.
- Filtros de usuário preservados e filtro temporário de reconexão removido em `finally`. Tempo da primeira desconexão mantido até recuperar.
- `CbnMessageSync`: usa cursor de mensagem, revisa as recentes, recupera páginas adicionais com limite por execução, elimina duplicação e mescla contra o cache atual depois da resposta, preservando eventos recebidos durante a requisição e mensagens locais pendentes.
- Respostas de uma conta anterior são descartadas. Leitura de mensagens recuperadas só é registrada para novas recebidas na conversa ativa e visível.
- Aplicação descarta serviço/conector anterior e seus timers ao mudar de conta ou desmontar, sem alterar o rascunho do editor. Nenhuma mensagem é enviada pelo mecanismo de recuperação.

## Verificação

- **58 testes em cinco arquivos aprovados**: conector/dashboard e widget existentes, recuperação, mesclagem de mensagens, leitura da conversa ativa, isolamento de conta, retentativa, descarte de listeners e preservação de pendências locais. Compilação Vite concluída.
- Publicada imagem web `cbn/chatwoot:4.16.2-cbn-realtime-20261105t232330z`; CRM/site HTTP 200, API privada 401 sem sessão e upgrade WebSocket 101. Fontes do bot, reabertura e classificação conferidas sem alteração.
- Backup consistente `/srv/cbn-production/crm-deploy-backups/realtime-20261105T232625Z`; logs/testes/manifesto em `/opt/cbn/builds/realtime-20261105T232330Z`. Retorno: restaurar somente imagem web do compose salvo e recriar esse serviço, preservando dados posteriores.
- Observação via DevTools limitada a tipos de eventos, URLs de recursos e resultado de conexão, sem registrar tokens, textos de clientes ou cabeçalhos de autenticação.
- Navegador carregou o bundle novo `dashboard-1OBjsKF2.js`. Interrupção/restauração de rede em aba de teste: assinatura confirmada, pings/presença retomados, chamadas de recuperação observadas para lista e mensagens, aviso de desconexão removido, **zero navegações/recarregamentos durante a recuperação** e rascunho sintético preservado.
- Rascunho de teste apagado pelo editor e remoção confirmada após abrir novamente; abas temporárias fechadas. Nenhuma mensagem de teste foi enviada. Aba original, cujo editor estava vazio, carregada na versão nova.
- Conferência operacional após publicação: WhatsApp `WORKING`, fila crítica vazia, sem retries ou erros novos na coleta, e outro CPF real recebido continuou automaticamente para a confirmação do bot. Não houve reprocessamento adicional de atendimentos nesta etapa.

## Operação

- Publicação substitui somente a imagem web; workers, sessão WhatsApp, regras do bot, classificações, credenciais e dados permanecem nas configurações em uso.
- Abas que já estavam abertas precisam carregar a versão nova uma vez. Não é emitido comando global para recarregar abas e perder rascunhos.
- O mecanismo depende de acesso ao servidor e sessão válida; não promete entrega instantânea durante ausência de rede. O intervalo de contingência não substitui o WebSocket.
