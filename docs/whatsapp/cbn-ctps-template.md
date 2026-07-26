# Modelo oficial de WhatsApp — leads da CTPS Digital

## Escopo

Esta entrega prepara o modelo `cbn_ctps_simulacao_v1`, sua arte e os scripts de
criação e acompanhamento. Ela não importa listas, não envia mensagens, não
altera o Chatwoot e não submete o modelo sem autorização expressa.

## Texto final

- Categoria: `MARKETING`
- Idioma: `pt_BR`
- Cabeçalho: `IMAGE`

```text
Olá, {{1}}! 👋

Você realizou recentemente uma simulação de Crédito do Trabalhador pela Carteira de Trabalho Digital.

A CBN Crédito pode ajudar a verificar as condições disponíveis e orientar os próximos passos.

Deseja continuar por aqui?
```

Exemplo: `{{1}} = Maria`

Rodapé:

```text
Atendimento sujeito à análise e às condições do produto.
```

Respostas rápidas:

1. `Quero continuar`
2. `Agora não`
3. `Não quero receber`

## Custo por envio

Este modelo é de **marketing**. Para um número destinatário do Brasil, a tarifa
de referência vigente em 26/07/2026 é **US$ 0,0625 por mensagem entregue**.
A Meta cobra quando a mensagem é entregue, não apenas tentada.

Usando a PTAX de venda de 24/07/2026, `US$ 1 = R$ 5,0666`:

| Mensagens entregues | Meta em USD | Estimativa em BRL |
|---:|---:|---:|
| 1 | US$ 0,0625 | R$ 0,32 |
| 100 | US$ 6,25 | R$ 31,67 |
| 1.000 | US$ 62,50 | R$ 316,66 |

As estimativas não incluem impostos, spread cambial ou eventual tarifa de
provedor. Como a CBN usa Cloud API diretamente, não foi incluído markup de BSP.
Confirme a [página oficial de preços da Meta](https://business.whatsapp.com/products/platform-pricing/)
e o câmbio antes de cada campanha.

Se o cliente iniciar uma conversa por anúncio Clique para WhatsApp, as mensagens
enviadas nos 3 dias seguintes podem ficar isentas conforme a regra de ponto de
entrada gratuito da Meta. Quando o cliente responde, abre-se também a janela de
atendimento de 24 horas; mensagens de serviço dentro dela são gratuitas nas
regras vigentes em 26/07/2026. A abordagem da lista CTPS, porém, é
business-initiated e deve ser orçada como marketing.

Estimativa reproduzível:

```powershell
Set-Location scripts
npm.cmd run whatsapp:estimate-ctps-cost -- --messages=1000 --usd-brl=5.0666
```

## Arte

- fonte editável: `assets/whatsapp/cbn-ctps-simulacao-header.svg`;
- arquivo final: `assets/whatsapp/cbn-ctps-simulacao-header.png`;
- dimensões: `800 × 418`;
- limite interno: menos de 300 KB.

A composição mantém margens seguras, usa apenas a marca CBN Crédito e não inclui
governo, CTPS Digital, banco, dinheiro, valores, taxas ou promessa de aprovação.

Renderização:

```powershell
Set-Location scripts
npm.cmd run whatsapp:render-ctps-header
```

## Variáveis

```text
META_GRAPH_API_VERSION=
META_APP_ID=
META_WABA_ID=
META_SYSTEM_USER_ACCESS_TOKEN=
META_TEMPLATE_NAME=cbn_ctps_simulacao_v1
META_TEMPLATE_LANGUAGE=pt_BR
```

Nunca grave valores reais no repositório ou no histórico do terminal.

## Dry-run

O comando padrão não chama a Meta:

```powershell
Set-Location scripts
npm.cmd run whatsapp:create-ctps-template
```

Ele valida arte e payload e informa `remoteCalls: 0`. O `header_handle` exibido é
sempre sanitizado.

## Submissão — gate humano obrigatório

Somente após nova autorização expressa e com as variáveis no processo local:

```powershell
Set-Location scripts
npm.cmd run whatsapp:create-ctps-template -- --submit
```

O fluxo consulta primeiro nome e idioma. Modelo `PENDING` ou `APPROVED` correto
gera no-op; `REJECTED` não é apagado; divergência exige novo nome versionado.
Somente quando não existe modelo ocorre upload resumível da imagem e
`POST /{WABA_ID}/message_templates`.

## Acompanhar aprovação

```powershell
Set-Location scripts
npm.cmd run whatsapp:check-ctps-template
```

O resultado informa nome, idioma, categoria, status, motivo de rejeição,
qualidade disponível e data da consulta, sem imprimir credenciais.

## Depois da aprovação

1. sincronizar modelos na caixa existente do Chatwoot;
2. confirmar `cbn_ctps_simulacao_v1`;
3. testar somente com um número autorizado;
4. validar imagem, texto e botões;
5. não criar disparo em lista sem os gates de consentimento e deduplicação.

## Gates futuros antes de qualquer envio

- telefone válido;
- origem e data da simulação;
- opt-in para WhatsApp, com data e fonte;
- ausência de `não contato` ou bloqueio anterior;
- deduplicação da campanha;
- idempotência e auditoria sem PII.

O botão `Não quero receber` deverá futuramente produzir bloqueio persistente e
label `nao_contatar`. Esse roteamento não faz parte desta entrega.
