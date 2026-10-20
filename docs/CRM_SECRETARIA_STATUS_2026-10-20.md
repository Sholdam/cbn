# Encerramento das pendentes e nome Secretária

## Autorização e execução

Em 20/10/2026 o proprietário pediu encerrar todas as conversas pendentes e,
em seguida, trocar o nome Pendente por Secretária.

O plugin CBN CRM listou todas as páginas com `status=pending` e
`assignee_type=all`, abrangendo as caixas disponíveis na conta CBN. Foram
27 conversas, incluindo caixa antiga. Antes de cada alteração, a conversa foi
consultada novamente; cada ação usou UUID estável, preparação e execução com
referência ao pedido real. Operações concluídas não são repetidas.

Resultado: 27 ações concluídas para `resolved`; nova consulta retornou zero
pendentes em todas as categorias. Não foram criadas respostas ou campanhas.
Manifesto operacional local contém somente IDs e estado das operações.

## Nome da fila

Patch `infra/cbn-secretaria-status/` altera somente traduções de estado de
conversa em português brasileiro:

- filtro da lista: **Secretária**;
- ação no cabeçalho e menu da conversa: **Enviar para Secretária**;
- ação de automação: **Enviar conversa para Secretária**;
- indicador de conversas pendentes no relatório: **Secretária**.

O código interno continua `pending`, preservando integração, API, regras e
comportamento de roteamento. Pendência financeira Shopify, revisão de conta e
ordenação por tempo de resposta não são estados desta fila e permanecem intactos.
A renomeação não liga agente, webhook ou atendimento automático da Secretaria.

## Publicação

Imagem: `cbn/chatwoot:4.16.2-cbn-secretaria-label-20261020`, derivada da versão
com correção de cópia da data de nascimento. Publicação somente no serviço web;
sem reiniciar WAHA/worker ou alterar dados de contatos.

Backup e manifesto em `/opt/cbn/builds/secretaria-label-20261020/`.
Rollback visual: restaurar somente a imagem web anterior
`cbn/chatwoot:4.16.2-cbn-date-copy-20261020`, preservando mudanças concorrentes.
O rollback visual não deve reabrir as conversas encerradas a pedido do usuário.

Build Vite concluído e imagem publicada somente no web. Backup da publicação:
`/opt/cbn/builds/secretaria-label-20261020/before-20261020T161450Z/`.
`git diff --check` sem problemas. Não foram adicionados/executados testes
automatizados nem enviados testes aos clientes. Abas abertas precisam recarregar
para receber a tradução nova; preservar rascunhos antes de recarregar.
