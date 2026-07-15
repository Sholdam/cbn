# Backlog — checkpoint de 15/07/2026

## Concluído anteriormente

### BKL-014 — Decidir a rota técnica da integração multiproduto

Status: **Concluído para a prova técnica inicial**.

Evidências:

- arquitetura de três contas confirmada;
- sessão MTProto autorizada;
- persistência após reinício comprovada;
- retry idempotente com o mesmo `operation_id` comprovado.

## BKL-012 — mapeamento das propostas

### CLT

O fluxo de digitação foi confirmado até a criação e o protocolo, incluindo documento, data, COMPE, agência, conta com dígito, tipo de conta, revisão, correção e confirmação final.

### FGTS

As consultas observadas ainda não retornaram oferta. Campos pós-oferta permanecem como **A confirmar FGTS**, sem regra inferida do CLT.

## BKL-013 — acompanhamento

No CLT foram confirmados:

- proposta criada;
- consulta por contrato;
- status `Em análise de compliance`;
- assinatura pendente;
- motivo operacional;
- link de assinatura/coleta.

Status, ação pendente, motivo e link são campos separados.

## BKL-015 — Dicionário de Dados multiproduto

Status: **Concluído v1**.

Foi criada a aba `Dicionário de Dados`, com `DD-001` a `DD-072`, cobrindo:

- Cliente;
- Consulta;
- Oferta;
- Proposta;
- Interação;
- Pendência;
- Operação técnica.

Foram alinhadas as abas operacionais:

- `Clientes`;
- `Consultas`;
- `Ofertas`;
- `Propostas`;
- `Interações`;
- `Pendências`;
- `Operações Técnicas`.

### Critérios atendidos

- cada entidade possui identificador próprio;
- Consulta, Oferta e Proposta possuem produto obrigatório;
- FGTS e CLT possuem estados e operações independentes;
- `operation_id` está presente nas estruturas técnicas e comerciais;
- status original, status normalizado, ação pendente e motivo não se sobrescrevem;
- campos sensíveis usam referências protegidas ou versões mascaradas;
- sessão Telegram é representada apenas por `session_alias`;
- campos FGTS não observados estão marcados como pendentes, sem regra inventada.

### Segurança incorporada

- CPF completo: tokenização ou referência em banco protegido;
- RG, endereço e dados bancários: storage criptografado;
- sessão MTProto: cofre de secrets;
- link de assinatura: referência protegida;
- retorno bruto e logs: storage protegido e mascarado;
- MTProto: `random_id` determinístico a partir do `operation_id`.

Novos campos FGTS serão manutenção do dicionário e não reabrem a arquitetura.

## Próxima tarefa operacional

### BKL-016 — Definir armazenamento de dados sensíveis

Status: **Próxima**.

Decisões necessárias:

1. banco protegido para dados estruturados;
2. criptografia ou tokenização de CPF e dados financeiros;
3. storage de documentos e retornos brutos;
4. cofre de secrets para sessões e tokens;
5. perfis de acesso mínimo;
6. retenção, anonimização e exclusão;
7. backup e recuperação.

A planilha continuará contendo apenas referências, aliases, códigos, resumos e dados mascarados.

## Tarefas vivas paralelas

- BKL-007 — validação regulatória e operacional;
- BKL-011 — catálogo de produtos contínuo;
- BKL-012 — fluxo FGTS pós-oferta;
- BKL-013 — assinatura, análise, aprovação, pagamento ou cancelamento.