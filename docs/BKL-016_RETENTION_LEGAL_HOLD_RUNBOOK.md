# BKL-016 — Runbook de retenção, anonimização e legal hold

## Reparos obrigatórios da revisão humana

O comportamento vigente é definido pela migration incremental `20260719_001`:

- recusas esperadas por retenção, dependência ou hold retornam sem alteração e
  mantêm auditoria persistente; erro de formato, integridade ou segurança ainda
  lança exceção;
- todo chamador deve tratar retorno vazio/zero como negação e interromper o fluxo;
- hold de `CLIENT` é superior e protege qualquer payload ou arquivo relacionado;
- o hold é reavaliado antes do Storage e novamente no `complete`;
- anonimização de cliente é recusada se proposta, payload ou arquivo exigir
  política própria; nenhum estado parcial é gravado;
- após anonimização, triggers impedem qualquer reidentificação em tabelas públicas
  ou privadas;
- quem solicita remoção do hold não pode aprová-la.

Hold por `OPERATION` não é suportado nesta fase. A decisão é explícita: escopo de
cliente e escopo específico de payload/arquivo são os únicos autorizados.

## Escopo e proibições

Este runbook é somente para desenvolvimento local descartável com fixtures
sintéticas. Dados reais e produção permanecem proibidos até existir KMS real,
política jurídica aprovada e revisão independente. Não há prazo legal fixado na
migration; uma política só pode ficar `ACTIVE` com período explícito e revisão
encerrada.

## Modelo

- `app_private.retention_policies`: categoria, finalidade, período configurável,
  status e revisão.
- `app_private.retention_controls`: entidade técnica, datas de retenção,
  elegibilidade, anonimização, exclusão, legal hold, atores técnicos e versão.
- `audit.events`: trilha append-only com códigos, UUIDs e versão; sem conteúdo.

As tabelas privadas usam RLS forçada, sem grants para `anon`, `authenticated` ou
`PUBLIC`. As funções `SECURITY DEFINER` têm `search_path` vazio e não são
executáveis por esses papéis. O futuro Gateway deverá receber um papel backend
dedicado e mínimo; `service_role` nunca será exposta ao navegador ou Appsmith.

## Legal hold

1. Aplicar com `app_private.apply_legal_hold`, motivo codificado e ator técnico.
2. O estado `BLOCKED` impede anonimização, preparação de exclusão e DELETE direto
   de payload ou referência de arquivo controlados.
3. Solicitar remoção explicitamente com `request_legal_hold_removal`.
4. Remover em chamada separada com `remove_legal_hold` e ator revisor.
5. Reavaliar; a remoção não executa descarte automaticamente.

## Anonimização

`anonymize_clients(uuid[], process_version)` aceita no máximo dez controles
distintos e explícitos. Ela recusa retenção futura ou hold, remove ciphertext
privado do cliente sem descriptografar, neutraliza os identificadores públicos,
marca `anonymized_at` e impede reidentificação posterior. Nova execução retorna
zero alterações, mantendo idempotência.

## Exclusão física em duas fases

1. O runtime valida branch, localhost, ausência de stack anterior, IDs
   sintéticos, caminhos protegidos e a variável humana.
2. `prepare_retention_deletion` bloqueia lote vazio/global, duplicado ou acima de
   dez, valida vencimento, hold e dependências, marca `DELETION_PENDING` e devolve
   inventário técnico.
3. Para arquivo, o runtime remove exatamente o UUID do bucket privado e comprova
   sua ausência.
4. `complete_retention_deletion(..., true, ...)` remove a referência e só então
   grava `DELETED`, `DELETION_COMPLETED` e `STORAGE_DELETION_COMPLETED`.
5. Falha do Storage impede conclusão. `cancel_retention_deletion` devolve o
   controle a `ELIGIBLE` e registra o motivo codificado.

Não existe transação distribuída entre PostgreSQL e Storage. O desenho usa
preparação persistida, confirmação de ausência e recuperação explícita. Se o
objeto já tiver sido apagado mas a conclusão do banco falhar, o controle continua
`DELETION_PENDING` para reconciliação; nunca é marcado como concluído em silêncio.

## Execução local

Com Docker ativo e nenhuma stack Supabase local preexistente:

```powershell
cd C:\Users\Daniely\Documents\CBN\scripts
$env:CBN_RETENTION_DELETE_CONFIRMED='synthetic-local-explicit-ids'
npm.cmd run test:retention
npm.cmd run run:retention-local
```

Suíte SQL, depois de `supabase db reset`:

```powershell
Get-Content -Raw ..\supabase\tests\bkl016_retention_legal_hold_test.sql |
  docker exec -i supabase_db_cbn psql -X -U supabase_admin -d postgres `
    -v ON_ERROR_STOP=1 --no-psqlrc
```

Limpeza obrigatória:

```powershell
supabase stop --no-backup
Remove-Item Env:CBN_RETENTION_DELETE_CONFIRMED -ErrorAction SilentlyContinue
```

## Rollback

O rollback `20260718_001_bkl016_retention_legal_hold_down.sql` recusa prosseguir
se existir política, controle, hold, anonimização, exclusão pendente/concluída ou
evento indispensável. Só é válido em base local limpa e descartável.

## Riscos e gates restantes

- prazos e finalidades precisam de aprovação jurídica/LGPD;
- KMS Google real segue bloqueado por faturamento;
- credencial backend e papel mínimo ainda não existem;
- execução remota desta migration não foi autorizada;
- testes independentes e política operacional de reconciliação ainda são gates;
- dados reais e produção continuam proibidos.
