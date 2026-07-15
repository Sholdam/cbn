# Dicionário de Dados — CBN Crédito

**Versão:** 1.0  
**Data:** 15/07/2026  
**Task:** BKL-015 — Dicionário de dados multiproduto

## Objetivo

Definir um vocabulário único para o n8n, Gateway, banco de dados, planilha operacional e agentes. O objetivo é impedir mistura entre FGTS e CLT, evitar duplicidade de proposta e proteger dados pessoais e credenciais.

A planilha operacional contém o inventário detalhado `DD-001` a `DD-072`. Este documento registra a arquitetura e as regras canônicas sem dados reais de clientes.

## Entidades

### 1. Cliente

Representa a pessoa atendida, independentemente do número de consultas, ofertas ou propostas.

Campos principais:

- `cliente_id` — UUID interno e imutável;
- `nome`;
- `telefone` normalizado em E.164;
- `cpf_ref` — referência segura ao CPF completo;
- `cpf_mascarado` — única versão permitida em planilha aberta;
- `consentimento_consulta` — evidência do aceite para FGTS + CLT;
- `consentimento_proposta` — evidência separada para cada proposta;
- `origem_lead`;
- `estado_jornada`;
- `resumo_contexto` sem dados sensíveis completos.

### 2. Consulta

Uma consulta é sempre vinculada a um único produto.

Campos principais:

- `consulta_id`;
- `cliente_id`;
- `produto`: `FGTS` ou `CLT`;
- `operation_id`;
- `status_consulta`;
- `requested_at`;
- `completed_at`;
- `retorno_bruto_ref`;
- `codigo_retorno` baseado no catálogo RET;
- `session_alias`.

Regra: FGTS e CLT nunca compartilham o mesmo registro de consulta.

### 3. Oferta

Snapshot imutável da condição retornada pelo sistema externo.

Campos principais:

- `oferta_id`;
- `consulta_id`;
- `produto`;
- `banco`;
- `tabela_plano`;
- `prazo_competencias`;
- `parcela`;
- `valor_liberado`;
- `taxa`;
- `seguro`;
- `competencias_fgts`;
- `validade_oferta`;
- `snapshot_hash`;
- `selecionada`.

Regra: o agente nunca inventa ou recalcula uma oferta. Banco, prazo, parcela, taxa, seguro e valor vêm do retorno atual.

### 4. Proposta

Uma proposta pertence a um produto e a uma oferta específica.

Campos principais:

- `proposta_id`;
- `cliente_id`;
- `oferta_id`;
- `produto`;
- `operation_id`;
- `protocolo_externo`;
- `status_raw`;
- `status_normalizado`;
- `acao_pendente`;
- `motivo_raw`;
- `link_assinatura_ref`;
- `documento_ref`;
- `dados_bancarios_ref`;
- `endereco_ref`;
- `autorizacao_final_at`;
- `last_checked_at`;
- `paid_at`.

Regra: status, ação pendente, motivo e link são campos independentes. Um retorno de análise pode coexistir com uma ação pendente de assinatura.

### 5. Interação

Evento cronológico da jornada.

Campos principais:

- `interacao_id`;
- `cliente_id`;
- `canal_direcao`;
- `message_id`;
- `tipo_evento`;
- `resumo_evento`;
- ator e horário.

O resumo nunca contém CPF, RG, conta bancária, sessão Telegram ou token completos.

### 6. Pendência

Item que exige ação automática, do cliente ou de uma pessoa.

Campos principais:

- `pendencia_id`;
- `cliente_id`;
- `proposta_id` quando aplicável;
- `tipo_prioridade`;
- `detalhe_mascarado`;
- `status_responsavel`;
- datas de criação e resolução.

Tipos previstos:

- documental;
- cadastral;
- bancária;
- técnica;
- consentimento;
- humana.

### 7. Operação técnica

Registro do trabalho executado pelo Gateway.

Campos principais:

- `operation_id`;
- `acao_produto`;
- `session_alias`;
- `random_id` quando MTProto;
- tentativa e estado do lock;
- datas de início e conclusão;
- `outcome_code`;
- `correlation_id`;
- `log_ref`.

Ações previstas:

- `CONSULTAR`;
- `CRIAR_PROPOSTA`;
- `CONSULTAR_STATUS`;
- `REENVIAR_LINK`.

## Regras canônicas

### Separação por produto

- Cada Consulta, Oferta e Proposta possui `produto` obrigatório.
- FGTS e CLT possuem `operation_id`, protocolo e status independentes.
- O estado geral do cliente é derivado dos subestados; nunca substitui os estados de cada produto.

### Idempotência

- `operation_id` é persistente durante retries da mesma operação lógica.
- Uma nova tentativa técnica não cria uma nova proposta comercial.
- Na rota MTProto, `random_id` é determinístico a partir do `operation_id`.
- Cada sessão processa somente uma operação ativa por vez.

### Autorização

- Consentimento de consulta não autoriza proposta.
- Cada proposta exige autorização final expressa após o resumo da condição.
- Sem evidência de autorização, o Gateway bloqueia a ação `CRIAR_PROPOSTA`.

### Status

Campos separados:

- `status_raw` — texto literal do sistema;
- `status_normalizado` — enum interno;
- `acao_pendente` — próxima ação;
- `motivo_raw` — motivo literal;
- `last_checked_at` — horário da consulta.

Erro de consulta de status não muda a proposta para reprovada ou cancelada.

## Segurança e armazenamento

| Dado | Armazenamento permitido | Exibição operacional |
|---|---|---|
| CPF completo | Banco criptografado ou tokenização | Somente mascarado |
| RG e dados do documento | Storage criptografado | Referência ou máscara |
| Endereço | Storage criptografado | Somente quando necessário |
| Dados bancários | Storage criptografado | Nunca completos em planilha |
| Sessão MTProto | Cofre de secrets | Apenas `session_alias` |
| Link de assinatura | Banco protegido | Referência controlada |
| Retorno bruto | Storage protegido | Código normalizado e resumo |
| Logs | Storage protegido e mascarado | Sem segredos ou documentos completos |

## Estados atuais de validação

### Confirmado no CLT

- documento e órgão emissor;
- UF emissora;
- data de emissão em `DD/MM/AAAA`;
- código COMPE;
- agência sem dígito ou possibilidade de pular;
- conta com dígito e separador;
- tipo de conta;
- revisão e correção;
- protocolo externo;
- status bruto de análise;
- ação pendente de assinatura;
- motivo e link operacional.

### A confirmar no FGTS

- campos adicionais pós-oferta;
- competências retornadas em caso real;
- resumo final literal;
- confirmação e protocolo da proposta;
- transições pós-criação.

Nenhuma regra FGTS pendente deve ser inferida a partir do fluxo CLT.

## Próximo passo

Alinhar as abas `Clientes`, `Propostas`, `Interações` e `Pendências` da planilha ao dicionário, mantendo na planilha somente identificadores, aliases, códigos, resumos e versões mascaradas. Os dados completos deverão migrar para banco protegido.