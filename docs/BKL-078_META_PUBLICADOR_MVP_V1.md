# BKL-078 — Publicador Meta estático — MVP V1

## Estado

Preparação concluída em branch, sem merge, deploy, ativação de workflow ou
chamada real à Meta.

- branch: `codex/meta-publicador-static-mvp`;
- workflow: `CBN META 03 — PUBLICADOR — TESTE SEGURO — V1`;
- gatilho: exclusivamente manual;
- escopo: uma publicação estática por execução;
- canais: Instagram profissional e Página do Facebook;
- credenciais: ausentes do artefato;
- carrossel, música, agendamento e métricas: fora da V1.

## Alterações na planilha oficial

A aba `Calendário Meta` recebeu o bloco técnico `Y:AL`:

- `post_id`;
- `media_urls_json`;
- `alt_texts_json`;
- `publish_key`;
- `attempts`;
- `locked_at`;
- `approved_at`;
- `approved_by`;
- `last_error_json`;
- `row_version`;
- `instagram_status`;
- `facebook_status`;
- `instagram_url`;
- `facebook_url`.

Foi criada a aba append-only `Meta - Log de publicações` para reservas,
resultados, IDs e erros por canal.

## Proteções implementadas no scaffold

1. `PAUSA_GERAL=SIM` por padrão.
2. Falha fechada se os IDs não secretos da Meta não forem configurados.
3. Seleção somente de `Aprovação=Aprovado` e `Status=APROVADO_PUBLICAR`.
4. Suporte apenas a `Formato=Post estático`.
5. Exigência de uma URL HTTPS pública.
6. Uma linha por execução.
7. Reserva antes da chamada à Meta.
8. Chave de idempotência por post e canal.
9. Máximo de duas tentativas totais por post.
10. Um retry técnico por chamada HTTP.
11. Resultado e erro separados por canal.
12. Erro sanitizado e limitado a 1.500 caracteres.
13. Workflow exportado como inativo e sem Schedule Trigger.
14. Nenhum objeto `credentials` incluído no JSON.

## Configuração necessária no n8n

Após importar o JSON:

1. selecionar a credencial Google Sheets OAuth2 nos nós da planilha;
2. criar uma credencial HTTP Header Auth para Instagram com
   `Authorization: Bearer <TOKEN>`;
3. criar uma credencial HTTP Header Auth para Facebook com
   `Authorization: Bearer <PAGE_ACCESS_TOKEN>`;
4. associar cada credencial somente aos nós do canal correspondente;
5. informar `IG_USER_ID`, `FB_PAGE_ID` e versão vigente da Graph API no nó de
   configuração;
6. manter a pausa ativa até existir uma linha de teste revisada.

## Smoke test obrigatório

1. preparar uma única linha sintética/controlada;
2. confirmar mídia e legenda;
3. confirmar URL HTTPS pública sem login;
4. alterar temporariamente `PAUSA_GERAL` para `NAO`;
5. executar manualmente uma vez;
6. voltar a pausa para `SIM`;
7. verificar o log, o calendário e os dois canais;
8. executar novamente sem resetar e comprovar ausência de duplicidade;
9. simular uma falha em um canal e comprovar erro parcial;
10. manter o workflow inativo após o teste.

## Critérios para V1.1

- importação confirmada na versão do n8n hospedada no Railway;
- IDs e erros persistidos corretamente;
- idempotência comprovada;
- recuperação manual de `PUBLICANDO` documentada;
- URLs definitivas das publicações confirmadas;
- endpoint e versão vigente da Meta confirmados;
- aprovação expressa antes de adicionar os horários 09h e 18h.

## Limitações conhecidas

- o JSON teve validação local de sintaxe e grafo, mas ainda não foi importado no
  n8n real;
- nenhuma chamada real à API foi executada;
- a URL definitiva do Instagram deve ser confirmada no primeiro teste;
- o endpoint de publicação da Página e a versão da Graph API devem ser revistos
  no ambiente antes da execução;
- música não faz parte da publicação via API desta etapa;
- imagens em Drive privado, arquivo local ou URL temporária não são elegíveis.

## Próxima ação

Importar o workflow no projeto n8n `CBN — Meta`, vincular credenciais sem
compartilhá-las no chat, manter o workflow inativo e executar um único smoke test
manual autorizado.
