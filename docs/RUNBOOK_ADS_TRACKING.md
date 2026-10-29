# Rastreamento de anúncios no CRM CBN

## Escopo autorizado em 29/10/2026

O usuário autorizou implementar a organização automática de leads de anúncios
no CRM ativo e na hospedagem. Esta autorização vale para esta integração; não
altera os gates gerais das BKL-016/018/020. As mensagens aos clientes, regras de
triagem, anúncios e orçamento não são modificados por este módulo.

O painel fica em `https://cbncredito.tech/area/crm/anuncios/`, dentro da área do
colaborador. O menu CRM expande Super Admin, Atendimento e Anúncios. As duas
primeiras opções mantêm os acessos externos; Anúncios é uma página nativa,
sem iframe, e usa a sessão e o CSRF do portal. Os dados de anúncios exigem o
perfil proprietário com módulo CRM. O login do Chatwoot não é reutilizado.
Nenhum CPF, telefone, nome de cliente ou conteúdo de mensagem é enviado ao
navegador pelo painel. O endereço inicial no host CRM apenas redireciona ao
portal; deixou de servir página e API de relatório.

## Fluxo e interpretação

- A cada cinco minutos, o serviço lê novos registros de entrada da caixa WAHA
  (conta 1, caixa 5). A extração ocorre no PostgreSQL: somente IDs e horários
  saem da consulta. O ID precisa estar no cabeçalho de anúncio do Facebook,
  antes da seção de mensagem do cliente. Outros canais não são cobertos.
- Uma combinação conversa/anúncio ocupa um registro, mesmo com mensagens
  repetidas. Contatos são distintos por anúncio; somar anúncios pode contar a
  mesma pessoa mais de uma vez. Primeiro e último anúncios são preservados.
- O catálogo identifica campanha, conjunto, anúncio e modalidade. IDs novos
  sem catálogo continuam capturados e aparecem como não identificados; a
  importação de métricas completa os nomes. A modalidade deve ser cadastrada
  no catálogo privado quando surgir um conjunto novo.
- Os campos `cbn_ads_*` na conversa recebem a origem. O preenchimento usa
  atualização incremental do JSON, preservando os demais campos. A atualização
  não emite mensagens, callbacks de conversa ou mudanças de estado; pode ser
  necessário atualizar a tela do CRM para enxergar os campos.
- A equipe informa **Ads · Etapa comercial**, **Ads · Crédito contratado (R$)**
  e **Ads · Comissão CBN (R$)**. Valores monetários são números não negativos,
  em reais. Não estimar vendas ou comissões a partir de resolução da conversa.
- A atribuição de venda é fixada no último anúncio observado quando a etapa
  passa a Contratado. Uma mensagem de anúncio posterior não desloca a venda
  enquanto a etapa permanecer Contratado. A leitura é periódica, portanto uma
  mudança de etapa feita entre duas capturas não constitui um histórico de
  transições. A venda deve permanecer corretamente registrada até a captura.
- O filtro de datas define a entrada da conversa por anúncio, no calendário
  UTC−3. Propostas e contratos são o estado atual dessa coorte, não contratos
  fechados naquela data nem a atribuição oficial da Meta.
- Cliques são **cliques totais**, não necessariamente cliques para WhatsApp.
  Sem linha importada, gasto e cliques são N/D. Comissões incompletas não viram
  lucro zero ou estimado. Comissão menos mídia não desconta outros custos.

## Instalação e segurança

Fonte: `scripts/ads-tracking/`, somente biblioteca padrão do Python. Os testes
usam registros sintéticos. O catálogo real `catalog.json` e qualquer semente
`initial-metrics.json` são arquivos privados, ignorados pelo Git. Criar o
catálogo a partir de `catalog.example.json` e dos metadados autorizados.

Antes da primeira instalação, inspecionar portas, Caddy, campos e serviços.
Enviar os arquivos para `/opt/cbn/ads-tracking`, incluindo o catálogo privado;
a importação inicial opcional segue `{period:{from,to},data:[...]}` com os
campos validados na função `import_metrics`. Nunca incluir esses dados no Git.
Executar `python3 deploy.py` com a autorização de produção já registrada.
`--resume` serve apenas para retomar uma instalação interrompida; não é um
atualizador genérico de instalações existentes. A interface e o proxy com
controle de proprietário ficam no projeto existente `cbn-colaborador`, em
`lib/ads.mjs`, `public/ads.js` e nas rotas `ads/*` do servidor do portal.

O instalador cria nove definições de atributos de conversa, sem substituir
definições existentes; mantém cópia do Caddy e somente dos atributos do
namespace de tracking em `installation-backup`, diretório privado. O banco
SQLite agregado fica em `/srv/cbn-production/ads-tracking`. O processo web usa
o usuário sem login `cbn-ads`, não tem acesso ao Docker e só pode escrever no
subdiretório de credenciais. Os diretórios pais privados do servidor mantêm
suas permissões: os caminhos necessários são montados apenas no namespace
do serviço com systemd, em `/run/cbn-ads-report`.

