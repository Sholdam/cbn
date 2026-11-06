# Recuperação do player de áudio — 06/11/2026

## Problema e diagnóstico

O proprietário relatou player preso em `00:00 / 00:00`, com ícone de pausa, que voltava após F5. O arquivo da mensagem indicada existe; uma nova abertura da conversa carregou metadados e duração normalmente. A falha original de rede não foi capturada, portanto não há evidência para atribuir a origem a um código HTTP ou ao WhatsApp.

O componente publicado chamava `play()` sem aguardar/tratar sua Promise e marcava reprodução imediatamente. Usava `<source>` reativo sem chamar `load()` após atualizar o endereço. Também não tratava erro, espera prolongada, duração tardia nem cancelamento de reprodução pendente.

## Correção

- Fonte vinculada diretamente ao `<audio>`, com observação do endereço do anexo e recarga do elemento após a atualização de DOM. Atualizar a mesma referência não reinicia o áudio.
- `preload=metadata`; metadados válidos de um arquivo pausado não provocam recargas desnecessárias.
- Reprodução confirmada pela Promise/evento do navegador; carregamento tem estado próprio. Falhas são tratadas e não geram rejeição solta.
- Três retentativas limitadas (1s, 3s, 8s), endereço com cache renovado, watchdog de 10s para carregamento/espera parados e botão explícito **Tentar novamente** ao esgotar.
- Sem reprodução automática na montagem ou chegada do anexo. Retentativa só tenta reproduzir quando o operador havia solicitado; pausa/troca de áudio/troca de anexo/desmontagem cancelam essa intenção e os timers.
- Duração tardia/WebM, posição, velocidade e mudo preservados quando cabível. O mecanismo modifica somente o player, sem recarregar página, reenviar mensagem ou chamar transcrição.
- Botão de transcrição existente preservado; nenhuma transcrição real ou mensagem de teste enviada nesta tarefa.

Fontes: `infra/cbn-audio/Audio.vue`, `useCbnAudioPlayback.js`, `Audio.spec.js`, `Dockerfile`. A imagem deriva da web efetivamente publicada, preservando as fontes de tempo real e os complementos de backend montados.

Comportamento da plataforma conferido na documentação primária: [load()](https://developer.mozilla.org/en-US/docs/Web/API/HTMLMediaElement/load) e [play()](https://developer.mozilla.org/en-US/docs/Web/API/HTMLMediaElement/play).

## Validação e publicação

- **38 testes aprovados em quatro arquivos**: 16 do player (incluindo componente real), nove de sincronização de mensagens, nove de recuperação em tempo real e quatro da transcrição manual.
- Testes cobrem rejeição de `play()`, erro duplicado, três tentativas/limite, timeout silencioso, fonte tardia/atualizada, mídia pausada com somente metadados, duração posterior/WebM, bloqueio de reprodução pelo navegador, cancelamento/desmontagem, promessa antiga, retomada de posição e preservação da transcrição.
- Compilação Vite concluída e imagem `cbn/chatwoot:4.16.2-cbn-audio-player-20261106t185906z` publicada somente no web. CRM/site HTTP 200, API privada 401 sem sessão e upgrade WebSocket 101.
- Fontes publicadas conferem com o artefato testado; backend do bot/reabertura/classificação preservado. WhatsApp `WORKING`, fila crítica zero e nenhum retry na conferência final.
- Navegador autenticado carregou o novo player. Teste temporário bloqueou somente o caminho do áudio: quatro requisições de mídia registradas como bloqueadas pelo inspector. Após remover o bloqueio, duração `5.668563`, `readyState=4`, sem erro, player pausado e **zero navegações durante a recuperação**. Não foi preciso F5 para recuperar. Transcrição continuou disponível.
- Bloqueio/cache de teste removidos e aba temporária fechada. Nenhuma mensagem enviada nem áudio real transcrito. Captura de imagem pelo navegador indisponível; conferência registrada por DOM do player e eventos de rede, sem salvar URLs assinadas ou conteúdo dos clientes.
- Backup `/srv/cbn-production/crm-deploy-backups/audio-player-20261106T190410Z`; compilação/testes/publicação e verificação operacional em `/opt/cbn/builds/audio-player-20261106T185906Z`.
- Abas já abertas precisam carregar a versão nova uma vez. O erro de rede que provocou o print original permanece sem código HTTP comprovado; as falhas de reprodução/carregamento identificadas no componente estão cobertas pela correção e pelo teste de falha real no navegador.

## Retorno

Restaurar somente a referência da imagem web no compose salvo e recriar `chatwoot-web`, mantendo banco, mensagens posteriores, workers, volumes e sessão WhatsApp.
