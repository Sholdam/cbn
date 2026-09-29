# Entrada Railway com CRM no Toshiba

Atualizado em 29/09/2026. O usuário escolheu manter um endereço Railway e
fazer o PC iniciar a conexão de saída. Os arquivos estão preparados localmente;
**nenhum serviço de túnel foi implantado no Railway e o cliente local não foi
iniciado**.

## Topologia preparada

```text
navegador HTTPS -> domínio *.up.railway.app -> frps no Railway (:8080)
                                             -> canal frp TLS autenticado
                                             -> frpc no WSL/Toshiba
                                             -> Chatwoot 127.0.0.1:3000
                                             -> Garage 127.0.0.1:3900

PC -> conexão TCP de saída -> Railway TCP Proxy -> frps (:7000)
```

Não é preciso abrir uma porta de entrada no roteador. O Railway continua a
receber pedidos públicos e a terminar HTTPS; a aplicação e seus dados seguem
no Toshiba. A conexão frpc/frps exige token aleatório e TLS com certificado
verificado contra a CA privada CBN. O Chatwoot de prévia tem autenticação HTTP
adicional; objetos S3 continuam protegidos por URLs assinadas. As duas rotas
compartilham o domínio: `/` vai ao CRM e `/<bucket-local>` vai ao Garage sem
reescrever caminho nem Host, requisitos para a assinatura S3.

## Artefatos locais

- [`../infra/tunnel/railway/Dockerfile`](../infra/tunnel/railway/Dockerfile):
  gateway frps a partir da imagem oficial `ghcr.io/fatedier/frps:v0.71.0`.
- [`../infra/tunnel/local/compose.yml`](../infra/tunnel/local/compose.yml):
  cliente frpc em perfil `public`, com `restart: no`; não sobe com o clone.
- [`../infra/scripts/prepare-cbn-tunnel.sh`](../infra/scripts/prepare-cbn-tunnel.sh):
  gerou CA, certificado e token em `/srv/cbn-production/secrets/frp` no LUKS.
- [`../infra/scripts/configure-cbn-tunnel.sh`](../infra/scripts/configure-cbn-tunnel.sh):
  registra o endpoint TCP e domínio Railway, quando existirem, no mesmo cofre.

As configurações frps/frpc passaram pelo validador `verify` da versão 0.71.0
com valores de exemplo. Isso não prova conexão pela rede Railway nem URLs S3.
Nenhum token, chave privada ou dado de cliente entra no Git.

## Etapas ainda necessárias

1. Revisar custo e criar um serviço gateway no projeto Railway usando o
   Dockerfile acima; atribuir primeiro um domínio Railway novo com porta HTTP
   interna `8080` e depois um TCP Proxy para a porta interna `7000`. Os domínios atuais
   `7k.up.railway.app` e `cbncredito.up.railway.app` permanecem nos serviços
   originais. Reutilizá-los exigirá uma mudança posterior de roteamento.
2. Configurar no serviço `FRP_TOKEN`, `FRP_SERVER_CERT_B64` e
   `FRP_SERVER_KEY_B64`, obtidos do cofre por canal seguro. Essa etapa envia
   credenciais ao Railway e inicia um serviço com custo; requer aprovação
   específica antes de executá-la.
3. Com domínio e endpoint TCP reais, executar `configure-cbn-tunnel.sh` no
   WSL e iniciar explicitamente o perfil `public` do frpc. A autenticação HTTP
   da prévia impede o acesso anônimo ao CRM.
4. Testar login, WebSocket, anexos e URL assinada por HTTPS. Para que o navegador
   use mídia no domínio público, ajustar `FRONTEND_URL`, `FORCE_SSL` e
   `STORAGE_ENDPOINT` do Chatwoot local de forma controlada. O estado local
   atual usa URLs `localhost` e endpoint Docker interno.
5. Definir entrada separada para o site CBN e revisar webhooks, Sidekiq,
   n8n e Telegram antes de qualquer operação pública. A cópia de segurança
   independente foi adiada a pedido do usuário e permanece um risco de corte.

O fallback é não iniciar frpc; sem cliente conectado, o gateway não encaminha
tráfego ao PC. O clone local em `127.0.0.1:3000` continua disponível.

Referências: [Railway HTTP e TCP no mesmo serviço](https://docs.railway.com/networking/tcp-proxy#using-http-and-tcp-together),
[frp HTTP](https://gofrp.org/en/docs/examples/vhost-http/),
[frp roteamento por caminho](https://gofrp.org/en/docs/features/http-https/route/)
e [frp TLS](https://gofrp.org/en/docs/features/common/network/network-tls/).
