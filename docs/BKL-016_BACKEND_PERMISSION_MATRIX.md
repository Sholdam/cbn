# BKL-016 — Matriz de permissões do backend

## Legenda

- **Permitido:** operação direta estritamente necessária.
- **Função controlada:** somente `EXECUTE` em wrapper listado; sem acesso à tabela.
- **Negado:** privilégio revogado ou inexistente.
- **N/A:** não pertence à responsabilidade do papel.

Os quatro papéis são `NOLOGIN`, `NOINHERIT`, `NOSUPERUSER`, `NOCREATEDB`,
`NOCREATEROLE`, `NOREPLICATION` e `NOBYPASSRLS`. Nenhum é owner de schema,
tabela, sequência ou função.

| Capacidade | `cbn_gateway_backend` | `cbn_retention_operator` | `cbn_hold_reviewer` | `cbn_deletion_executor` |
|---|---|---|---|---|
| SELECT direto em `public` | Negado | Negado | Negado | Negado |
| INSERT/UPDATE direto em `public` | Negado | Negado | Negado | Negado |
| DELETE direto | Negado | Negado | Negado | Negado |
| Ler `app_private` | Negado | Negado | Negado | Negado |
| Ler `audit.events` | Negado | Negado | Negado | Negado |
| Criar operação técnica | Função controlada | Negado | Negado | Negado |
| Atualizar estado da operação | Função controlada | Negado | Negado | Negado |
| Avaliar retenção | Negado | Função controlada | Negado | Negado |
| Anonimizar | Negado | Função controlada | Negado | Negado |
| Aplicar legal hold | Negado | Função controlada | Negado | Negado |
| Solicitar remoção de hold | Negado | Função controlada | Negado | Negado |
| Aprovar/rejeitar remoção | Negado | Negado | Função controlada | Negado |
| Preparar exclusão | Negado | Função controlada | Negado | Negado |
| Cancelar exclusão pendente | Negado | Função controlada | Negado | Negado |
| Concluir exclusão | Negado | Negado | Negado | Função controlada |
| Alterar política jurídica | Negado | Negado | Negado | Negado |
| Alterar schema/RLS/migration | Negado | Negado | Negado | Negado |
| Criar/alterar/conceder role | Negado | Negado | Negado | Negado |
| Acessar Storage por SQL | Negado | Negado | Negado | Negado |
| Ler plaintext/DEK/KEK/segredo | Negado | Negado | Negado | Negado |

## Wrappers concedidos

### Gateway

- `app_private.gateway_create_operation(...)`
- `app_private.gateway_update_operation_state(...)`

### Operador de retenção

- `app_private.retention_evaluate(...)`
- `app_private.retention_apply_legal_hold(...)`
- `app_private.retention_anonymize_clients(...)`
- `app_private.retention_prepare_deletion(...)`
- `app_private.retention_cancel_deletion(...)`
- `app_private.retention_request_hold_removal(...)`

### Revisor independente

- `app_private.hold_review_removal(...)`

### Executor de descarte

- `app_private.retention_complete_deletion(...)`

As funções internas e `audit.record_backend_identity_event(...)` não são
concedidas a nenhum dos papéis operacionais. O owner continua sendo a identidade
técnica que executa migrations. A associação administrativa automática do
Supabase local permite que `postgres` use `SET ROLE` durante testes; ela não é
uma credencial operacional e é removida pelo rollback antes de apagar os papéis.

## Auditoria por identidade

A migration `20260721_001` não altera nenhum item da matriz. Os mesmos wrappers
registram eventos específicos para `CBN_RETENTION_OPERATOR`,
`CBN_HOLD_REVIEWER` e `CBN_DELETION_EXECUTOR`, além dos eventos já existentes do
Gateway. Os papéis continuam sem `EXECUTE` em
`audit.record_backend_identity_event(...)` e sem acesso direto a `audit.events`.
