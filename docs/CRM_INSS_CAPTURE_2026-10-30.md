# Coleta INSS após CPF — 30/10/2026

Regra 5 enviava a pergunta de CPF para INSS, mas o complemento retornava antes de iniciar estado de coleta quando não havia CLT. A reconstrução de prompt também aceitava somente CLT. CPF válido recebido era ignorado. Espelhamento de etiquetas excluía INSS.

Corrigido início/reconstrução como kind `inss`, cópia da etiqueta ao contato e avanço de CPF validado para `dados_recebidos`, reutilizando regra nativa 10 e sua mensagem de encaminhamento. Matrícula/vínculo Colatina e coleta CLT preservados. Conflitos de CPF continuam exigindo revisão. Intervenção humana ou conversa encerrada impede mensagem atrasada.

Recuperadas individualmente conversas 531/532/533: resposta válida localizada, CPF salvo e etiqueta INSS no contato, estágio concluído. Todas já tinham intervenção humana e estavam resolvidas: nenhuma mensagem enviada e nenhum estado de conversa reaberto. Não houve replay geral do histórico.

Sintaxe Ruby conferida e worker existente reiniciado. A primeira tentativa via compose falhou por configuração de serviços incompatível; fonte foi revertida antes da correção e publicação pelo container existente. Não foram recriados serviços paralelos. Backup original em `/opt/cbn/builds/inss-cpf-20261030T124410Z`, hash publicado `f01353778cc79aa1d118271fde7d03c3b8ec13d7c6707eb3dc89b2671b0a2846`.

Novo envio de confirmação ainda não observado organicamente. Texto nativo: “Obrigado pelos dados! Já encaminhei seu atendimento para um atendente. Ele dará continuidade por aqui assim que estiver disponível.” Nenhum teste de envio criado.
