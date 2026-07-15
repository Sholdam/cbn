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
- conta com dígito e separador;
- tipo de conta;
- revisão final;
- opções de confirmar ou corrigir;
- criação com número de contrato.

**Decisão:** o mapeamento CLT está suficiente para iniciar contratos técnicos e modelagem de dados, mantendo autorização final e idempotência.

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

**Regra:** status bruto, ação pendente, motivo e link devem ser armazenados em campos separados. Uma ação de assinatura pendente não pode apagar o status de análise, nem o contrário.

## BKL-015 iniciada — Dicionário de Dados multiproduto

Status: **Em andamento**.

Foi criada na planilha a aba `Dicionário de Dados`, com os registros `DD-001` a `DD-072`.

Entidades cobertas:

- Cliente;
- Consulta;
- Oferta;
- Proposta;
- Interação;
- Pendência;
- Operação técnica.

Para cada campo foram definidos:

- nome técnico;
- produto aplicável;
- tipo;
- obrigatoriedade;
- origem;
- destino de uso;
- sensibilidade;
- armazenamento;
- validação;
- regra de atualização;
- estado da validação.

### Decisões de segurança incorporadas

- CPF completo fica tokenizado ou referenciado em banco protegido; planilha usa apenas CPF mascarado.
- RG, endereço e dados bancários ficam em storage criptografado.
- Sessão Telegram fica em cofre de secrets; banco registra apenas `session_alias`.
- Link de assinatura fica protegido e não aparece completo em planilha ou log aberto.
- Logs e retornos brutos ficam em storage protegido, com mascaramento e retenção.
- Idempotência usa `operation_id` persistente; MTProto usa `random_id` determinístico.

## Tarefas vivas que continuam abertas

- BKL-007 — validação regulatória e operacional de FGTS/CLT;
- BKL-011 — catálogo de produtos contínuo;
- BKL-012 — completar o fluxo FGTS pós-oferta;
- BKL-013 — capturar transições após assinatura, análise final, aprovação/reprovação e pagamento;
- BKL-015 — consolidar o dicionário e alinhar as abas operacionais.

## Próxima tarefa operacional

### BKL-015 — alinhar as estruturas operacionais

Próximas ações:

1. revisar a versão inicial do dicionário;
2. alinhar as abas `Clientes`, `Propostas`, `Interações` e `Pendências` às entidades e referências definidas;
3. separar claramente o que fica no banco protegido do que pode aparecer mascarado na planilha;
4. transformar enums e regras em contratos do n8n/Gateway;
5. manter campos FGTS pós-oferta como `A confirmar FGTS` até surgir caso autorizado.

## Critério para avançar para a próxima task

A BKL-015 poderá ser concluída quando:

- as abas operacionais estiverem alinhadas ao dicionário;
- cada campo sensível tiver destino seguro definido;
- os contratos do Gateway usarem os mesmos nomes e enums;
- não houver status único misturando FGTS e CLT;
- os campos FGTS ainda não observados estiverem explicitamente marcados como pendentes, sem regra inventada.