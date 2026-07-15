# Handoff — CBN Crédito

**Atualizado em:** 15/07/2026, após mapeamento do fluxo CLT de proposta e primeiros status pós-criação  
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
7. Status bruto, motivo e ação pendente devem ser armazenados separadamente quando o sistema devolver informações simultâneas.

## Checkpoint técnico concluído em 12/07/2026

### Arquitetura manual já comprovada

- três contas Telegram podem ser vinculadas;
- CLT e FGTS funcionam simultaneamente;
- os contextos não se misturam;
- a conta dedicada a status visualiza propostas criadas pelas outras contas.

### Teste MTProto — item 5

- conta autorizada com GramJS;
- comando seguro `menu` enviado ao bot operacional;
- resposta do bot recebida;
- PowerShell encerrado e aberto novamente;
- a sessão reconectou sem pedir novo código e sem pedir senha 2FA.

**Resultado:** persistência da sessão comprovada.

### Teste de idempotência — item 6

- `operation_id`: `CBN-IDEMPOTENCIA-MENU-001`;
- o estado foi salvo antes do envio;
- o primeiro processo enviou `menu` uma vez e foi encerrado;
- o segundo processo repetiu a operação com o mesmo identificador determinístico;
- o histórico confirmou apenas uma mensagem enviada ao bot.

**Resultado:** retry com o mesmo `operation_id` não duplicou o comando.

## Checkpoint BKL-012 — fluxo CLT mapeado em 15/07/2026

O fluxo observado ficou confirmado nesta ordem:

1. seleção do banco e da oferta;
2. número do RG, somente números; para RG novo, o bot orienta informar o CPF;
3. órgão emissor do RG;
4. UF emissora em sigla;
5. data de emissão em `DD/MM/AAAA`, com rejeição de data inválida ou futura;
6. código COMPE do banco;
7. agência sem dígito, com opção de pular quando o fluxo permitir;
8. número da conta com dígito;
9. tipo de conta;
10. revisão final dos dados;
11. opção de confirmar e enviar ou corrigir;
12. criação da proposta com retorno de número de contrato.

O resumo final observado inclui dados de documento, endereço e conta bancária. A documentação registra apenas a estrutura e as validações, nunca os valores reais do cliente.

## Checkpoint BKL-013 — primeiros status CLT

Foram confirmados no fluxo observado:

- proposta criada com número de contrato;
- consulta por número do contrato;
- retorno literal de **Em análise de compliance**;
- mensagem paralela de proposta aguardando assinatura;
- motivo de aprovação automática;
- link operacional de assinatura/coleta.

### Regra importante do parser

O sistema pode devolver simultaneamente:

- um status de análise;
- uma ação pendente de assinatura;
- um motivo operacional;
- um link.

Esses campos não podem se sobrescrever. O modelo recomendado é manter, no mínimo:

- `status_raw`;
- `status_normalizado`;
- `acao_pendente`;
- `motivo_raw`;
- `link_assinatura`;
- `consultado_em`.

## Situação do FGTS

O fluxo de consulta foi confirmado, incluindo:

- Saque-Aniversário ativo;
- autorização da instituição indicada pelo sistema;
- CPF com 11 dígitos;
- retorno de CPF inválido;
- retorno de cliente sem oferta.

Ainda não apareceu um cliente autorizado com oferta FGTS disponível. Portanto, os campos pós-oferta e a confirmação final permanecem como **A confirmar em atendimento**, sem inventar regras.

## Decisão técnica atual

A rota provisória escolhida para o MVP é:

1. API oficial da fornecedora, caso seja disponibilizada e comprovada;
2. enquanto isso, MTProto com contas de usuário separadas;
3. Telegram Web RPA apenas como contingência.

A **BKL-014** está concluída no escopo de decisão e prova técnica inicial.

## Segurança e arquivos locais

- A sessão MTProto permanece somente no `.env` local ou em cofre de secrets.
- O `.env` não foi enviado ao GitHub.
- Não publicar prints contendo códigos, sessão, API hash ou dados pessoais.
- Não registrar CPF, RG, endereço, conta bancária, número real de contrato ou link operacional em documentação pública.
- O repositório é público; todos os arquivos enviados devem ser revisados para não conter segredos.

## Próxima tarefa ao retomar

A **BKL-012** permanece aberta apenas para:

1. capturar os prompts de endereço que não apareceram integralmente;
2. mapear o primeiro fluxo FGTS com oferta real;
3. manter o bloqueio técnico da confirmação final;
4. registrar somente evidências mascaradas.

Em paralelo, a **BKL-013** deve acompanhar a proposta CLT já criada até:

1. assinatura;
2. análise final;
3. aprovação ou reprovação;
4. pagamento ou cancelamento.

Depois de amadurecer BKL-012 e BKL-013, iniciar a **BKL-015 — dicionário definitivo de dados multiproduto**.

## Arquivos técnicos salvos neste repositório

- `telegram-gateway/src/auth.js`
- `telegram-gateway/src/check-session.js`
- `telegram-gateway/src/idempotency-test.js`
- `.env.example` sem credenciais

## Critério para não perder contexto

Antes de executar qualquer nova etapa:

1. abrir este handoff;
2. conferir BKL-012 e BKL-013 na planilha operacional;
3. não gerar nova sessão Telegram sem necessidade;
4. não colocar segredo ou dado de cliente em código, print ou chat;
5. não criar proposta real sem autorização final;
6. tratar status, ação pendente e motivo como campos separados.