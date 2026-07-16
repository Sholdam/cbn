# Relatório local — BKL-016 Retenção e legal hold

## Revisão corretiva — 16/07/2026

A revisão humana identificou três bloqueadores e uma melhoria de segregação. A
migration incremental `20260719_001_bkl016_retention_legal_hold_repairs.sql` foi
criada porque a CLI do Supabase não aceita duas migrations com a mesma versão
diária `20260718`. A migration `20260718_001` permaneceu inalterada.

Correções comprovadas:

- negações esperadas por política não lançam exceção depois da auditoria;
  retornam zero/nenhum inventário, preservam `RETENTION_EVALUATED` e o evento
  `*_DENIED`, e o runtime interrompe o descarte;
- dependências sensíveis de proposta, payload ou arquivo recusam a anonimização
  integral do cliente; interações e pendências têm conteúdo mascarado removido
  atomicamente;
- triggers impedem reintroduzir dados privados, proposta, payload, arquivo,
  interação ou pendência após anonimização;
- hold em `CLIENT` protege dinamicamente payload e arquivo do mesmo cliente;
- `complete_retention_deletion` revalida o escopo imediatamente antes de concluir;
- o runtime comprovou que hold aplicado entre `prepare` e `complete` mantém o
  objeto Storage e o estado `DELETION_PENDING`;
- solicitante e aprovador da remoção do hold precisam ser atores diferentes;
- rollback corretivo recusou estado novo, passou em base limpa e a reaplicação
  completa foi aprovada.

As quatro suítes SQL, os 36 testes Node e o runtime local com Storage foram
executados novamente. A BKL-016 permanece **Em andamento**.

Data: 16/07/2026

Branch: `codex/bkl-016-retention-legal-hold`

Status: **Em andamento**

Ambiente: Supabase local descartável, sem vínculo remoto

## Entregas

- migration incremental `20260718_001_bkl016_retention_legal_hold.sql`;
- rollback fail-closed correspondente;
- políticas configuráveis sem prazo jurídico hardcoded;
- controles privados por entidade e validação de propriedade;
- legal hold com solicitação e remoção explícitas;
- anonimização transacional, idempotente e sem plaintext;
- exclusão física em duas fases com inventário e confirmação de Storage;
- bloqueio de DELETE direto em entidade controlada;
- auditoria append-only sem PII;
- testes SQL, testes Node e runtime com Storage local real;
- runbook e atualização do handoff, backlog e arquitetura.

## Resultados comprovados

- `supabase db reset`: aprovado e reaplicado;
- migration e seed sintético: aprovados;
- suíte base de banco/RLS: aprovada;
- constraints de envelope: aprovadas;
- retenção/legal hold SQL: aprovada;
- legal hold bloqueou anonimização, banco e Storage;
- remoção de hold exigiu solicitação explícita;
- anonimização repetida não alterou o resultado;
- backup realizado depois da anonimização foi restaurado sem reintroduzir os
  identificadores removidos;
- lista ausente/vazia, lote acima do limite e confirmação incorreta foram
  recusados;
- dependência ativa impediu exclusão;
- falha simulada de Storage manteve `DELETION_PENDING` e a referência intacta;
- objeto sintético foi removido do bucket correto e sua ausência comprovada antes
  de marcar `DELETED`;
- rollback com estado novo foi recusado;
- rollback limpo e reaplicação completa foram aprovados;
- 36 testes Node foram aprovados, incluindo nove gates específicos de retenção;
- runtime local ponta a ponta foi aprovado;
- nenhuma URL assinada foi criada ou persistida.

## Falhas corrigidas durante a implementação

O primeiro teste SQL revelou ambiguidade entre a variável PL/pgSQL e o alias do
inventário. O alias foi tornado inequívoco e toda a migration foi reaplicada.
Outro teste detectou uma fixture de `object_key` incompatível com a proteção
contra sequência numérica; a fixture passou a usar apenas UUID/hash sintético.

## Segurança e limpeza

- nenhum CPF, RG, nome real, endereço, conta ou telefone real;
- nenhuma credencial externa, token remoto, sessão ou chave real;
- nenhuma conexão com Supabase remoto, produção, Railway, n8n, Appsmith,
  Telegram ou Google Cloud;
- KMS usado apenas pelas fixtures locais já existentes;
- `telegram-gateway/` e `.env.example` inalterados;
- stack encerrada com `supabase stop --no-backup`;
- nenhum objeto sintético residual conhecido;
- nenhum merge realizado.

## Riscos restantes

Prazos legais, taxonomia final, identidade backend mínima, KMS real, aplicação em
desenvolvimento remoto, reconciliação operacional e revisão independente seguem
pendentes. Por isso a BKL-016 permanece **Em andamento**.
