# Bot de triagem FGTS — Chatwoot e n8n

## Escopo aprovado

O fluxo automatiza somente conversas originadas do anúncio de FGTS na caixa
oficial `CBN Api`. Mensagens de outros produtos são abertas para atendimento
humano sem resposta do bot. No fluxo FGTS, ele:

1. reconhece a mensagem inicial do anúncio;
2. solicita o CPF;
3. valida os 11 dígitos, a sequência e os dígitos verificadores;
4. solicita nova tentativa quando o CPF é inválido;
5. quando válido, orienta a autorização da `GIRO SOCIEDADE DE CRÉDITO`;
6. encerra o bot e abre a conversa para atendimento humano.

O bot não consulta banco, não simula CLT, não menciona Crédito do Trabalhador,
não envia proposta e não responde depois do handoff.

## Mensagens

### Solicitação do CPF

> Olá! 👋 Sou a assistente virtual da CBN Crédito.
>
> Para verificarmos as opções disponíveis para você, envie seu CPF com os 11
> números, por favor.

### CPF inválido

> CPF inválido, pode enviar novamente?

### Autorização do FGTS

> CPF recebido ✅
>
> Agora preciso que você autorize a consulta do seu FGTS.
>
> Abra o aplicativo FGTS ou a Carteira de Trabalho Digital e autorize a
> instituição:
>
> GIRO SOCIEDADE DE CRÉDITO
>
> Quando concluir, responda PRONTO.

## Estado e privacidade

O estado fica nos atributos da conversa:

- `cbn_fgts_bot_stage`: `awaiting_cpf` ou `handed_off`;
- `cbn_fgts_last_message_id`: id técnico da última mensagem processada.

O CPF completo não é copiado para atributo, etiqueta, log ou execução salva. A
mensagem original continua no histórico do Chatwoot, pois foi enviada pelo
próprio cliente. O n8n está configurado para não persistir execuções bem-sucedidas
e para eliminar execuções com erro após sete dias.

## Infraestrutura

- serviço Railway: `n8n-cbn-bot`;
- imagem fixada: `n8nio/n8n:2.28.7`;
- volume: `n8n-cbn-bot-volume`;
- montagem: `/home/node/.n8n`;
- domínio: `https://n8n-cbn-bot-production.up.railway.app`;
- banco do piloto: SQLite no volume isolado;
- instância n8n antiga: preservada e não alterada.

## Teste seguro

Use apenas CPF sintético de teste e uma conversa controlada. Confirme:

1. mensagem FGTS recebe a etiqueta `fgts`;
2. bot solicita CPF;
3. uma sequência repetida de 11 dígitos recebe a mensagem de correção;
4. um CPF sintético válido recebe a orientação da GIRO;
5. conversa passa para `open`;
6. nova mensagem não recebe resposta do bot;
7. nenhum CPF aparece nos atributos da conversa ou nos logs do n8n.

## Correção operacional de 26/07/2026

A primeira versão publicada continha uma expressão inválida na URL dinâmica do
nó `Atualizar estado técnico`. A saudação era enviada, mas o estágio
`awaiting_cpf` não era persistido; por isso, a mensagem seguinte era entregue ao
humano sem a orientação automática da GIRO.

A expressão foi substituída por uma única expressão n8n válida, publicada e
confirmada sem erro de sintaxe. Conversas iniciadas antes da correção não são
reprocessadas automaticamente para evitar mensagens duplicadas; nelas, a
orientação foi concluída manualmente pelo atendimento.
