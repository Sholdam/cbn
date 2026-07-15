# Backlog — checkpoint de 15/07/2026

## Concluído anteriormente

### BKL-014 — Decidir a rota técnica da integração multiproduto

Status: **Concluído para a prova técnica inicial**.

Evidências:

- arquitetura de três contas confirmada manualmente;
- sessão MTProto autorizada;
- envio e resposta do bot comprovados;
- persistência após reinício comprovada;
- retry idempotente com o mesmo `operation_id` comprovado.

## Avanço da BKL-012

### CLT — fluxo de digitação comprovado

Foram confirmados no fluxo observado:

- escolha de banco e oferta;
- RG;
- órgão emissor;
- UF emissora;
- data de emissão em `DD/MM/AAAA`;
- rejeição de data inválida ou futura;
- código COMPE;
- agência sem dígito ou opção de pular;
- conta com dígito;
- tipo de conta;
- revisão final;
- opções de confirmar ou corrigir;
- criação com número de contrato.

**Decisão:** o mapeamento CLT está suficiente para iniciar o contrato técnico do Gateway, mantendo validação, autorização final e idempotência.

### FGTS — pendência remanescente

As consultas disponíveis até agora retornaram sem oferta.

**Decisão:** não inventar campos pós-oferta. Aguardar cliente autorizado com oferta real e registrar o fluxo literal até a confirmação final.

## Avanço da BKL-013

Foram confirmados no CLT:

- proposta criada;
- consulta por número de contrato;
- status literal `Em análise de compliance`;
- assinatura pendente;
- motivo de aprovação automática;
- link operacional de assinatura/coleta.

**Regra nova:** status bruto, ação pendente, motivo e link devem ser armazenados em campos separados. Uma ação de assinatura pendente não pode apagar o status de análise, nem o contrário.

## Tarefas vivas que continuam abertas

- BKL-007 — validação regulatória e operacional de FGTS/CLT;
- BKL-011 — catálogo de produtos contínuo;
- BKL-012 — completar prompts de endereço e o fluxo FGTS pós-oferta;
- BKL-013 — capturar transições após assinatura, análise final, aprovação/reprovação e pagamento.

## Próxima tarefa operacional

### BKL-012 — concluir o que falta sem bloquear o projeto

Próximas ações:

1. capturar os prompts de endereço não mostrados integralmente;
2. aguardar a primeira oferta FGTS real;
3. registrar somente evidências mascaradas;
4. manter bloqueio técnico da confirmação final;
5. não transcrever CPF, RG, endereço, conta, contrato ou link real.

### BKL-013 — acompanhar a proposta CLT existente

Capturar, quando ocorrer:

1. assinatura concluída;
2. nova etapa de análise;
3. aprovação ou reprovação;
4. pagamento, cancelamento ou expiração.

## Próxima fase preparada

Depois de amadurecer BKL-012 e BKL-013, iniciar:

### BKL-015 — Dicionário de dados definitivo multiproduto

Entidades recomendadas:

- Cliente;
- Consulta;
- Oferta;
- Proposta;
- Interação;
- Pendência;
- Operação técnica.

Campos adicionais já recomendados para Proposta:

- `status_raw`;
- `status_normalizado`;
- `acao_pendente`;
- `motivo_raw`;
- `link_assinatura`;
- `consultado_em`.