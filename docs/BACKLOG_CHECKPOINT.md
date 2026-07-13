# Backlog — checkpoint de 12/07/2026

## Concluído nesta sessão

### BKL-014 — Decidir a rota técnica da integração multiproduto

Status: **Concluído para a prova técnica inicial**.

Evidências:

- arquitetura de três contas confirmada manualmente;
- sessão MTProto autorizada;
- envio e resposta do bot comprovados;
- persistência após reinício comprovada;
- retry idempotente com o mesmo `operation_id` comprovado.

## Tarefas vivas que continuam abertas

- BKL-007 — validação regulatória e operacional de FGTS/CLT;
- BKL-011 — catálogo de produtos contínuo;
- BKL-012 — mapa de digitação de propostas;
- BKL-013 — acompanhamento e transições de status.

## Próxima tarefa operacional

### BKL-012 — Mapear a digitação de propostas FGTS e CLT

Objetivo imediato:

- fechar campos mínimos comuns e específicos;
- identificar validações e formatos literais;
- preservar o bloqueio de confirmação final;
- coletar evidência somente em operação autorizada.

Depois de amadurecer a BKL-012, iniciar:

### BKL-015 — Dicionário de dados definitivo multiproduto

Entidades recomendadas:

- Cliente;
- Consulta;
- Oferta;
- Proposta;
- Interação;
- Pendência;
- Operação técnica.
