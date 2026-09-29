# WAHA local e Chatwoot CBN

## Estado preparado em 29/09/2026

O usuário autorizou WAHA para o mesmo número comercial do canal legado,
com aparelho disponível. A sessão ainda precisa ser pareada por QR.

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

Regras automáticas `1,3,4,5,6` foram pausadas no clone; a lista original
está no estado privado da integração. Autoatribuição, saudação, CSAT e
coleta de e-mail estão desativados na nova caixa. Não ligar essas regras
sem revisar seu alcance e as respostas que enviam.

## Início e parada

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
