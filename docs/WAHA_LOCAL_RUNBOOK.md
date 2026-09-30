# WAHA local e Chatwoot CBN

## Estado conectado em 29/09/2026

O usuário autorizou WAHA para o mesmo número comercial do canal legado e
concluiu a leitura do QR. A sessão ficou `WORKING`; a identidade foi
comparada ao número esperado sem imprimir o identificador.

Teste de texto: conversa `185`, saída `2208` com estado `read`, entrada
`2209`. Um mapeamento por direção no banco WAHA e contato existente
reutilizado. O container foi reiniciado e retomou `WORKING` sem QR.
Foto de teste `2217` recebida e salva. Com autorização adicional, a mesma
foto foi devolvida como `2222` e ficou `read`, com um mapeamento WAHA.
Fotos/miniaturas responderam HTTP 200 local e publicamente com autenticação;
áudio de teste respondeu HTTP 206 com Range nas duas superfícies.
O checkpoint privado está em `secrets/waha-test.json`; não repetir os
envios iniciais.

O build offline do Vite concluiu, e web/worker usam
`cbn/chatwoot:4.16.2-cbn-waha-media` (imagem
`sha256:2a4161519d3deeb925c8e5c265c5b8c69b6562b7e0c80a066d805cd567f69220`).
Fontes corrigidas e manifest dos assets foram conferidos nos containers.
Fotos renderizaram na interface após a correção do proxy. A política do
navegador bloqueou a última conferência automatizada do player; depois disso,
o usuário testou manualmente envio, recebimento e reprodução de áudio e
confirmou todos funcionando. A pendência funcional de áudio está encerrada
por essa confirmação; não houve novo envio de teste pelo agente.

Houve reinício inesperado do WSL após o build, com causa ainda desconhecida.
`start-cbn-public.ps1` recuperou cofre, CRM, site, túnel e WAHA; a sessão
retornou a `WORKING` com identidade, sem QR, e os dois envios permaneceram
`read`. O helper temporário de pareamento já foi encerrado.

- WAHA 2026.9.1 CORE, engine GOWS, imagem oficial fixada por digest no Compose.
- Sessão `default`, app Chatwoot, nova caixa `CBN WhatsApp (WAHA)` / inbox `5`.
- WAHA sai pela rede normal do PC. Nenhum proxy está configurado na sessão.
  Railway serve somente a entrada pública do CRM/site.
- Sessões, mídia, banco do app e Redis persistem no cofre
  `/srv/cbn-production/waha`. Credenciais e estado ficam em `secrets/`,
  com permissões restritas. Nunca copiar esses arquivos para Git.
- Usuário técnico é agente e membro da nova caixa; a criação dos atributos
  usou permissão administrativa temporária, removida após provisionamento.
- Grupos, status e canais WhatsApp são ignorados nesta etapa; não foi
  solicitado importar em massa o histórico do celular.

## Filas e automações

O ambiente original Chatwoot está preservado em
`secrets/chatwoot-local.env.pre-waha`. O ambiente local agora aponta para
Redis DB `1`, que estava vazio na troca. A DB `0` continua preservada.

`chatwoot-waha-worker` consome somente `critical`, `medium` e
`active_storage_analysis`, com concorrência `2` e agenda vazia. O entrypoint
recusa iniciar se a DB não for `1` ou faltar o destino da nova caixa.
Não habilitar `high`, mailers, cron, n8n ou worker legado durante a conexão.

Regras automáticas `1,3,4,5,6` foram pausadas durante o pareamento. Após os
testes, o usuário autorizou reativá-las; elas estão ativas somente na caixa
WAHA `5`, para entrada não privada com os conteúdos originais. A saudação
com duas alternativas usa lista no mesmo filtro, sem `OR` que ultrapasse
o filtro de caixa/tipo. A ativação não reprocessa mensagens históricas.
Autoatribuição, saudação própria da caixa, CSAT e coleta de e-mail continuam
desativados; a saudação é enviada pela regra existente. n8n/Telegram ficam
desligados por escolha expressa do usuário nesta etapa.

O usuário também autorizou remover os outros usuários humanos, mantendo
proprietário `1` e conta técnica WAHA `7`. API da integração reconferida:
HTTP 200. Não excluir a conta técnica nem compartilhar o login principal.
O endereço público agora usa somente autenticação própria do CRM; cadastro
público está bloqueado, APIs privadas recusam acesso anônimo e limite de
tentativas de login foi exercitado com identidade sintética.

## Início e parada

A imagem local com suporte às URLs relativas de mídia é construída a partir
da imagem CBN 4.16.2 já preservada. O ajuste é aplicado ao código fonte e o
Vite recompila os assets com novos nomes, sem editar bundles minificados:

