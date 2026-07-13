# Arquitetura Técnica — Gateway de Crédito CBN

## Rota escolhida

### 1. API oficial Prospecta

Permanece como rota preferida caso a fornecedora entregue documentação, autenticação e endpoints operacionais comprovados.

### 2. Telegram MTProto

Rota provisória validada para operar o bot como conta de usuário real.

Provas concluídas em 12/07/2026:

- autorização da conta;
- envio e recebimento de mensagem;
- sessão persistente após reinício do processo;
- idempotência do envio por `operation_id`/`random_id` determinístico.

### 3. RPA no Telegram Web

Somente contingência. Não deve ser a base do MVP enquanto MTProto permanecer estável.

## Sessões previstas

- sessão CLT;
- sessão FGTS;
- sessão Propostas/Status.

Cada sessão possui fila exclusiva e somente uma operação ativa.

## Contrato interno do Gateway

O atendimento e o CRM chamam operações internas, por exemplo:

- `consultar_clt`;
- `consultar_fgts`;
- `criar_proposta`;
- `consultar_status`.

O Gateway converte a operação para API, MTProto ou contingência sem expor essa decisão ao agente comercial.

## Idempotência

Cada operação deve possuir um `operation_id` persistente.

Regras:

1. gerar ou receber o `operation_id` antes do primeiro envio;
2. persistir o estado antes de executar efeito externo;
3. derivar um identificador determinístico de envio;
4. em retry, reutilizar o mesmo identificador;
5. nunca reenviar cegamente após timeout;
6. consultar histórico/estado antes de repetir uma etapa;
7. confirmação de proposta exige trava adicional e autorização final.

## Lock por sessão

Campos mínimos do lock:

- `session_id`;
- `operation_id`;
- `status`;
- `lease_expires_at`;
- `heartbeat_at`;
- `current_step`.

O lock deve expirar de forma segura e retornar a operação para revisão ou retry idempotente.

## Estados mínimos da operação

- `RECEIVED`;
- `LOCK_ACQUIRED`;
- `COMMAND_PREPARED`;
- `COMMAND_SENT`;
- `WAITING_RESPONSE`;
- `RESPONSE_RECEIVED`;
- `NORMALIZED`;
- `COMPLETED`;
- `RETRY_PENDING`;
- `HUMAN_REVIEW`;
- `FAILED_FINAL`.

## Observabilidade

Registrar:

- `operation_id`;
- produto;
- sessão;
- etapa;
- tentativa;
- tempo de resposta;
- retorno bruto mascarado;
- retorno normalizado;
- erro;
- decisão de retry;
- origem da alteração.

Nunca registrar segredo ou documento completo.

## Segurança

- `api_id`, `api_hash` e sessão em cofre de secrets;
- 2FA nas contas;
- revogação e rotação documentadas;
- logs mascarados;
- permissões mínimas;
- nenhuma credencial no GitHub.
