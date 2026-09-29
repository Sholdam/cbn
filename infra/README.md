# Infraestrutura interna CBN

## Clone local com dados Railway — estado em 29/09/2026

O clone real usa [`railway-clone-compose.yml`](railway-clone-compose.yml). No
PowerShell desta máquina, com o Toshiba `FAMULUS_DATA` em `D:`, iniciar por:

```powershell
& .\infra\scripts\start-cbn-clone.ps1
```

O script mantém o WSL acordado, reabre o cofre LUKS2, confere a montagem e
inicia PgVector, Redis, Garage, Chatwoot Web e o site. Aguarda HTTP 200 do Web.
CRM: `http://127.0.0.1:3000/`; site: `http://127.0.0.1:3002/`.
Sidekiq, Telegram e workflows n8n do clone real continuam desligados.

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