O coletor usa o acesso de manutenção local já existente ao PostgreSQL; não há
porta nova de banco, credencial de banco no cliente ou privilégio adicional
para pessoas do CRM. A consulta e projeção são fixas na conta/caixa autorizadas.
O relatório lê o SQLite em modo somente leitura e em transação consistente.

O serviço de relatório não escuta em TCP. Ele usa somente
`/run/cbn-ads-report/report.sock` (0660), em diretório 0750 preservado entre
reinícios. O container do portal monta esse diretório somente para leitura e
recebe o grupo complementar `cbn-ads`; não monta o banco, as credenciais ou o
Docker. O portal verifica proprietário e módulo CRM antes de encaminhar apenas
as duas rotas internas fixas: relatório e configuração. Cookies, CSRF e tokens
de sessão não são encaminhados. O serviço exige a origem fixa do portal no
POST; o portal valida também seu próprio CSRF. Há CSP e no-store nas respostas,
sem CORS aberto. O CRM e o WAHA não são reiniciados. A transferência exigiu
reconstruir somente o portal, preservando volume, contas e sessões existentes.

## Métricas e credencial Windsor

A conexão OAuth do plugin no Codex permite consultas nesta conversa, mas não
transfere uma credencial reutilizável ao servidor. Para atualização independente,
o administrador salva sua chave de API no próprio painel. Ela fica em arquivo
0600 dentro de diretório 0700, não é retornada pela API e não deve ser enviada
no chat. Não são usados tokens de sessão do navegador ou do plugin.

O job consulta a conta Emergencia configurada no código, em HTTPS, no endpoint
oficial `connectors.windsor.ai/facebook`, com intervalo móvel de 30 dias. A
frequência normal é diária; falhas têm intervalo mínimo de uma hora. A rotina
de cinco minutos dispara a primeira consulta após salvar uma chave nova.
A disponibilidade e atualidade upstream dependem da conexão e do plano Windsor;
o módulo não compra plano ou solicita atualização paga. A captura do CRM
continua funcionando quando o Windsor falha. A conta antiga tem apenas a
importação inicial; reconectá-la e ampliar explicitamente a seleção para
atualizá-la continuamente, se necessário.

Cada linha de métricas é identificada por conta/anúncio/data e atualizada por
upsert, sem somar a mesma exportação duas vezes. Linhas ausentes não são
interpretadas como gasto zero. A interface mostra cobertura e data de cada
importação e o estado separado da sincronização.

Documentação primária: [API Windsor](https://windsor.ai/api-documentation/),
[campos Facebook](https://windsor.ai/data-field/facebook).

## Validação, manutenção e reversão

Testes do coletor/API: `python -m unittest discover -s scripts/ads-tracking -p test_tracking.py -v`.
No projeto do portal: `npm test`, incluindo proxy Unix, restrição a proprietário,
CSRF, rota nativa e rejeição de acessos anônimos.

Verificar `systemctl status cbn-ads-report.service cbn-ads-capture.timer` e
`systemctl list-timers cbn-ads-capture.timer`. `cbn-ads-capture.service` é um job
oneshot; estado inativo após sucesso é normal. Para validar imediatamente uma
chave recém-salva, executar `systemctl start cbn-ads-capture.service`. Inspecionar
apenas `metrics-status.json` e contadores; nunca imprimir o arquivo de chave.

Uma atualização de código deve preservar o catálogo, SQLite, credencial e
backup. Rodar os testes, copiar somente os arquivos alterados e reiniciar
apenas `cbn-ads-report.service` se o código web mudou. O coletor carrega a
próxima versão no disparo seguinte. Não executar o instalador novamente após
a rota estar ativa. Não apagar o cursor para atualizar nomes.

Para suspender, desabilitar o timer e parar o serviço de relatório. A API do
portal passa a informar indisponibilidade. Para reverter o frontend, há backup
privado do código, compose, imagem anterior e SQLite consistente do portal em
`portal-transfer-backup`. Preservar o banco e os campos comerciais preenchidos
pela equipe. Não restaurar o JSON inteiro de uma conversa nem apagar definições
de campos sem revisar dados posteriores. Não substituir um Caddyfile atual por
backup antigo sem preservar as alterações de outros serviços.

Evidência da instalação: testes sintéticos passaram localmente e no VPS;
backfill de metadados, autenticação administrativa, rejeição de acesso anônimo,
campos nativos e timer foram verificados. A primeira sincronização diária com
a chave cadastrada pelo usuário foi concluída. A transferência foi verificada
no navegador interno, com o menu expandido e o dashboard nativo carregado.
O catálogo inclui os nove anúncios INSS definidos pelo usuário. Nenhum envio
a cliente foi executado.
