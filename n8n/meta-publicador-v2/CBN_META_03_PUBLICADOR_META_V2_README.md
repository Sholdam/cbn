# CBN META 03 — Publicador Meta — V2 Produção

## Entrega

O arquivo `CBN_META_03_PUBLICADOR_META_V2_PRODUCAO.json` evolui o publicador
Instagram + Facebook validado, preservando a arquitetura baseada em Google
Sheets, lock, log append-only, loop por canal e consolidação final.

O workflow possui 39 nós e é entregue com `active=false`. Ele contém:

- Manual Trigger para manutenção e teste controlado;
- Schedule Trigger a cada 1 minuto;
- timezone `America/Sao_Paulo`;
- leitura fail-closed da aba `Automação Meta` antes de qualquer mutação ou
  chamada à Meta;
- seleção somente com aprovação humana, data/horário vencido e canal pendente;
- tentativas e backoff independentes por canal;
- publicação dos dois canais na mesma execução;
- preservação de canal, ID e URL já publicados;
- consulta simples do permalink do Instagram após publicação;
- retry técnico HTTP com `maxTries=2` e retry funcional com até três tentativas.

## Ordem segura para adoção

1. Revise este diretório e o relatório de validação.
2. Aplique manualmente a migração descrita em
   `CBN_META_V2_MIGRACAO_PLANILHA.md`.
3. Preencha `Automação Meta` com `PAUSA_GERAL=SIM` e as demais configurações.
4. Importe o JSON no n8n sem ativá-lo.
5. Confirme as referências de credenciais Google Sheets e HTTP Header Auth.
6. Confirme que os tokens existem somente em Credentials do n8n.
7. Faça um teste sintético manual mantendo um único post controlado.
8. Comprove log, lock, IDs, URLs, idempotência e retry.
9. A ativação e a troca de `PAUSA_GERAL` para `NAO` exigem autorização separada.

## Estados

O estado geral usa `APROVADO_PUBLICAR`, `PUBLICANDO`, `PARCIAL`, `PUBLICADO` e
`ERRO`. Os estados de canal usam `PENDENTE`, `PUBLICANDO`, `PUBLICADO` e `ERRO`.

Um lock ou último log `RESERVADO`/`PUBLICANDO` é ambíguo e bloqueia replay
automático. A recuperação exige revisão humana, inclusive consulta direta aos
canais antes de qualquer nova tentativa.

## Limitações

- A validação desta entrega é offline; o JSON não foi importado no n8n real.
- A planilha real não foi modificada.
- O workflow não foi ativado e nenhuma chamada real à Meta foi feita.
- A URL HTTPS é validada sintaticamente. A disponibilidade pública continua
  sendo responsabilidade do operador antes da aprovação.
- O parser de horário espera o formato exibido `DD/MM/AAAA` e `HH:mm`.
- O permalink do Instagram é opcional: se a consulta adicional falhar após a
  publicação confirmada, o ID é preservado e nenhuma URL é inventada.

## Validação local

Execute:

```powershell
node n8n/meta-publicador-v2/validate-meta-publicador-v2.mjs
```
