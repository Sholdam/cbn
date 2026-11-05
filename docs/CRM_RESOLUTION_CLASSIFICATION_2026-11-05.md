# Classificar antes de resolver — 05/11/2026

## Pedido e fluxo

O proprietário autorizou exigir uma situação válida antes de resolver, independentemente de humano, bot ou integração. Refinou o fluxo para dois cliques: **Resolver → escolher situação**. A escolha salva o campo do contato e resolve a conversa em uma transação.

- Ao clicar Resolver ou usar o atalho, abre a lista de situações em botões. Mesmo com um valor anterior, exige confirmação explícita da escolha humana. Não há um terceiro botão Confirmar.
- Cancelar não grava classificação nem resolve. Falha mantém a seleção aberta, com mensagem de erro.
- Duplo clique não envia duas solicitações. Se houver nova mensagem pública desde a abertura, a seleção é atualizada e a conversa não é encerrada por uma decisão desatualizada.
- Reabrir, Secretária e adiar conservam seus fluxos nativos. O atalho para resolver e ir à próxima conversa espera a resolução e não navega após cancelamento.

## Regra obrigatória

`cbn_situacao_atendimento` deve ser uma string exatamente igual a uma opção cadastrada na definição de atributo do contato da conta CBN. Valores vazios, booleanos, listas, texto arbitrário e opções removidas são rejeitados.

As opções conhecidas são Novo contato, Em negociação, Aguardando cliente, Follow-up, Venda fechada, Sem interesse e **Sem oferta** (acrescentada por pedido explícito do proprietário). Exigir uma opção válida não determina automaticamente se o conteúdo escolhido representa o atendimento: essa decisão continua com o atendente ou bot responsável.

Implementação:

- Validação nativa em Conversation, com erro legível antes de gravar a transição para resolved.
- Trigger PostgreSQL na transição para resolved e na criação já resolvida. Também cobre operações em lote e escritores que pulam validações Rails. Não depende de automação na fila para reabrir posteriormente.
- Só conta CBN 1; outras contas não são afetadas. Conversas antigas já resolvidas podem receber atualizações normais, sem exigir reclassificação retroativa.
- Snapshot da escolha em `additional_attributes.cbn_resolution`, preservando os demais atributos. Não há mensagem adicional ao cliente.

## Seleção e autorização

GET/POST `/api/v1/accounts/:account_id/conversations/:conversation_id/resolution_classification`, com autenticação, conta atual e autorização nativa da conversa por display_id. Nenhuma chave ou permissão nova.

POST exige `classification` válida e `last_message_id` da consulta anterior. Trava conversa e contato; salva situação e resolução na mesma transação. Atualização concorrente de mensagem retorna 409. Repetição idêntica de uma resolução confirmada é idempotente; alterar a escolha de uma já encerrada pede reabertura.

Bots e integrações que usam a rota nativa de status devem salvar uma situação válida no contato antes de resolver. Sem ela, a conversa permanece não resolvida. A regra não escolhe automaticamente um resultado fictício para satisfazer a obrigatoriedade.

## Conexão com anúncios

A cobertura de anúncios não usa diretamente o campo do contato: lê `cbn_ads_etapa` na conversa. No encerramento, a escolha também fornece a etapa correspondente:

| Situação do atendimento | Etapa dos anúncios |
|---|---|
| Novo contato | Novo contato |
| Em negociação | Em atendimento |
| Aguardando cliente | Em atendimento |
| Follow-up | Em atendimento |
| Venda fechada | Contratado |
| Sem interesse | Perdido |
| Sem oferta | Perdido |

Proposta enviada já explicitamente registrada é preservada nas três opções genéricas de atendimento. Não são inventados valores de crédito ou comissão. Produção nativa mantém sua atribuição e deduplicação por proposta. O capturador existente reflete a classificação na consulta seguinte; não foi criado replay histórico.

As conversas antigas sem situação permanecem para revisão humana. Não se inferiu resultado pela falta de resposta, por etiqueta de produto, pelo fechamento anterior nem pelo estágio de um outro cliente.

## Verificações

- 19 verificações SQL iniciais, ampliadas para 20 ao incluir Sem oferta, com tabelas temporárias e rollback: tipos inválidos, opções válidas, transição, inserção, atualização em lote sem persistência parcial, reabertura, legado, outras contas e preservação de proposta enviada.
- 10 testes Ruby finais, 48 asserções: callback, rotas e herança de autorização; modelo com dados sintéticos; controlador com doubles para gravação, entrada inválida, mensagem nova e repetição idempotente, além do caso específico Sem oferta. Não são testes HTTP autenticados completos nem gravações de clientes reais.
- 5 testes Vue: abertura sem gravação, escolha, duplo clique, cancelamento, erro de nova mensagem e configuração vazia.
- Compilação Vite e sintaxe Ruby aprovadas. Testes não criaram mensagens nem registros de atendimento reais.

## Implantação e retorno

Imagem candidata `cbn/chatwoot:4.16.2-cbn-resolution-20261105t172321z`. Validação nos quatro processos Rails via initializer persistente; web recebe o novo componente. PostgreSQL, Redis, WAHA e sessão de WhatsApp não são reiniciados.

Primeira tentativa retornou à imagem anterior ao exceder um limite de inicialização de 30 segundos. O serviço anterior retornou HTTP 200; o limite de saúde foi ajustado antes de repetir. Publicação principal confirmada, com backup consistente em `/srv/cbn-production/crm-deploy-backups/resolution-20261105T172750Z`, CRM e portal HTTP 200, rota nova HTTP 401 sem sessão e trigger ativo.

Conferência autenticada no navegador mostrou as sete opções, incluindo Sem oferta, abriu sem gravar e cancelou conservando o botão Resolver. Captura local em `outputs/crm-classificacao-resolver-2026-11-05.png` (fora do Git). A escolha final não foi acionada num cliente real apenas para testar. A implantação não fechou nem reclassificou conversas em massa.

Revisão final publicada na imagem `cbn/chatwoot:4.16.2-cbn-resolution-20261105t172321z-no-offer`, backup adicional `/srv/cbn-production/crm-deploy-backups/resolution-no-offer-20261105T173256Z`. Inclui a opção na definição nativa do contato, no modelo obrigatório e na validação PostgreSQL, sem reconstruir ou alterar o frontend para cada nova opção deste ajuste.

Retorno: remover somente os dois volumes de `cbn-resolution` nos quatro serviços, voltar a imagem web anterior e aplicar `infra/cbn-resolution/rollback.sql`. Recriar apenas os processos Rails com `--no-deps`. Não restaurar o banco inteiro sobre o uso novo e não desfazer classificações legítimas já registradas.

Permanecem preservados os complementos/fontes de coleta, menu, reabertura, configuração dos bots e dados financeiros. Não há reclassificação histórica em massa.
