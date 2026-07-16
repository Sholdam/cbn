# Relatório local — BKL-016 identidade mínima do backend

**Data:** 16/07/2026

**Branch:** `codex/bkl-016-backend-identity`

**Status geral:** BKL-016 **Em andamento**

## Entrega

- correção incremental `20260721_001`, sem alteração da migration-base;
- eventos específicos de identidade para Gateway, operador, revisor nos caminhos
  de aprovação/rejeição e executor de descarte;
- ausência de evento de sucesso em negação, zero alterações ou falha técnica;
- rollback incremental fail-closed antes do rollback-base;
- matriz de permissões e grants preservados;

- quatro papéis PostgreSQL `NOLOGIN` e sem atributos administrativos;
- Gateway, retenção, revisão de hold e conclusão de descarte separados;
- nenhum grant direto em tabelas públicas, privadas ou de auditoria;
- wrappers `SECURITY DEFINER` com `search_path = ''` e parâmetros tipados;
- `PUBLIC`, `anon` e `authenticated` sem execução nos wrappers;
- auditoria técnica mínima, sem PII;
- migration incremental, rollback fail-closed, matriz e runbook;
- gate local que recusa branch, stack, alvo, confirmação e caminhos inseguros.

## Validações executadas

### Correção localizada de auditoria

- teste SQL focado de identidade: aprovado;
- teste focado comprova `allowed=false` em zero alterações e contagens exatas,
  sem evento extra após falhas técnicas;
- gate Node focado: **8/8 testes aprovados**;
- suíte Node completa BKL-016: **44/44 testes aprovados**;
- runtime SQL completo foi executado uma vez e encerrou removendo a stack local;
  o invólucro do terminal atingiu seu timeout antes de capturar a linha final;
- verificação focada posterior comprovou explicitamente a recusa do rollback
  após evento de identidade e o rollback limpo `20260721_001` → `20260720_001`;
- `git diff --check`: aprovado;
- `validate-bkl016.ps1`: aprovado;
- `telegram-gateway/` e `.env.example`: inalterados;
- nenhuma conexão remota, credencial externa, dado real, deploy ou merge.

O nome inicialmente sugerido `20260720_002` não foi usado porque a CLI do
Supabase interpreta somente o trecho anterior ao primeiro `_` como versão e
detectou colisão com `20260720_001`. A migration permaneceu incremental e recebeu
a versão única `20260721_001`, sem modificar o histórico aplicado.

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
