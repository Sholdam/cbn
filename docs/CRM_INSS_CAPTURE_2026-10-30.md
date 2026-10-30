# Coleta INSS após CPF — 30/10/2026

## Correção complementar — anúncio sem etiqueta e retomada

Novo atendimento revelou uma lacuna: a regra 5 só contém envio de mensagem e não adiciona etiqueta. A primeira correção ainda dependia de `inss` previamente presente. O serviço web de retomada também excluía INSS e estava com o initializer anterior embutido na imagem.

Agora o tipo de coleta é identificado pelas palavras do cliente ou pelo envelope explícito do anúncio, além das etiquetas existentes. A classificação nativa cria a etiqueta na conversa e no contato, inicializa a coleta antes da resposta e reconstrói a pergunta existente quando necessário. A retomada aceita INSS, aproveita o CPF recebido depois da pergunta e usa a confirmação nativa sem repetir a solicitação. Cadastro conflitante, bloqueio, janela de validade, trava, UUID e cooldown preservados.

Publicado web derivado da imagem em uso, `cbn/chatwoot:4.16.2-cbn-inss-resume-20261030`, com initializer e serviço de retomada atualizados; compose persistido e somente web/worker recarregados. Backup `/opt/cbn/builds/inss-resume-20261030T182054Z`; initializer do worker SHA-256 `95d57a5cfb7ce300680c8248e42c7430058af20ab1e7db27789e09b5a3f4c4f3`. WAHA e portal não reiniciados.

Sete verificações de regressão com objetos sintéticos passaram, sem gravações ou envios: classificação sem etiqueta, anúncio, mensagem sem produto, precedência CLT e avanço de etapa para INSS/CLT. Verificador reproduzível em `infra/cbn-leads/inss_regression_check.rb` para Rails runner.

Atendimento indicado retomado operacionalmente pelo mesmo serviço do botão, somente depois de conferir que continuava aberto e sem intervenção humana: CPF salvo, etiqueta no contato/conversa, agente atribuído e exatamente uma confirmação nativa criada com remetente automático. Status observado `sent`; entrega ao dispositivo ainda não confirmada. CRM e site HTTP 200. Não houve reprocessamento das demais conversas nem envio de teste. Um novo ciclo completo iniciado organicamente após esta publicação ainda não foi observado.

## Primeira correção e recuperação histórica

Regra 5 enviava a pergunta de CPF para INSS, mas o complemento retornava antes de iniciar estado de coleta quando não havia CLT. A reconstrução de prompt também aceitava somente CLT. CPF válido recebido era ignorado. Espelhamento de etiquetas excluía INSS.

Corrigido início/reconstrução como kind `inss`, cópia da etiqueta ao contato e avanço de CPF validado para `dados_recebidos`, reutilizando regra nativa 10 e sua mensagem de encaminhamento. Matrícula/vínculo Colatina e coleta CLT preservados. Conflitos de CPF continuam exigindo revisão. Intervenção humana ou conversa encerrada impede mensagem atrasada.

Recuperadas individualmente conversas 531/532/533: resposta válida localizada, CPF salvo e etiqueta INSS no contato, estágio concluído. Todas já tinham intervenção humana e estavam resolvidas: nenhuma mensagem enviada e nenhum estado de conversa reaberto. Não houve replay geral do histórico.

Sintaxe Ruby conferida e worker existente reiniciado. A primeira tentativa via compose falhou por configuração de serviços incompatível; fonte foi revertida antes da correção e publicação pelo container existente. Não foram recriados serviços paralelos. Backup original em `/opt/cbn/builds/inss-cpf-20261030T124410Z`, hash publicado `f01353778cc79aa1d118271fde7d03c3b8ec13d7c6707eb3dc89b2671b0a2846`.

Novo envio de confirmação ainda não observado organicamente. Texto nativo: “Obrigado pelos dados! Já encaminhei seu atendimento para um atendente. Ele dará continuidade por aqui assim que estiver disponível.” Nenhum teste de envio criado.
