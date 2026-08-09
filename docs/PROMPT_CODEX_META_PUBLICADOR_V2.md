# Prompt Codex — Meta Publicador V2

## Objetivo

Evoluir o publicador Meta V1.4 validado para um workflow V2 agendado, inativo na
entrega, com aprovação humana, pausa fail-closed na planilha, idempotência e
retry por canal para Instagram e Facebook.

## Esforço

Ultra (9/10): integração externa com efeito irreversível, idempotência,
credenciais, máquina de estados, retry e migração de schema operacional.

## Restrições

- preservar a arquitetura validada;
- não versionar segredos;
- não alterar outros workflows;
- usar somente testes sintéticos/offline;
- não modificar a planilha real;
- não ativar, publicar, fazer deploy ou merge;
- entregar branch e PR draft para revisão.

## Critérios de aceite

- JSON importável com Manual e Schedule a cada minuto;
- timezone `America/Sao_Paulo` e `active=false`;
- `PAUSA_GERAL` e configuração crítica lidas da aba `Automação Meta`;
- Instagram e Facebook na mesma execução, sem duplicar canal publicado;
- estados gerais e por canal determinísticos;
- até três tentativas funcionais por canal, com backoff 10/30 minutos;
- retry HTTP com duas tentativas;
- log append-only e reserva antes da Meta;
- IDs/URLs existentes preservados;
- 17 cenários obrigatórios aprovados offline;
- documentação de migração, operação e validação.

## Arquivos esperados

Os artefatos ficam em `n8n/meta-publicador-v2/`, acompanhados do validador
executável em Node.js.
