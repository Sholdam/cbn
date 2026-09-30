# Entrada Railway com CRM no Toshiba

Atualizado em 30/09/2026. O usuário autorizou um gateway de baixo custo no
Railway, com conexão de saída iniciada pelo PC. **A prévia pública está ativa**
em <https://crmcbn.up.railway.app/>. O domínio longo anterior foi renomeado
por pedido do usuário. Por autorização
posterior do usuário, Basic Auth foi removido: o acesso agora abre o login
normal do CRM. Cadastro público bloqueado, APIs privadas 401 e limite de
tentativas de login 429 foram conferidos antes da remoção. O site tem prévia em
<https://crmcbn.up.railway.app/site/> no mesmo serviço.
Os domínios antigos do CRM e do site não foram movidos.

## Topologia preparada

```text
navegador HTTPS -> domínio *.up.railway.app -> frps no Railway (:8080)
                                             -> canal frp TLS autenticado
                                             -> frpc no WSL/Toshiba
                                             -> Chatwoot 127.0.0.1:3000
                                             -> Garage 127.0.0.1:3900
                                             -> site via Nginx local :3901 -> :3002

PC -> conexão TCP de saída -> Railway TCP Proxy -> frps (:7000)
```

Não é preciso abrir uma porta de entrada no roteador. O Railway continua a
receber pedidos públicos e a terminar HTTPS; a aplicação e seus dados seguem
no Toshiba. A conexão frpc/frps exige token aleatório e TLS com certificado
verificado contra a CA privada CBN. O Chatwoot usa sua autenticação própria;
objetos S3 continuam protegidos por URLs assinadas. As rotas
compartilham o domínio: `/` vai ao CRM, `/<bucket-local>` vai ao Garage sem
reescrever caminho nem Host, e `/site/` vai ao site local com remoção desse
prefixo pelo Nginx. Preservar caminho e Host no Garage é necessário para a
assinatura S3.

## Artefatos locais

- [`../infra/tunnel/railway/Dockerfile`](../infra/tunnel/railway/Dockerfile):
  gateway frps a partir da imagem oficial `ghcr.io/fatedier/frps:v0.71.0`.
- [`../infra/tunnel/local/compose.yml`](../infra/tunnel/local/compose.yml):
  cliente frpc em perfil `public`, com `restart: no`; não sobe com o clone.
- [`../infra/scripts/prepare-cbn-tunnel.sh`](../infra/scripts/prepare-cbn-tunnel.sh):
  gerou CA, certificado e token em `/srv/cbn-production/secrets/frp` no LUKS.
- [`../infra/scripts/configure-cbn-tunnel.sh`](../infra/scripts/configure-cbn-tunnel.sh):
  registra o endpoint TCP e domínio Railway, quando existirem, no mesmo cofre.

As configurações frps/frpc passaram pelo validador `verify` da versão 0.71.0.
O serviço Railway `cbn-tunnel-gateway` foi implantado a partir do Dockerfile,
com domínio HTTPS novo na porta interna 8080 e TCP Proxy na porta interna 7000.
O cliente local conectou com TLS e token. O domínio retornou 401 sem credencial,
200 na raiz e no login com credencial, uma URL S3 assinada retornou 200 e SHA-256
igual ao manifesto, e `/cable` aceitou o handshake WebSocket. A rota `/site/`
retornou HTTP 200 e HTML idêntico ao site local, sem outro serviço Railway.
Esses foram os testes da fase com Basic Auth. Após a retirada autorizada,
raiz/login/site responderam 200 sem credenciais extras, APIs privadas de
inboxes/perfil responderam 401 e listagem S3 sem assinatura respondeu 403.
O cadastro público segue bloqueado. Um login sintético foi recusado, com
HTTP 429 na 11ª tentativa para o mesmo e-mail. Isso valida controles específicos;
não constitui auditoria completa de segurança.
O Chatwoot Web
usa o domínio novo em `FRONTEND_URL` e `STORAGE_ENDPOINT`; o arquivo anterior
foi preservado no cofre como `chatwoot-local.env.pre-tunnel`. `FORCE_SSL=false`
preserva o acesso local; o HTTPS público é terminado no Railway. Nenhum token,
chave privada ou dado de cliente entra no Git.

O gateway foi observado consumindo cerca de 0,013 GB de RAM e CPU quase ociosa
logo após a ativação. O projeto CBN acumulava aproximadamente US$0,19 neste
ciclo, mas a medição curta não garante o total mensal. Conferir o uso do projeto
Railway durante a operação para manter a meta de US$5/mês.

## Operação e limites

O canal WhatsApp planejado agora é WAHA local. A ponte WAHA–Chatwoot deverá
usar a rede interna dos contêineres; a sessão WAHA sairá diretamente pela
internet deste PC. Não é necessário abrir uma rota pública para webhook da
Meta para essa integração. O canal antigo da API oficial permanece inerte.

1. Com o Toshiba conectado, executar `infra/scripts/start-cbn-public.ps1` para
   reabrir o cofre, iniciar o clone e ligar o cliente do túnel. Para retirar o
   HD, executar `infra/scripts/stop-cbn-clone.ps1`, que agora para o túnel antes
   de fechar o cofre. O ciclo parar, fechar, reabrir e publicar foi executado
   com sucesso em 29/09. Em 30/09 foram instaladas as tarefas Windows de
   keepalive e recuperação do perfil público por minuto e no logon; o início
   exige o Toshiba correto e cofre montado. A flag de manutenção preserva
   parada explícita. Início após reboot não foi exercitado nesta etapa.
2. A prévia é navegável. Na interface local do Chatwoot, uma nota privada foi
   salva e permaneceu após recarregar a conversa. Login pelo domínio público e
   fluxo completo de anexos na interface ainda não foram exercitados. URL
   assinada, handshake WebSocket e HTTP foram validados separadamente.
3. O site CBN permanece em `127.0.0.1:3002` e tem prévia em `/site/`;
   O worker limitado e a ponte WAHA estão ativos. Cinco regras de atendimento
   Chatwoot foram reativadas para entrada não privada na caixa WAHA. Sidekiq
   legado, n8n e Telegram continuam desligados; o usuário escolheu retomar
   somente as regras de atendimento do CRM nesta etapa. Os domínios originais
   `7k.up.railway.app` e `cbncredito.up.railway.app` não mudaram. O corte e a
   paridade operacional completa dependem de revisão própria.
4. A cópia de segurança independente foi adiada a pedido do usuário e
   permanece um risco de recuperação.

Ao parar `frpc`, o gateway não encaminha tráfego ao PC. O clone local em
`127.0.0.1:3000` continua disponível enquanto o Toshiba estiver montado.

Referências: [Railway HTTP e TCP no mesmo serviço](https://docs.railway.com/networking/tcp-proxy#using-http-and-tcp-together),
[frp HTTP](https://gofrp.org/en/docs/examples/vhost-http/),
[frp roteamento por caminho](https://gofrp.org/en/docs/features/http-https/route/)
e [frp TLS](https://gofrp.org/en/docs/features/common/network/network-tls/).
