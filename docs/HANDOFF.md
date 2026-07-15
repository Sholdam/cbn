# Handoff — CBN Crédito

**Atualizado em:** 15/07/2026, após conclusão da BKL-015 e alinhamento das estruturas operacionais  
**Projeto:** CBN — operação autônoma de varredura e venda de crédito  
**Escopo inicial:** FGTS + Crédito do Trabalhador (CLT)

## Objetivo

Construir uma operação autônoma com captação pela Meta, atendimento no WhatsApp, consentimento, consulta dos dois produtos, consolidação das ofertas, digitação das propostas aceitas, acompanhamento e intervenção humana somente em exceções.

## Decisões estruturais vigentes

1. A varredura padrão consulta **FGTS e CLT** após consentimento e dados suficientes.
2. As ofertas devem vir somente dos sistemas reais; o agente não inventa banco, valor, prazo ou taxa.
3. O atendimento não fala diretamente com Telegram ou Prospecta. O n8n utilizará um **Gateway interno**.
4. Cada sessão Telegram processará somente uma operação ativa por vez.
5. Cada operação terá `operation_id` persistente para impedir duplicidade em timeout ou retry.
6. Proposta real somente com autorização final expressa do cliente/operador.
7. Status bruto, status normalizado, ação pendente, motivo e link são campos independentes.
8. CPF, RG, endereço, dados bancários, sessão Telegram e links operacionais ficam fora de planilhas e logs abertos.

## Checkpoint técnico concluído

- três contas Telegram vinculáveis;
- CLT e FGTS simultâneos, sem mistura de contexto;
- conta de status com acesso cruzado às propostas;
- sessão MTProto persistente após reinício;
- retry idempotente com o mesmo `operation_id` e somente uma mensagem enviada.

A rota provisória do MVP é:

1. API oficial da fornecedora, quando disponível e comprovada;
2. MTProto com contas separadas enquanto isso;
3. Telegram Web RPA apenas como contingência.

A **BKL-014** está concluída.

## BKL-012 — mapeamento das propostas

### CLT confirmado

1. banco e oferta;
2. RG somente números; RG novo pode usar CPF;
3. órgão emissor;
4. UF emissora;
5. data `DD/MM/AAAA`, rejeitando data inválida ou futura;
6. código COMPE;
7. agência sem dígito ou possibilidade de pular;
8. conta com dígito e separador;
9. tipo de conta;
10. revisão e correção;
11. confirmação final;
12. criação e protocolo.

O endereço veio automaticamente do cadastro no fluxo observado. Só deve ser solicitado se o sistema pedir correção.

### FGTS pendente

A consulta, os pré-requisitos e os retornos sem oferta foram confirmados. Os campos pós-oferta continuam como **A confirmar FGTS** até surgir cliente autorizado com oferta real.

## BKL-013 — acompanhamento CLT

Já foram observados:

- proposta criada;
- consulta por número de contrato;
- status `Em análise de compliance`;
- assinatura pendente;
- motivo operacional;
- link de assinatura/coleta.

O parser deve manter separados:

- `status_raw`;
- `status_normalizado`;
- `acao_pendente`;
- `motivo_raw`;
- `link_assinatura_ref`;
- `last_checked_at`.

## BKL-015 — Dicionário de Dados multiproduto

**Status: Concluído v1.**

Foi criada na planilha a aba `Dicionário de Dados`, com `DD-001` a `DD-072`, cobrindo:

1. Cliente;
2. Consulta;
3. Oferta;
4. Proposta;
5. Interação;
6. Pendência;
7. Operação técnica.

Também foram alinhadas as estruturas operacionais:

- `Clientes`;
- `Consultas`;
- `Ofertas`;
- `Propostas`;
- `Interações`;
- `Pendências`;
- `Operações Técnicas`.

As abas agora usam identificadores próprios, referências entre entidades, produto separado, `operation_id`, aliases, códigos, estados normalizados e versões mascaradas.

### Regras de segurança incorporadas

- CPF completo: referência segura ou tokenização;
- planilha: somente CPF mascarado;
- RG, endereço e conta bancária: storage criptografado;
- sessão MTProto: cofre de secrets; operação usa somente `session_alias`;
- link de assinatura: referência protegida;
- retorno bruto e logs: storage protegido, mascaramento e retenção;
- retry: mesmo `operation_id`; `random_id` determinístico na rota MTProto.

Campos FGTS ainda não observados entram como manutenção do dicionário, sem reabrir a arquitetura.

## Próxima tarefa

### BKL-016 — Definir armazenamento de dados sensíveis

Precisamos decidir e documentar:

1. banco de dados protegido;
2. criptografia e tokenização;
3. cofre de secrets;
4. separação entre banco, storage de documentos e logs;
5. política de retenção e exclusão;
6. perfis de acesso mínimo;
7. backup e recuperação.

A planilha e os logs abertos continuarão recebendo somente referências, aliases, códigos, resumos e dados mascarados.

## Tarefas vivas paralelas

- BKL-007 — validação regulatória e operacional;
- BKL-011 — catálogo de produtos contínuo;
- BKL-012 — fluxo FGTS pós-oferta;
- BKL-013 — assinatura, análise, aprovação, pagamento ou cancelamento.

## Arquivos do repositório

- `telegram-gateway/src/auth.js`
- `telegram-gateway/src/check-session.js`
- `telegram-gateway/src/idempotency-test.js`
- `docs/DICIONARIO_DADOS.md`
- `docs/BACKLOG_CHECKPOINT.md`
- `.env.example` sem credenciais

## Regras para retomar

1. abrir este handoff;
2. iniciar pela BKL-016;
3. manter BKL-012 e BKL-013 como tarefas vivas não bloqueantes;
4. não gerar nova sessão Telegram sem necessidade;
5. não registrar segredo ou dado completo de cliente em código, planilha, print ou chat;
6. não criar proposta sem autorização final expressa.