# Migração da planilha — CBN Meta V2

## Escopo

Esta migração não foi aplicada automaticamente. Faça uma cópia de segurança e
execute-a manualmente na planilha `CBN Crédito — Fluxo Operacional` antes de
importar o workflow V2.

## Aba `Calendário Meta`

Não remova, mova ou renomeie nenhuma coluna existente. Após a coluna `AL`,
adicione exatamente:

| Coluna | Cabeçalho | Conteúdo |
|---|---|---|
| AM | `instagram_attempts` | inteiro de 0 a 3 |
| AN | `facebook_attempts` | inteiro de 0 a 3 |
| AO | `instagram_last_error_json` | erro sanitizado do Instagram |
| AP | `facebook_last_error_json` | erro sanitizado do Facebook |
| AQ | `instagram_next_retry_at` | ISO-8601 ou vazio |
| AR | `facebook_next_retry_at` | ISO-8601 ou vazio |

Linhas históricas podem permanecer vazias. O V2 interpreta tentativa vazia como
zero e considera um canal pendente quando solicitado, salvo evidência inequívoca
de publicação por status, ID ou último log válido.

Não preencha manualmente tentativas ou apague IDs/URLs já registrados.

## Aba `Automação Meta`

Use duas colunas com os cabeçalhos `Chave` e `Valor`. Adicione uma linha para
cada configuração:

| Chave | Valor inicial seguro |
|---|---|
| `PAUSA_GERAL` | `SIM` |
| `MAX_ATTEMPTS_CANAL` | `3` |
| `RETRY_1_MINUTES` | `10` |
| `RETRY_2_MINUTES` | `30` |
| `TIMEZONE` | `America/Sao_Paulo` |

Não coloque tokens, senhas, cookies, OAuth, Page Access Token ou qualquer outro
segredo nessa aba. Ausência, valor inválido ou falha de leitura encerra o fluxo
de forma fechada antes de mutação, reserva ou chamada à Meta.

## Aba `Meta - Log de publicações`

Nenhuma alteração de schema é necessária. Ela continua append-only, com as 13
colunas existentes. Não corrija nem apague registros antigos; o V2 ignora linhas
quebradas que contenham expressões literais e usa o último estado válido por
`Publish Key + Canal`.

## Checklist de verificação

- [ ] Cabeçalhos AM:AR escritos exatamente como documentado.
- [ ] Nenhuma coluna anterior foi movida.
- [ ] `PAUSA_GERAL=SIM` antes da importação.
- [ ] Cinco configurações críticas presentes e sem duplicatas.
- [ ] Nenhum segredo presente na planilha.
- [ ] Uma linha sintética preparada para o smoke test manual.
