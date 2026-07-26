# Runbook — Gateway Telegram CLT

## Objetivo

Executar uma consulta CLT por vez no bot operacional do Telegram e devolver o
retorno ao n8n para registro exclusivo como nota privada do Chatwoot.

## Fluxo suportado

1. n8n recebe a confirmação/autorização do cliente;
2. n8n obtém o CPF da conversa e o telefone do contato no Chatwoot;
3. n8n gera ou reutiliza um `operation_id`;
4. n8n chama `POST /v1/clt/simulations`;
5. Gateway posiciona o bot no menu CLT;
6. Gateway seleciona `Simular Todos os Bancos`;
7. Gateway envia o CPF;
8. se solicitado, envia o telefone do contato do CRM;
9. sem oferta, Gateway aguarda `Informe outro CPF ou escolha uma opção`;
10. com oferta, Gateway estrutura até cinco opções e envia `0` para voltar ao
    menu CLT sem selecionar banco;
11. Gateway envia o resultado sanitizado e as ofertas ao callback fixo;
12. n8n cria mensagem `private` na mesma conversa;
13. quando existirem ofertas, n8n apresenta uma lista interativa ao cliente.

Para a próxima consulta, o Gateway reconhece o menu final e envia `1`, sem
reiniciar toda a navegação.

## Contrato de entrada

Cabeçalho:

```text
x-gateway-key: segredo interno
content-type: application/json
```

Corpo:

```json
{
  "operation_id": "CBN-CLT-<identificador-estável>",
  "conversation_id": 123,
  "cpf": "11 dígitos",
  "phone": "+55DDDNUMERO"
}
```

Respostas:

- `202`: operação nova aceita;
- `200`: mesmo `operation_id` já conhecido; não foi duplicado;
- `400`: CPF, telefone, conversa ou operação inválidos;
- `401`: chave interna ausente ou inválida.

## Contrato do callback

O Gateway chama apenas `N8N_CALLBACK_URL`. O n8n deve validar:

```text
Authorization: Bearer <N8N_CALLBACK_TOKEN>
idempotency-key: <operation_id>
```

Sucesso:

```json
{
  "operation_id": "CBN-CLT-...",
  "conversation_id": 123,
  "product": "CLT",
  "status": "COMPLETED",
  "visibility": "private",
  "result_text": "retorno sanitizado do Telegram",
  "offers": [
    {
      "position": 1,
      "institution": "Banco de exemplo",
      "installments": 24,
      "installment_amount": "222,70",
      "installment_amount_cents": 22270,
      "released_amount": "2.511,07",
      "released_amount_cents": 251107
    }
  ],
  "offer_list": {
    "type": "list",
    "button": "Ver ofertas",
    "sections": [
      {
        "title": "Opções disponíveis",
        "rows": [
          {
            "id": "clt_offer_1",
            "title": "1 - Banco de exemplo",
            "description": "24x R$ 222,70 | Libera R$ 2.511,07"
          },
          {
            "id": "clt_other_amount",
            "title": "Outro valor",
            "description": "Quero verificar outra condição"
          }
        ]
      }
    ]
  },
  "phone_requested": false
}
```

Falha controlada usa `HUMAN_REVIEW` ou `FAILED_FINAL` e sempre solicita revisão
humana. O n8n não deve transformar esse callback em mensagem pública.

## Configuração do n8n

### Disparo

No fluxo de triagem, após autorização:

1. buscar a conversa no Chatwoot;
2. obter o telefone do contato associado;
3. recuperar o CPF enviado pelo cliente sem colocá-lo em log ou atributo aberto;
4. construir `operation_id` estável e salvar no estado técnico da conversa;
5. chamar o Gateway.

Não gerar um novo `operation_id` ao repetir a mesma consulta.

### Callback

Criar webhook separado, protegido pelo token. Antes de criar a nota privada:

1. verificar Bearer;
2. verificar se o `operation_id` pertence à conversa;
3. impedir processamento duplicado;
4. criar mensagem no Chatwoot com `message_type=outgoing` e `private=true`;
5. atualizar somente estado técnico não sensível.

### Lista de ofertas enviada ao cliente

Quando `offers` possuir entre uma e cinco opções, o n8n deve construir uma lista
interativa do WhatsApp:

- uma linha para cada oferta, mantendo a ordem do Telegram;
- título com posição e instituição;
- descrição com prazo, parcela e valor liberado;
- uma última linha fixa chamada `Outro valor`.

Com duas ofertas, o cliente verá:

```text
1 — primeira oferta
2 — segunda oferta
3 — Outro valor
```

Com cinco ofertas, `Outro valor` será a sexta linha. A lista interativa comporta
esse cenário sem perder opções.

IDs estáveis:

```text
clt_offer_1
clt_offer_2
clt_offer_3
clt_offer_4
clt_offer_5
clt_other_amount
```

Ao selecionar uma oferta, o n8n registra a escolha como nota privada e transfere
para atendimento humano. Ao selecionar `Outro valor`, pergunta qual valor o
cliente deseja e também transfere para humano. Esta etapa não cria proposta.

## Falhas que exigem humano

- telefone ausente ou inválido;
- tela inesperada de autorização do C6;
- repetição da solicitação de telefone;
- ausência do prompt de CPF;
- timeout do Telegram;
- resposta final vazia;
- callback indisponível após as tentativas.

O Gateway não tenta adivinhar opções, não cria proposta e não envia o retorno ao
cliente.

## Deploy futuro no Railway

Não executar sem gate humano.

1. usar `telegram-gateway/Dockerfile`;
2. adicionar secrets somente no Railway;
3. manter uma réplica;
4. não montar `.env`;
5. usar domínio privado entre n8n e Gateway, quando disponível;
6. expor publicamente somente se o n8n não conseguir alcançar a rede privada;
7. testar apenas com fixture sintética antes de habilitar o fluxo real;
8. comprovar callback privado e retry com mesmo `operation_id`.

## Riscos restantes

- `telegram@2.26.22` está arquivado;
- fila e lock ainda não estão no PostgreSQL;
- reinício durante operação exige retry supervisionado;
- API oficial Prospecta continua sendo a rota preferida quando disponível;
- dados reais e produção permanecem bloqueados pelos gates do projeto.
