# Indisponibilidade do CRM e site — 23/10/2026

## Resultado

Proprietário relatou queda simultânea; durante a investigação informou retorno espontâneo. Confirmados site e CRM HTTP 200 por acesso público local e pelo próprio VPS, às aproximadamente 16h15 de Brasília. Sessão WhatsApp `WORKING`; todos os serviços de produção ativos, PostgreSQL e Redis WAHA saudáveis.

Nenhum serviço foi reiniciado ou alterado nesta investigação. Não houve envio de mensagens, restauração de banco, replay ou mudança nas automações.

## Evidências e limites

- Os dois domínios resolveram para o IP correto. As primeiras tentativas HTTPS e SSH expiraram; uma consulta externa também não conseguiu acessar os endereços. Depois ambos HTTPS e SSH voltaram.
- O boot anterior terminou seus registros às `2026-10-23T18:30:05Z` e o boot atual começou às `18:47:51Z` (**15h47 de Brasília**). Todos os containers de produção tinham cerca de 27 minutos de execução na consulta das 16h15.
- Não há evento de desligamento normal, OOM ou kernel panic nos registros consultados do boot anterior. Isso não determina a origem do reinício; não atribuir à Hostinger, a ação humana ou à aplicação sem evidência adicional.
- RAM atual: aproximadamente 2,4 GiB utilizados de 7,75 GiB, cerca de 5,3 GiB disponíveis. Disco: 22 GiB utilizados, 23%, 75 GiB disponíveis. Esses valores são posteriores ao retorno e não provam consumo anterior à queda.
- O conector Hostinger não concluiu a consulta de estado/ações nesta sessão; a consulta apenas de leitura foi encerrada. A causa exata do reinício e da indisponibilidade externa permanece não confirmada.
- A lacuna entre registros e boot não deve ser apresentada como duração exata da indisponibilidade. A correlação entre o reinício e a queda relatada não comprova uma causa única.

Inspeções por SSH limitado aos estados dos containers, disponibilidade HTTP, DNS, memória/disco, journals de boot/rede e status da sessão WAHA. Próxima evidência útil, se houver recorrência: histórico de ações/manutenção no painel do provedor, cruzado com os horários UTC acima. Nenhuma alteração preventiva especulativa aplicada.
