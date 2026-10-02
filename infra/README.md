# Infraestrutura interna CBN

## Túnel de entrada Railway — prévia ativa

O desenho para manter um endereço Railway com o CRM neste PC está em
[`../docs/RAILWAY_TUNNEL_PLAN.md`](../docs/RAILWAY_TUNNEL_PLAN.md).
As configurações locais ficam em `tunnel/`; credenciais estão no cofre LUKS.
O gateway `cbn-tunnel-gateway` foi implantado no Railway. Para iniciar o clone
e sua entrada pública após conectar o Toshiba:

```powershell
& .\infra\scripts\start-cbn-public.ps1
```

O endereço retornado abre o login normal do CRM. A senha HTTP extra foi
retirada por autorização do usuário após conferir autenticação, cadastro
público bloqueado e limite de tentativas de login.
O site tem prévia em `<endereço retornado>/site/` no mesmo gateway.
O helper antigo de cópia da senha informa que a proteção extra está desativada.
O endereço ativo é <https://crmcbn.up.railway.app/>. As cinco regras de
atendimento Chatwoot estão ativas na caixa WAHA; fluxos n8n continuam desligados.

## Recuperação automática instalada em 30/09/2026

`CBN-WSL-Keepalive` mantém o WSL ativo fora do terminal/chat.
`CBN-Service-Recovery` confere serviços por minuto e no logon do proprietário,
recuperando o perfil público com o Toshiba correto e o cofre montado.
Reinstalação nesta máquina:

```powershell
& .\infra\scripts\install-cbn-service-recovery.ps1
```

A parada segura grava `%USERPROFILE%\.cbn\maintenance.flag` e suspende a
recuperação até um início manual. Eventos ficam em `.cbn/service-recovery.log`.
Não habilitar restart Docker indiscriminado: containers precisam do cofre
montado antes de iniciar, para não criar dados fora do volume criptografado.
Sem energia, internet, HD ou logon após reboot, a recuperação não garante acesso.

Após a recuperação de 02/10/2026, o helper do cofre confirma a montagem no
namespace da sessão WSL, do systemd e do Docker antes de iniciar containers.
A parada segura desmonta todas essas vistas antes de fechar o cofre.
O início manual aguarda até cinco minutos para o boot frio do Rails.
O registro do incidente está em
[`../docs/CRM_DISK_RECOVERY_2026-10-02.md`](../docs/CRM_DISK_RECOVERY_2026-10-02.md).

## Clone local com dados Railway — estado em 29/09/2026

O clone real usa [`railway-clone-compose.yml`](railway-clone-compose.yml). No
PowerShell desta máquina, com o Toshiba `FAMULUS_DATA` em `D:`, iniciar por:

```powershell
& .\infra\scripts\start-cbn-clone.ps1
```

O script mantém o WSL acordado, reabre o cofre LUKS2, confere a montagem e
inicia PgVector, Redis, Garage, Chatwoot Web e o site. Aguarda HTTP 200 do Web.
CRM: `http://127.0.0.1:3000/`; site: `http://127.0.0.1:3002/`.
O worker limitado WAHA inicia se a integração já estiver provisionada.
O Sidekiq legado, Telegram e workflows n8n continuam desligados.

Antes de desconectar o HD, usar:

```powershell
& .\infra\scripts\stop-cbn-clone.ps1
```

Essa parada sincroniza e fecha o cofre. O ciclo parar/iniciar foi executado com
êxito em 29/09. Dados e segredos reais ficam apenas no cofre; nenhuma variável
de produção pertence ao Git. O estado de paridade e os limites estão em
[`../docs/CRM_INFRA_MIGRATION_STATUS.md`](../docs/CRM_INFRA_MIGRATION_STATUS.md).

## Fundação sintética anterior — parada

`docker-compose.yml` é apenas uma base local descartável para Postgres/pgvector,
Redis e o **Chatwoot customizado CBN**. Todos os serviços ficam atrás do perfil
`synthetic`. Postgres, Redis e Sidekiq usam somente a rede interna `backend`;
apenas o Chatwoot Web também conecta à rede bridge `frontend`, necessária para
publicar `127.0.0.1:3000` no host. Sem perfil, `docker compose up` não inicia
serviços.

Esta composição **não é o clone real**. Em 28/09/2026 ela foi construída
e validada com banco local vazio e dados sintéticos; a interface abre o
onboarding inicial. Foi parada em 29/09 para liberar a porta 3000; seus volumes
foram preservados. Não importe dados ou volumes Railway. O Chatwoot Web e o
único Sidekiq compartilham a imagem customizada construída de
`../chatwoot-cbn/Dockerfile`.

## Preparação local posterior

1. Conectar o Toshiba, iniciar `Ubuntu-CBN` em WSL2 e confirmar que o Docker está
   ativo. O HD contém a distro, imagens e volumes; desligá-lo encerra o ambiente.
2. Se ainda não existir, copiar `.env.example` para `.env` e gerar valores
   **descartáveis e sintéticos**. O `.env` não pode entrar no Git.
3. Validar antes de criar volumes:

   ```bash
   cd infra
   cp .env.example .env
   docker compose --profile synthetic config
   docker compose --profile synthetic build
   ```

4. Somente com o clone real parado e a porta 3000 livre: para inicializar um banco sintético novo, executar
   `docker compose --profile synthetic run --rm --no-deps chatwoot-web bundle exec rails db:chatwoot_prepare`;
   depois subir com `docker compose --profile synthetic up -d`. Verifique os
   healthchecks antes de abrir `http://127.0.0.1:3000/`.

## Observações históricas da composição sintética

- **Object storage:** não fixar ainda; medir o bucket de origem e decidir
  criptografia/licença. A distribuição open-source MinIO está arquivada; o
  AIStor Free tem limite de nó único e não oferece criptografia em repouso.
- **n8n:** não montar/restaurar até existir uma proteção verificável que deixe
  todos os workflows inativos e bloqueie disparos externos na primeira subida.
- **WAHA:** nenhuma instância atual foi encontrada. A imagem pública atual uniu
  as antigas edições; escolher versão/engine e guardar sessões em volume próprio
  após validar a política e preparar pareamento novo.
- **Telegram Gateway:** o código neste repositório é uma prova de conceito CLI,
  sem servidor HTTP. Identificar o código/commit do deployment antes de
  containerizar.
- **Caddy/túnel/gateway:** definir a entrada pública somente depois de resolver
  a divergência entre manter Railway como gateway e desligá-lo por completo.

O arquivo `.env` real, banco, anexos, dados de sessão e backups ficam fora do Git.
Depois da instalação local do Docker, rode `bash infra/scripts/status.sh` para
ver os containers locais; esse comando não verifica o Railway.
