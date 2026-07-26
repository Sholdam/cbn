# Relatório — modelo oficial CTPS para WhatsApp

Data: 26/07/2026

## Resultado

Foi preparada localmente a versão `cbn_ctps_simulacao_v1`, em `pt_BR` e
categoria `MARKETING`, com:

- cabeçalho `IMAGE`;
- arte editável SVG e PNG final de 800×418 e 108.410 bytes;
- corpo com variável de nome e exemplo sintético `Maria`;
- rodapé de análise e condições;
- respostas rápidas `Quero continuar`, `Agora não` e `Não quero receber`;
- cliente da Graph API sem credenciais incorporadas;
- upload resumível da imagem;
- consulta e comparação idempotentes antes da criação;
- consulta separada de status, rejeição e qualidade;
- dry-run sem chamadas remotas;
- estimador de custo por mensagens entregues.

## Custo

Para destinatários do Brasil, a referência vigente consultada em 26/07/2026 é:

- marketing: **US$ 0,0625 por mensagem entregue**;
- PTAX de venda de 24/07/2026: **R$ 5,0666 por US$ 1**;
- estimativa unitária: **R$ 0,32**;
- mil entregas: **US$ 62,50**, aproximadamente **R$ 316,66**.

Não estão incluídos impostos, spread cambial ou eventual markup de provedor. A
CBN usa Cloud API direta; por isso não foi presumida tarifa adicional de BSP.

## Evidências

- arte renderizada e inspecionada visualmente;
- 22/22 testes focados aprovados;
- 66/66 testes da suíte Node completa aprovados;
- dry-run retornou `remoteCalls: 0`;
- imagem abaixo de 300 KB;
- estimador reproduziu mil entregas por R$ 316,66 no câmbio de referência;
- nenhuma credencial foi usada;
- nenhuma chamada à Meta ocorreu;
- nenhuma mensagem, lista, Chatwoot, n8n ou caixa foi alterada.

## Gate seguinte

A submissão depende de autorização expressa separada. Antes de executar
`--submit`, revisar texto, arte, custo vigente, opt-in, origem dos leads,
deduplicação e bloqueios de não contato.
