# Prompt Codex — BKL-016 identidade mínima do backend

## Objetivo

Criar e validar localmente identidades técnicas de menor privilégio para o
Gateway, retenção, revisão de legal hold e conclusão de descarte. A identidade
operacional não pode ser `service_role`, não pode acessar tabelas privadas e
não pode acumular preparação e conclusão de exclusão.

## Restrições

- branch `codex/bkl-016-backend-identity`;
- Supabase local descartável e dados exclusivamente sintéticos;
- nenhuma conexão remota, credencial, login, senha, token ou recurso pago;
- `telegram-gateway/` e `.env.example` inalterados;
- nenhuma migration anterior reescrita;
- sem merge ou deploy;
- BKL-016 permanece **Em andamento**.

## Entregas

1. migration incremental `20260720_001_bkl016_backend_identity.sql`;
2. rollback fail-closed correspondente;
3. papéis `NOLOGIN` sem privilégios administrativos;
4. wrappers `SECURITY DEFINER` com `search_path = ''` e owner de migration;
5. grants exclusivos por papel e revogação de `PUBLIC`, `anon` e `authenticated`;
6. matriz de permissões, runbook e relatório;
7. teste SQL com `SET ROLE` e identidade sintética sem privilégio administrativo;
8. runtime com gate `CBN_BACKEND_IDENTITY_CONFIRMED=synthetic-local-role-test`;
9. rollback recusado com auditoria/estado indispensável, rollback limpo e reaplicação;
10. varredura de PII, segredo, JWT, URL assinada, credencial e `.env` real.

## Critérios de aceite

- Gateway executa somente wrappers operacionais autorizados;
- operador avalia, anonimiza, aplica hold, solicita remoção, prepara e cancela;
- revisor independente somente aprova/rejeita remoção solicitada;
- executor separado somente conclui descarte após ausência de Storage;
- nenhum papel lê tabelas privadas ou `audit.events` diretamente;
- nenhum papel possui `LOGIN`, `SUPERUSER`, `CREATEDB`, `CREATEROLE`,
  `BYPASSRLS`, `REPLICATION` ou ownership;
- tentativas de `DELETE`, `GRANT`, `ALTER ROLE`, `CREATE ROLE` e troca indevida
  de papel falham;
- auditoria registra apenas códigos e identidade técnica;
- todos os testes anteriores continuam aprovados.

Ao final, fazer commit e push da branch, sem merge.