```powershell
wsl.exe -d Ubuntu-CBN -u root -- docker build -t cbn/chatwoot:4.16.2-cbn-waha-media -f /mnt/c/Users/GUILHERME/OneDrive/Documentos/ChatGPT/CBN/cbn-infrastructure-migration/infra/chatwoot-media.Dockerfile /mnt/c/Users/GUILHERME/OneDrive/Documentos/ChatGPT/CBN/cbn-infrastructure-migration/infra
```

O build usa dependências já disponíveis no cache local (`pnpm --offline`)
e não usa credenciais ou banco de produção. `node_modules` é temporário em
memória para reduzir operações pequenas no HD externo. Web e worker precisam usar a
mesma imagem. O helper de áudio deve resolver URLs relativas usando a
origem da página; sem esse ajuste, `new URL` recusa o caminho proxy.

No Windows, na raiz do repositório:

```powershell
& .\infra\scripts\start-cbn-public.ps1
```

O início do clone reconhece o estado WAHA já provisionado e inicia WAHA,
Redis próprio e o worker limitado. Para somente iniciar esses componentes,
com cofre e Chatwoot já disponíveis:

```powershell
& .\infra\scripts\start-cbn-waha.ps1
```

Antes de retirar o HD:

```powershell
& .\infra\scripts\stop-cbn-clone.ps1
```

A parada inclui worker, WAHA e Redis antes de sincronizar e fechar o cofre.

## Pareamento

A API e o painel administrativo estão somente em loopback `3003`, com
credenciais privadas. Não colocar a chave em URL ou repassá-la ao navegador.

A página temporária `http://127.0.0.1:3004/` serve somente QR e estado,
sem expor a chave. Ela é criada pelo helper:

```powershell
wsl.exe -d Ubuntu-CBN -u root -- python3 -u /mnt/c/Users/GUILHERME/OneDrive/Documentos/ChatGPT/CBN/cbn-infrastructure-migration/infra/scripts/cbn-waha-pairing.py
```

Iniciar a sessão `default` pela API autenticada antes de abrir a página.
No celular comercial: **Aparelhos conectados → Conectar um aparelho**.
Ler o QR e aguardar `WORKING`. O código se atualiza; se a sessão expirar
para `FAILED`, a página aberta solicita renovação somente dessa sessão,
limitada a dez tentativas por execução do helper. Se esgotar, fechar e
reabrir o helper para uma nova tentativa assistida. Fechar o helper
temporário quando acabar o pareamento.

## Conferência após parear

1. Conferir, sem imprimir o número, que a identidade `me` corresponde ao
   número comercial esperado. Se divergir, parar a sessão e corrigir.
2. Receber mensagem do aparelho de teste na nova caixa.
3. Responder uma vez pelo CRM ao contato de teste e conferir entrega,
   sem reativar Meta ou executar filas herdadas.
4. Conferir anexo, mapeamento de contato e persistência da sessão.
5. Registrar resultado sem telefone, texto privado, QR ou credenciais.

A caixa antiga `CBN Api` continua com seu histórico. A nova caixa recebe
os eventos WAHA; não alterar o tipo do canal antigo nem apagar conversas.

## Ponte interna

`infra/cbn-local-media.rb` mantém a leitura/gravação de objetos do servidor
na rede local Garage e preserva assinaturas públicas dos uploads diretos.
Fotos, miniaturas e áudio usados pela interface têm caminhos proxy relativos,
que usam a origem da página e evitam outro desafio BasicAuth ao acessar pelo
localhost. A página pública mantém sua autenticação normal.

O worker transforma somente anexos da caixa WAHA no webhook interno em URLs
proxy absolutas `http://chatwoot-web:3000`, preservando extensão/MIME. A
leitura desses anexos não precisa atravessar o Railway. Integrações externas
legadas ainda inativas devem revisar o uso de caminhos relativos antes de
serem reativadas.

O webhook da caixa aponta para o container WAHA pela rede Docker.
O initializer `infra/waha-local-webhook.rb` autoriza somente POST para a
URL exata provisionada, com host `waha`, porta `3000`, caminho do app,
sem query, credencial na URL ou redirecionamento. As demais chamadas
mantêm a filtragem SSRF padrão de Chatwoot. Não ativar uma exceção global
de acesso privado para resolver essa ponte.

Provisionamento é separado em etapas (`isolate`, `chatwoot`, `app`) em
`infra/scripts/provision-cbn-waha.py`; após `isolate`, recriar Chatwoot Web
para que leia DB `1` antes das demais etapas. Elas preservam segredos
existentes e não imprimem tokens. Não repetir criação manual de caixa,
conta técnica ou app se o estado privado já existe.

## Pendências preservadas

Backup independente foi adiado pelo usuário. Não publicar dumps reais,
mídia, sessão WhatsApp ou segredos no GitHub. O processamento legado e
a validação completa do clone continuam pendentes de tarefas próprias.
