# Dicionário de Dados — CBN Crédito

**Versão:** 1.0  
**Data:** 15/07/2026  
**Task:** BKL-015 — concluída v1

## Objetivo

Definir um vocabulário único para n8n, Gateway, banco de dados, planilha operacional e agentes, evitando mistura entre FGTS e CLT, duplicidade de propostas e exposição de dados pessoais ou credenciais.

A planilha contém o inventário detalhado `DD-001` a `DD-072`. Este documento registra as regras canônicas sem dados reais de clientes.

## Entidades

### Cliente

Pessoa atendida, independentemente da quantidade de consultas, ofertas e propostas.

Campos centrais:

- `cliente_id`;
- `nome`;
- `telefone` em E.164;
- `cpf_ref`;
- `cpf_mascarado`;
- consentimento de consulta;
- autorização de proposta por operação;
- origem do lead;
- estado da jornada;
- resumo sem dados sensíveis completos.

### Consulta

Registro de consulta de um único produto.

Campos centrais:

- `consulta_id`;
- `cliente_id`;
- `produto`;
- `operation_id`;
- status e código de retorno;
- horários;
- `retorno_bruto_ref`;
- `session_alias`.

FGTS e CLT nunca compartilham o mesmo registro de consulta.

### Oferta

Snapshot imutável da condição retornada.

Campos centrais:

- `oferta_id`;
- `consulta_id`;
- produto;
- banco;
- tabela ou plano;
- prazo ou competências;
- parcela;
- valor liberado;
- taxa e CET quando exibidos;
- seguro;
- validade;
- `snapshot_hash`;
- seleção e horário do aceite.

O agente não recalcula nem inventa condições.

### Proposta

Proposta vinculada a um produto e a uma oferta específica.

Campos centrais:

- `proposta_id`;
- `cliente_id`;
- `oferta_id`;
- `operation_id`;
- produto;
- protocolo mascarado;
- `status_raw`;
- `status_normalizado`;
- `acao_pendente`;
- `motivo_raw`;
- `link_assinatura_ref`;
- referências de documento, conta e endereço;
- `final_authorization_evidence_payload_ref`, obrigatório e vinculado a payload protegido do tipo `FINAL_AUTHORIZATION_EVIDENCE`;
- horários de criação, consulta, assinatura, aprovação e pagamento.

Status, ação pendente, motivo e link são independentes.

### Interação

Evento cronológico da jornada.

Campos centrais:

- `interacao_id`;
- data e hora;
- `cliente_id`;
- `proposta_id` quando aplicável;
- produto;
- canal e direção;
- `message_id`;
- tipo e resumo do evento;
- estado anterior e posterior;
- ator e automação.

### Pendência

Item que exige ação automática, do cliente ou humana.

Campos centrais:

- `pendencia_id`;
- `cliente_id`;
- `proposta_id` quando aplicável;
- produto;
- tipo e prioridade;
- detalhe mascarado;
- status, responsável e SLA;
- resolução mascarada.

### Operação técnica

Execução do Gateway.

Campos centrais:

- `operation_id`;
- `correlation_id`;
- cliente e produto;
- ação;
- `session_alias`;
- `random_id` quando MTProto;
- tentativa e lock;
- horários e duração;
- `outcome_code` e `error_code`;
- referências de retorno e log;
- versão do Gateway.

Ações previstas:

- `CONSULTAR`;
- `CRIAR_PROPOSTA`;
- `CONSULTAR_STATUS`;
- `REENVIAR_LINK`.

## Regras canônicas

### Separação por produto

- Consulta, Oferta e Proposta têm `produto` obrigatório.
- FGTS e CLT possuem operações, ofertas, protocolos e status independentes.
- O estado geral do cliente é derivado e não sobrescreve os subestados.

### Idempotência

- retries reutilizam o mesmo `operation_id`;
- tentativa técnica não cria nova proposta comercial;
- MTProto usa `random_id` determinístico;
- cada sessão possui uma operação ativa por vez.

### Autorização

- consentimento de consulta não autoriza proposta;
- cada proposta exige confirmação final expressa;
- sem evidência protegida válida, o banco e o Gateway bloqueiam `CRIAR_PROPOSTA`.

### Status

Campos separados:

- `status_raw`;
- `status_normalizado`;
- `acao_pendente`;
- `motivo_raw`;
- `last_checked_at`.

Falha ao consultar status não transforma a proposta em reprovada ou cancelada.

## Segurança e armazenamento

| Dado | Destino permitido | Exibição operacional |
|---|---|---|
| CPF completo | Banco criptografado ou tokenização | Somente mascarado |
| RG e documento | Storage criptografado | Referência ou máscara |
| Endereço | Storage criptografado | Somente quando necessário |
| Dados bancários | Storage criptografado | Nunca completos na planilha |
| Sessão MTProto | Cofre de secrets | Apenas `session_alias` |
| Link de assinatura | Banco protegido | Referência controlada |
| Retorno bruto | Storage protegido | Código e resumo |
| Logs | Storage protegido e mascarado | Sem segredos ou dados completos |

## Estruturas operacionais alinhadas

A BKL-015 foi concluída com as seguintes abas:

- `Clientes`;
- `Consultas`;
- `Ofertas`;
- `Propostas`;
- `Interações`;
- `Pendências`;
- `Operações Técnicas`;
- `Dicionário de Dados`.

As abas possuem cabeçalhos alinhados ao modelo, filtros, produto separado, referências entre entidades e validações iniciais para produto, direção e status de proposta.

## Estado da validação

### Confirmado no CLT

- documento, órgão, UF e data;
- COMPE, agência, conta com dígito e tipo;
- revisão e correção;
- criação e protocolo;
- status bruto de análise;
- assinatura pendente;
- motivo e link operacional.

### A confirmar no FGTS

- campos pós-oferta;
- competências retornadas;
- resumo final;
- protocolo;
- transições pós-criação.

Nenhuma regra pendente do FGTS será inferida a partir do CLT.

## Próxima tarefa

### BKL-016 — armazenamento seguro

Definir a arquitetura concreta para:

1. banco estruturado protegido;
2. criptografia e tokenização;
3. storage de documentos e retornos brutos;
4. cofre de secrets;
5. perfis de acesso;
6. retenção, anonimização e exclusão;
7. backup e recuperação.

A planilha permanecerá como camada operacional mascarada, não como repositório de dados sensíveis.
