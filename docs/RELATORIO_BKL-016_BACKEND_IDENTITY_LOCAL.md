# Relatório local — BKL-016 identidade mínima do backend

**Data:** 16/07/2026

**Branch:** `codex/bkl-016-backend-identity`

**Status geral:** BKL-016 **Em andamento**

## Entrega

- quatro papéis PostgreSQL `NOLOGIN` e sem atributos administrativos;
- Gateway, retenção, revisão de hold e conclusão de descarte separados;
- nenhum grant direto em tabelas públicas, privadas ou de auditoria;
- wrappers `SECURITY DEFINER` com `search_path = ''` e parâmetros tipados;
- `PUBLIC`, `anon` e `authenticated` sem execução nos wrappers;
- auditoria técnica mínima, sem PII;
- migration incremental, rollback fail-closed, matriz e runbook;
- gate local que recusa branch, stack, alvo, confirmação e caminhos inseguros.

## Validações executadas

- Node.js: **44/44 testes aprovados**, incluindo Storage, envelope, recuperação,
  retenção e os 8 testes novos do gate de identidade;
- cinco suítes SQL distintas aprovadas na mesma stack:
  - banco/RLS;
  - constraints de envelope;
  - retenção/legal hold;
  - reparos de retenção;
  - identidade e privilégios;
- suíte de identidade repetida depois da reaplicação;
- rollback com auditoria indispensável recusado com a mensagem esperada;
- rollback em base limpa aprovado;
- migration reaplicada por `supabase db reset`;
- stack removida com `supabase stop --no-backup`.

## Falhas fechadas comprovadas

- leitura direta de dados privados e auditoria;
- `DELETE` SQL direto;
- troca para papel não concedido por identidade sintética não administrativa;
- `GRANT`, `ALTER ROLE` e `CREATE ROLE`;
- Gateway tentando retenção/hold/descarte;
- operador tentando aprovar sua própria remoção ou concluir descarte;
- revisor tentando anonimizar, preparar descarte ou alterar cliente;
- executor tentando preparar descarte;
- lista vazia e lote acima do limite;
- rollback com auditoria do novo modelo.

## Observações

O Supabase local concede automaticamente os papéis novos ao papel administrativo
`postgres`. Isso permite a simulação com `SET ROLE`; não constitui identidade de
aplicação. O teste recusa qualquer membership operacional diferente desse caso,
e o rollback revoga a associação administrativa antes de remover os papéis.

As provas anteriores de Storage e backup não foram repetidas como operações
externas nesta fase. Seus testes unitários/regressivos passaram, e a nova
identidade não recebeu acesso SQL ao Storage. Nenhuma URL assinada, chave local
ou credencial foi impressa ou persistida.

## Riscos restantes

- Google Cloud KMS real bloqueado por faturamento;
- aprovação jurídica de prazos e finalidades;
- login/credencial real do backend ainda inexistente;
- autenticação futura do Gateway ainda não escolhida;
- estratégia remota de backup e reconciliação operacional;
- aplicação remota da migration ainda não autorizada;
- revisão técnica independente;
- dados reais e produção continuam proibidos.

Não houve conexão remota, dado real, credencial externa, deploy ou merge.
