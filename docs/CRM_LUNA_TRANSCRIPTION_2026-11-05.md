# Luna no editor e transcrição manual — 05/11/2026

## Entrega

- Conta CBN: preferência nativa `settings.captain_models.editor = gpt-6-luna`. Ferramentas de reescrita, correção e sugestão usam o roteamento nativo; `reasoning_effort: none` mantém o contrato do editor com ferramentas. Outros modelos e recursos pagos não foram alterados.
- Botão **Transcrever áudio** no componente nativo de áudio. Reutiliza a integração OpenAI habilitada, com `gpt-transcribe`; nenhum segredo foi copiado para código, cliente ou imagem.
- Acionamento manual, autenticação nativa e autorização de acesso à conversa. Não transcreve ao abrir a conversa. Usa apenas blob já armazenado, não URL fornecida pelo chamador.
- POST/GET `/api/v1/accounts/:account_id/cbn_audio_transcriptions/:attachment_id`. Fila existente `active_storage_analysis` no worker WAHA, Redis DB 1. Token e trava evitam concorrência e substituição por resultado antigo.
- Conversão local para WebM/Opus via FFmpeg; limite de 25 MB e tempo de conversão. API recebe `model`, `languages[]` e arquivo. Falhas expõem aviso seguro, sem resposta bruta do provedor.
- Texto salvo em `attachment.meta.transcribed_text`, apresentado pelo componente nativo, com notificação de atualização; não cria mensagem, envia WhatsApp ou reabre conversa.

## Validação

- 7 testes Ruby / 35 asserções e 4 testes Vue aprovados na imagem candidata; compilação concluída.
- Teste real sintético de texto com Luna aprovado. Após publicação, `Captain::RewriteService` executou correção de texto sintético com o modelo correto e credencial `hook`, sem conversa vinculada.
- Transcrição inicialmente recusada com 403/model_not_found. Depois da liberação informada pelo proprietário, catálogo HTTP 200 incluiu os dois IDs exatos e áudio sintético foi reconhecido (68 caracteres). Nenhum áudio de cliente foi enviado para teste.
- Navegador autenticado confirmou botão nas mensagens de áudio. Não foi acionado em gravação real apenas para testar.
- CRM e portal HTTP 200; rota privada 401 sem sessão. Web, worker e serviço WAHA em execução. Fontes de coleta, menu, reabertura e classificação preservadas.
- Validação completa de uma transcrição solicitada por operador em atendimento real ainda depende do primeiro uso; teste da API foi sintético.

## Publicação e retorno

- Web: `cbn/chatwoot:4.16.2-cbn-ai-20261105t180539z`.
- Worker: `cbn/chatwoot:4.16.2-cbn-ai-20261105t180539z-worker`, baseado no worker existente com FFmpeg e arquivos backend adicionais.
- Backup consistente: `/srv/cbn-production/crm-deploy-backups/cbn-ai-20261105T182255Z` (compose, dump e preferência anterior).
- Somente web e worker recriados; serviço de sessão WhatsApp preservado. Falha inicial de leitura SQL do campo de preferência abortou antes de modificar o compose; corrigido para ler `settings` antes da publicação bem-sucedida.
- Retorno: restaurar as duas imagens do compose salvo e somente a preferência `editor` anterior, preservando outras alterações posteriores. Não restaurar dump sobre dados novos como rotina.

## Fontes oficiais consultadas

- https://developers.openai.com/api/docs/models/gpt-6-luna
- https://developers.openai.com/api/docs/models/gpt-transcribe
- https://developers.openai.com/api/docs/guides/speech-to-text

## Fontes versionadas

`infra/cbn-ai/`: initializer, registro de modelos, serviço, job, controlador, componente, patches, Dockerfile e testes. Não contém chave, blob de cliente ou configuração de ambiente.
