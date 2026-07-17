# BKL-018 — Matriz de permissões humanas

| Capacidade | Admin | Operations | Support | Auditor |
|---|---|---|---|---|
| Ler operação autorizada por RLS | Permitido | Permitido | Permitido, com campos mascarados | Permitido |
| Criar/alterar operação | Permitido | Permitido | Apenas interação/pendência prevista | Negado |
| Excluir operação por SQL | Negado nesta fundação | Negado | Negado | Negado |
| Consultar próprio perfil mínimo | Função controlada | Função controlada | Função controlada | Função controlada |
| Ler `user_profiles` diretamente | Negado | Negado | Negado | Negado |
| Criar perfil humano | Função controlada | Negado e auditado | Negado e auditado | Negado e auditado |
| Alterar papel humano | Função controlada; nunca o próprio | Negado | Negado | Negado |
| Desativar/reativar humano | Função controlada; nunca o próprio | Negado | Negado | Negado |
| Atribuir papel técnico a humano | Negado pelo tipo do banco | Negado | Negado | Negado |
| Ler `app_private`/ciphertext | Negado | Negado | Negado | Negado |
| Usar papéis técnicos BKL-016 | Negado | Negado | Negado | Negado |
| Executar retenção/descarte | Negado | Negado | Negado | Negado |
| Ler auditoria autorizada | Permitido por RLS existente | Negado | Negado | Permitido por RLS existente |
| Alterar RLS, schema, role ou grants | Negado | Negado | Negado | Negado |

Regras globais:

- `anon` não possui acesso operacional;
- `authenticated` sem perfil `ACTIVE` não possui acesso operacional;
- `service_role` não executa as RPCs humanas e não representa usuário final;
- os papéis técnicos `NOLOGIN` da BKL-016 permanecem separados.
