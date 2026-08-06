# Contrato de dados — CBN META v1.0

## Escopo

Contrato compartilhado entre os quatro workflows do projeto n8n `CBN — Meta`.
A planilha oficial é a fila de estado. Nenhum workflow publica a partir de texto
solto, conversa ou arquivo local.

## Abas oficiais

### `Calendário Meta`

O bloco técnico começa na coluna `Y`:

| Campo | Tipo | Regra |
|---|---|---|
| `post_id` | string | Identificador estável e único. Não reutilizar. |
| `media_urls_json` | JSON array | Uma URL HTTPS pública na V1 estática. |
| `alt_texts_json` | JSON array | Reservado para acessibilidade e carrossel. |
| `publish_key` | string | Chave de idempotência estável. |
| `attempts` | inteiro | Máximo de duas tentativas totais na V1. |
| `locked_at` | ISO-8601 | Preenchido antes da chamada externa. |
| `approved_at` | ISO-8601 | Data da aprovação humana. |
| `approved_by` | string | Responsável pela aprovação. |
| `last_error_json` | JSON/string | Erro consolidado, limitado a 1.500 caracteres. |
| `row_version` | inteiro | Incrementado nas transições do publicador. |
| `instagram_status` | enum | `PUBLICADO`, `ERRO` ou vazio. |
| `facebook_status` | enum | `PUBLICADO`, `ERRO` ou vazio. |
| `instagram_url` | URL | URL registrada após publicação. |
| `facebook_url` | URL | URL registrada após publicação. |

O Publicador V1 também usa os campos editoriais `Data`, `Horário`, `Formato`,
`Legenda / roteiro-base`, `Arquivo / URL da mídia`, `Instagram`, `Facebook`,
`Aprovação`, `Status`, `ID Instagram`, `ID Facebook`, `Horário publicado` e
`Erro`.

### `Meta - Log de publicações`

Log somente por acréscimo, com as colunas:

- `Execução`;
- `Post ID`;
- `Publish Key`;
- `Canal`;
- `Status`;
- `Media ID`;
- `URL`;
- `Data/Hora`;
- `Erro`;
- `Tentativa`;
- `Detalhes`;
- `Workflow`;
- `Row Version`.

## Estados oficiais

```text
PLANEJADO_AUTOMACAO
EM_PESQUISA
ROTEIRO_PRONTO
APROVADO_PRODUCAO
MIDIA_PRONTA
APROVADO_PUBLICAR
PUBLICANDO
PUBLICADO
ERRO
PAUSADO
```

Somente `APROVADO_PUBLICAR` é elegível ao publicador.

## Regras de segurança

1. `PAUSA_GERAL` é fail-closed: qualquer valor diferente de `NAO` bloqueia.
2. A V1 funciona apenas com `MODO_TESTE=SIM`.
3. Apenas um post estático é selecionado por execução.
4. A mídia precisa ser HTTPS e publicamente acessível pela Meta.
5. A reserva é gravada antes da chamada externa.
6. `RESERVADO`, `PUBLICANDO` e `PUBLICADO` bloqueiam reenvio da mesma chave/canal.
7. Execução interrompida em `PUBLICANDO` exige revisão humana.
8. Tokens, senhas e IDs de credencial não entram no JSON versionado.
9. Um canal não mascara o erro do outro.
10. Carrossel fica fora da V1.

## Idempotência

Quando `publish_key` estiver vazio:

```text
{post_id}:{data}:{horario}:STATIC_V1
```

A chave por canal é:

```text
{publish_key}:{CANAL}
```

## Entrada mínima

```json
{
  "post_id": "cbn-meta-20260806-1800-seguranca",
  "Formato": "Post estático",
  "Aprovação": "Aprovado",
  "Status": "APROVADO_PUBLICAR",
  "Instagram": "SIM",
  "Facebook": "SIM",
  "Legenda / roteiro-base": "Legenda aprovada",
  "media_urls_json": "[\"https://cdn.exemplo.com/cbn/post.png\"]",
  "attempts": "0",
  "row_version": "0"
}
```

## Saída esperada

Sucesso completo:

```json
{
  "Status": "PUBLICADO",
  "instagram_status": "PUBLICADO",
  "facebook_status": "PUBLICADO",
  "ID Instagram": "meta_id",
  "ID Facebook": "meta_id",
  "Erro": ""
}
```

Falha parcial ou total:

```json
{
  "Status": "ERRO",
  "instagram_status": "PUBLICADO",
  "facebook_status": "ERRO",
  "last_error_json": "{\"facebook\":\"erro sanitizado\"}"
}
```
