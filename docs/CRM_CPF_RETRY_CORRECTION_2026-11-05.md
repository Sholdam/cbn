# CPF inválido, retomada repetida e correção do cliente — 05/11/2026

## Causa confirmada

- Na conversa indicada, o primeiro número recebido era inválido pelo dígito verificador. A captura o ignorava sem orientar o cliente. Esse mesmo valor já estava salvo no campo do contato.
- A segunda saudação veio de uma retomada manual registrada pelo serviço do bot; como o CPF salvo era inválido, a retomada reenviava a apresentação inicial.
- O cliente depois enviou outro número, válido, com um dígito diferente. Como o cadastro continha o anterior, o fluxo entrava em `revisao_cpf`. Não havia outro contato com o número corrigido. Valores reais não foram registrados neste documento ou nos testes.

## Correção publicada

- Tentativa numérica de CPF inválido recebe aviso específico, editável na regra nativa **CBN — CPF: conferir número inválido** (ID 16), sem nova saudação: “O CPF informado não passou na validação. Confira se os números estão corretos e envie novamente os 11 dígitos, por favor.”
- Aviso idempotente por mensagem, mantendo a coleta aguardando CPF e respeitando bloqueio, pausa, janela e intervenção humana. Retomada manual usa esse aviso se há tentativa inválida pendente.
- Resposta válida pode corrigir valor salvo inválido somente quando há mensagem anterior do mesmo contato, na mesma coleta, comprovando o número inválido. CPF já válido, conflito com outro contato, cadastro sem essa comprovação ou atendimento assumido pelo humano continuam protegidos.
- Nenhum número adicional é persistido no estado do fluxo. Pontos de auditoria usam IDs de mensagens.

## Recuperação do atendimento indicado

- Durante o trabalho, o operador assumiu a conversa. A tentativa de retomada respeitou esse bloqueio e não enviou mensagem.
- Feita correção pontual revisada somente do campo CPF, usando a resposta válida e a comprovação da tentativa anterior; coleta marcada concluída. Responsável e conversa aberta preservados. Não foi enviada nova pergunta ou confirmação pelo bot.
- Releitura confirmou cadastro válido correspondente à resposta corrigida e último envio de autoria do operador; WhatsApp `WORKING`, fila crítica vazia e sem retries.

## Validação e operação

- Falha reproduzida com a versão anterior. **9 testes Ruby / 19 asserções**, mais sete verificações anteriores INSS/CLT, aprovados antes e após a publicação, somente com objetos sintéticos e sem envios de teste.
- Fontes publicadas por mounts persistentes no web e no worker; serviço de retomada montado somente no web. Imagem de atualização em tempo real preservada.
- Regra/configuração/fonte originais e dump consistente em `/srv/cbn-production/crm-deploy-backups/cpf-retry-20261105T234619Z`.
- Evidências: `/opt/cbn/builds/cpf-retry-20261105T234433Z`, com testes, publicação, tentativa de retomada bloqueada, reparação de cadastro e verificação final.
- Retorno: restaurar somente compose, arquivos e configuração desta alteração; se necessário, pausar a regra 16. Não restaurar dump sobre dados posteriores nem desfazer a correção válida do cadastro como parte do rollback de código.
- Aviso novo ainda não observado em tentativa inválida orgânica posterior; seus guardas, remetente e idempotência foram testados com objetos sintéticos. O caso atual já estava em atendimento humano.
