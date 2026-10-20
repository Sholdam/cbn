# Formatação de texto no WhatsApp CBN

## Escopo autorizado

O proprietário pediu consulta de exemplos pelo plugin CBN CRM, pesquisa da
formatação WhatsApp e correção da edição/envio de textos. Não autoriza disparos
de teste para clientes. Não reprocessar nem reenviar histórico.

## Diagnóstico

- Plugin instalado CBN CRM consultou 18 conversas e 206 mensagens, em leitura.
  Encontrados marcadores CommonMark, marcadores nativos WhatsApp e negritos com
  espaços antes do fechamento, além de escapes de quebra de linha. Nenhum texto
  de cliente ou dado financeiro integra este documento.
- Caixa WAHA 5 é `Channel::Api`. O editor oferecia somente negrito/itálico e
  usava regras CommonMark, onde um asterisco significa itálico.
- Conversor WAHA instalado executa regex sucessivas: asterisco simples vira
  underscore, duplo vira simples. Não protege código e URLs; não trata spans
  multilinha ou espaços internos dos delimitadores adequadamente.
- A assinatura humana é CommonMark em negrito antes da conversão. Automação
  tem remetente nulo e não recebe assinatura; manter esse controle existente.

## Implementação

Fontes em `infra/cbn-whatsapp-formatting/`:

- `patch-editor.py`: caixa 5 usa capacidades de WhatsApp no compositor da
  conversa; mantém a distinção de nota privada. Adiciona suporte a citação no
  esquema WhatsApp. Não altera o tipo real da caixa nem o transporte/API.
- `whatsappEditor.js`: regras de digitação prioritárias para `*negrito*`,
  `_itálico_`, `~tachado~`, conservando marcas combinadas e trechos de código.
  Colagem de texto sem estilo aceita sintaxe WhatsApp; HTML já formatado e
  rascunhos salvos continuam CommonMark. URLs e código são protegidos na colagem.
- `markdown-to-whatsapp.mjs`: usa o parser `markdown-it` já travado no Chatwoot;
  converte a árvore CommonMark uma vez para WhatsApp, em vez de regex em cascata.
  Trata negrito/itálico/tachado combinados, linhas, listas, citação, código e links.
  Espaços de margem ficam fora dos marcadores. Código não é reinterpretado.
- `Dockerfile.ui`: deriva da imagem atual do CRM e recompila o frontend,
  preservando ajustes anteriores e stylesheet existente. Empacota o conversor
  Node sem dependências extras de runtime.
- `Dockerfile.waha`: deriva do mesmo digest WAHA instalado, alterando somente
  o módulo de conversão Chatwoot → WhatsApp. Não atualiza versão/engine/session.

Persistência: mensagens e rascunhos seguem CommonMark; conversão WhatsApp ocorre
na saída do adaptador. Notas privadas, e-mail, canais API diferentes e mensagens
antigas não são convertidos nem regravados em lote.

## Referências oficiais

- [WhatsApp — Como formatar suas mensagens](https://faq.whatsapp.com/539178204879377/?cms_platform=web&locale=pt_BR).
- [WAHA — integração Chatwoot e conversão de content](https://waha.devlike.pro/docs/apps/chatwoot/).
- Código da versão instalada e pacote oficial npm
  `@chatwoot/prosemirror-schema@1.3.23` consultados para ordem dos plugins,
  regras de entrada e serialização do editor.

## Implantação e conferências

Implantado no VPS, com as imagens:

- Web: `cbn/chatwoot:4.16.2-cbn-whatsapp-formatting-20261020`.
- WAHA: `cbn/waha:whatsapp-formatting-20261020`.

Compose persistente atualizado. Somente web e WAHA foram recriados; worker,
banco, filas e automações preservados. Manifesto e fontes do build ficam em
`/opt/cbn/builds/whatsapp-formatting-20261020/`. Backup do compose e conversor
anterior: `before-deploy-20261020T111850Z/` dentro dessa pasta.

Compilação Vite e empacotamento Node concluídos; fonte do editor extraída da
imagem comparada com a revisão enviada antes da promoção. `git diff --check`
sem erros. Após implantação, CRM e entrypoint JS HTTP 200, três serviços ativos,
sessão WAHA `WORKING` e nenhum erro de carregamento de módulo no trecho de log
consultado. Entry publicado: `dashboard-Ca0Rlcf8.js`.

Não foram adicionados/executados testes automatizados nem enviadas mensagens
de teste a clientes. Compilação e disponibilidade não comprovam a aparência de
uma mensagem no celular; acompanhar o próximo envio real autorizado. O navegador
precisa recarregar a página para receber as novas regras do compositor.

Rollback: restaurar as imagens anteriores somente nos serviços `chatwoot-web`
e `waha`, usando o compose privado do backup como referência. Conferir antes
se houve outra alteração legítima no compose e preservá-la. Executar o compose
VPS com perfis `physical`, `web`, `waha`, `up -d --no-deps chatwoot-web waha`.
Não restaurar banco nem volume de sessão, não reenviar mensagens. Se desfizer
apenas o editor, o conversor novo continua compatível com o CommonMark anterior.
