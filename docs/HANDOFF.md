# Handoff — CBN Crédito

**Atualizado em:** 12/07/2026, encerramento da sessão de trabalho  
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

## Decisão técnica atual

A rota provisória escolhida para o MVP é:

1. API oficial da fornecedora, caso seja disponibilizada e comprovada;
2. enquanto isso, MTProto com contas de usuário separadas;
3. Telegram Web RPA apenas como contingência.

A **BKL-014** pode ser considerada concluída no escopo de decisão e prova técnica inicial.

## Segurança e arquivos locais

- A sessão MTProto permanece somente no `.env` local ou em cofre de secrets.
- O `.env` não foi enviado ao GitHub.
- Não publicar prints contendo códigos, sessão, API hash ou dados pessoais.
- O repositório é público; todos os arquivos enviados devem ser revisados para não conter segredos.

## Próxima tarefa ao retomar

**BKL-012 — Mapear a digitação de propostas FGTS e CLT.**

Retomar por:

1. revisar a aba `Mapeamento Propostas`;
2. listar campos comuns e campos específicos por produto;
3. marcar literalmente o que ainda está “A confirmar”;
4. validar formatos e mensagens do bot durante operação autorizada;
5. manter bloqueio técnico da confirmação final;
6. depois iniciar a BKL-015, dicionário definitivo de dados multiproduto.

## Arquivos técnicos salvos neste repositório

- `telegram-gateway/src/auth.js`
- `telegram-gateway/src/check-session.js`
- `telegram-gateway/src/idempotency-test.js`
- `.env.example` sem credenciais

## Critério para não perder contexto amanhã

Antes de executar qualquer nova etapa:

1. abrir este handoff;
2. conferir a BKL-012 na planilha operacional;
3. não gerar nova sessão Telegram sem necessidade;
4. não colocar segredo em código, print ou chat;
5. não criar proposta real sem autorização final.
