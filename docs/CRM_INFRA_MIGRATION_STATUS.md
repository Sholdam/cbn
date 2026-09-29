# Migração da infraestrutura do CRM CBN

## Checkpoint atual — 29/09/2026 09:16 BRT

**O Toshiba foi reconectado e o clone local voltou a funcionar.** O Windows reconheceu `D:` (`FAMULUS_DATA`, NTFS saudável); WSL, Docker e o cofre LUKS2 reabriram. Um processo WSL oculto mantém a distro ativa nesta sessão. O script [`start-cbn-clone.ps1`](../infra/scripts/start-cbn-clone.ps1) agora valida disco/montagem e inicia apenas os componentes locais sem automações; [`stop-cbn-clone.ps1`](../infra/scripts/stop-cbn-clone.ps1) foi preparado para parada e desmontagem segura antes de remover o HD.

Os dois scripts passaram por um ciclo real de parada, sincronização, desmontagem, fechamento do LUKS, nova abertura e reinício. Após alguns segundos de inicialização, Chatwoot e site retornaram HTTP 200; o cofre permaneceu montado no mapper esperado. O Web pode recusar conexões enquanto o Puma ainda inicia.

**Porta atual:** a pilha sintética foi parada sem excluir seus volumes. O clone real foi colocado em `http://127.0.0.1:3000/`, e a aba local abriu o dashboard da conta CBN com canais e 4 conversas abertas. O site segue em `http://127.0.0.1:3002/`. As referências à porta 3001 abaixo descrevem a fase anterior de validação.

- PostgreSQL físico voltou saudável após desligamento limpo; Rails leu uma conta, 181 conversas e 1.952 mensagens. Chatwoot Web retornou HTTP 200, sem onboarding. Site CBN retornou HTTP 200. Redis iniciou com a cópia RDB; após o Web operar, `DBSIZE=262`, incluindo chaves criadas na validação local.
- Garage leu de volta os 56 objetos, 10.708.446 bytes, todos com SHA-256 igual ao manifesto. O volume n8n está acessível na imagem `n8nio/n8n:2.28.7` sem executar workflows; SQLite confirma 6 workflows, 10 credenciais, 5.091 execuções e 3 workflows marcados ativos.
- A reconciliação de anexos está fechada: 64 registros ActiveStorage = 58 `s3_compatible` + 6 `local`. Os 56 objetos S3 exportados correspondem a 56 registros; **dois objetos S3 já faltavam no bucket Railway**. No Web, dois dos seis arquivos `local` estão no volume Chatwoot; os quatro restantes estão no volume Sidekiq separado da origem. Mantivemos os volumes separados para preservar fielmente o estado da origem. Assim, o Web local encontra 58/64 arquivos, como a topologia original sugere. Nenhum arquivo ausente foi fabricado.
- O Sidekiq do clone real, Telegram e a execução n8n permanecem desligados; DNS, webhooks, mensageria e corte continuam inalterados. A pilha sintética anterior está parada. A cópia local é navegável para validação interna, ainda sem equivalência operacional completa nem backup independente da chave de recuperação. Não usar o HD como único backup.

Decisões e sequência de aceite: [`CLONE_CUTOVER_READINESS.md`](CLONE_CUTOVER_READINESS.md).

## Interrupção anterior — 29/09/2026

Após a reinicialização das 08:36, o disco D: desapareceu do Windows e o clone ficou indisponível até a reconexão física. O histórico abaixo registra o estado durante essa interrupção e em 28/09.

- A distro `Ubuntu-CBN` e o Docker estão em `D:\CBN\wsl\Ubuntu-CBN\ext4.vhdx`. O cofre LUKS2 nativo, dentro desse disco ext4, foi criado e seu fechamento e reabertura com chave protegida por DPAPI foram comprovados. Os dados reais ficaram apenas no cofre montado em `/srv/cbn-production`; não foram gravados no repositório. A chave ainda depende deste perfil Windows e precisa de recuperação independente antes de qualquer corte.
- O PostgreSQL foi copiado por `pg_basebackup`, verificado por `pg_verifybackup` e iniciado com a mesma imagem `pgvector/pgvector:pg18`. O cluster restaurado preservou `vector 0.8.5` e bateu com a origem em 97 tabelas públicas, quatro usuários, uma conta, 181 conversas, 1.952 mensagens e 52 anexos. O dump lógico cifrado continua como cópia adicional.
- O volume Redis foi extraído e o RDB passou em `redis-check-rdb`: 251 chaves, 84 expirações, checksum válido. A instância local `redis:8.2.1` carregou as 251 chaves numa rede Docker interna, sem porta pública.
- Os volumes n8n, Chatwoot e Sidekiq foram extraídos para o cofre. O n8n preserva 6 workflows, 10 credenciais e 5.091 execuções; três workflows constavam como ativos no banco SQLite, portanto o serviço local permanece inerte. A imagem `n8nio/n8n:2.28.7` e o volume foram montados em contêiner sem executar `n8n start`.
- O bucket Railway foi copiado com manifesto de SHA-256: 56 objetos e 10.708.446 bytes. Um bucket local S3 compatível Garage `v2.4.1` no cofre recebeu os 56 objetos; todos foram lidos de volta com SHA-256 idêntico. Garage está limitado ao loopback e não tem exposição pública. A compatibilidade com o aplicativo foi comprovada em parte: Rails encontrou 58 de 64 registros de blob no S3 local. Os seis registros restantes exigem comparação final com o bucket de origem; a consulta foi interrompida quando o HD saiu do sistema.
- A imagem Chatwoot CBN 4.16.2 foi construída a partir do código da origem com ajuste local no limite de memória da compilação. O Web local abriu em `http://127.0.0.1:3001/` com o banco real, sem onboarding; `Account.count=1`, 181 conversas e 1.952 mensagens. O site CBN do commit de origem abriu em `http://127.0.0.1:3002/`. Essas URLs ficaram indisponíveis com a ausência do HD. A pilha sintética anterior continua separada na porta 3000.
- O gateway Telegram foi construído a partir do commit da origem, mas não foi iniciado. Sidekiq e automações n8n permanecem desligados para impedir consumo de filas e disparos. WAHA não existe no projeto Railway e continua uma integração adicional.
- Na origem Railway, PgVector, Redis, n8n, SideKiq e Chatwoot foram ligados temporariamente apenas para extração e depois desligados. Os comandos, `preDeployCommand` e a conexão Git originais do Chatwoot foram restaurados. O último estado observado era sem deploy ativo dos serviços extraídos. DNS, webhooks e roteamento público não foram alterados.
- A primeira tentativa de imagem LUKS diretamente sobre NTFS deixou `D:\CBN\vault\cbn-production.img` de 50 GB sem dados reais. A revisão automática bloqueou sua remoção com `blocked by policy`; o arquivo segue no HD e requer limpeza manual quando ele reaparecer. O cofre funcional é o LUKS nativo dentro de `ext4.vhdx`.
- Após reconectar o disco: conferir integridade NTFS/WSL/LUKS, reabrir o cofre, verificar PostgreSQL, Redis, Garage, Chatwoot, site e n8n inerte; concluir a comparação dos seis blobs e preparar chave/backup recuperáveis. Só então avaliar paridade funcional e um eventual corte, com aprovação própria.

## Registro anterior — 28/09/2026

**Naquele momento a fundação sintética estava saudável no HD externo, o inventário Railway estava atualizado e a cópia protegida do PostgreSQL havia sido obtida. O clone real ainda não tinha sido restaurado.**

## Objetivo

Preparar um clone blue/green fiel do CRM atualmente implantado no Railway: preservar serviços, versões, configurações, workflows, integrações, banco/pgvector, anexos e sessões autorizadas, sem substituir componentes por alternativas simplificadas. A máquina local será o destino operacional. Registrar separadamente qualquer adaptação inevitável de rede/ingresso e validar equivalência funcional antes do corte. O WAHA deve sair diretamente pela conexão local brasileira; túneis servem apenas para entrada.

## Proteções vigentes

- A autorização posterior do usuário permite iniciar serviços necessários e obter o estado para o clone. Registrar cada mudança temporária na origem e encerrar o serviço após a extração; não iniciar workflows ou filas com efeitos externos.
- Não alterar DNS/webhooks, ativar workflows, iniciar disparos, nem fazer cutover sem aprovação separada.
- Dados reais extraídos ficam somente em staging criptografado. A aplicação em BKL-016 e a operação produtiva do clone ainda dependem dos gates externos próprios.
- Nunca versionar `.env`, credenciais, sessões, dados reais, dumps ou arquivos de backup.
- Preservar `chatwoot-cbn/Dockerfile` e os patches CBN; Chatwoot web e Sidekiq devem usar a mesma imagem customizada.
- Manter Postgres/Redis privados e apenas um Sidekiq consumindo filas no corte.
- n8n precisa iniciar com os workflows inativos e sem disparos externos durante validação.

## Progresso

- **Etapa 0 — auditoria:** concluída; Railway consultado em modo de leitura. Nenhuma alteração de produção ou transferência de dados foi feita.
- **Etapa 1 — servidor:** WSL2 2.7.14 validado após reinicialização. O Toshiba (`D:`, volume `FAMULUS_DATA`) está saudável; `D:\CBN`, `D:\CBN\wsl` e `D:\CBN\backups` estão criadas. Ubuntu 24.04.5 LTS amd64 foi obtido da Canonical, SHA-256 conferido com o manifesto oficial e importado como `Ubuntu-CBN` em `D:\CBN\wsl\Ubuntu-CBN`; o disco virtual `ext4.vhdx` fica no HD externo. systemd foi habilitado. Docker Engine 29.8.1, Compose 5.5.1, Buildx e containerd foram instalados na distro; `docker run --rm hello-world` concluiu. Imagens, camadas e volumes padrão do Docker ficam dentro do disco WSL no Toshiba. O runtime WSL usou fallback `VirtioProxy` após aviso de configuração de rede NAT; apt, pull de imagens e acesso HTTP local funcionaram. Um processo WSL oculto mantém a distro acordada durante o uso; `wsl --terminate Ubuntu-CBN` o encerra e para os serviços. O HD precisa permanecer conectado.
- **Composição sintética:** imagem Chatwoot CBN 4.16.2 construída após limitar o heap de Node a 4 GiB na pré-compilação. Postgres 18 com pgvector, Redis 8.2.1, Chatwoot Web e um Sidekiq foram iniciados; banco sintético vazio foi preparado com `rails db:chatwoot_prepare`. Os quatro serviços ficaram saudáveis sem reinícios. A interface respondeu em `http://127.0.0.1:3000/` com redirecionamento para `/installation/onboarding`; nenhuma conta foi criada. `infra/.env` contém apenas chaves aleatórias descartáveis e é ignorado pelo Git. Postgres, Redis e Sidekiq ficam na rede interna; só Chatwoot Web também está na bridge `frontend`, com porta publicada apenas no loopback.
- **Escopo confirmado pelo usuário:** fazer um clone fiel do Railway atual. A composição sintética é apenas a fundação de validação e não representa o clone concluído. Antes de promovê-la a destino, comparar inventário, imagens/versões, variáveis, serviços, volumes, integrações e estado de dados com uma captura atual da origem; preservar valores de produção por canal seguro e nunca registrá-los no repositório ou em logs.
- **Conferência após reinicialização:** `infra/scripts/status.sh` confirmou os quatro serviços como `running/healthy`; a consulta local confirmou a extensão `vector`; e o host recebeu HTTP 302 para `/installation/onboarding`. n8n, WAHA, MinIO/Storage, gateway Telegram e gateway público continuam ausentes da composição e marcados como pendentes pelos gates de configuração descritos abaixo.
- **Inventário atual da origem:** os nove serviços configurados estavam sem deploy ativo antes da extração. Cinco volumes e um bucket permanecem preservados; o bucket S3 `chatwoot-media` contém 56 objetos (~10,7 MB). WAHA não está neste projeto Railway. A fonte do gateway Telegram foi localizada no commit implantado `af89119da4a4`, e a do site no commit `23b0d2fe51ca`; ambas foram extraídas para `D:\CBN\source`. A imagem local do gateway foi construída e `n8nio/n8n:2.28.7` baixada. Detalhes sem segredos: [`RAILWAY_PARITY_INVENTORY.md`](RAILWAY_PARITY_INVENTORY.md).
- **Extração autorizada:** PgVector foi iniciado temporariamente no Railway. A leitura confirmou 181 conversas, 1.952 mensagens e 52 anexos. `pg_dump -Fc` via SSH gerou uma cópia DPAPI `CurrentUser` em `D:\CBN\backups`, com leitura cifrada conferida e sem dump aberto no disco. Uma chave SSH exclusiva CBN foi registrada na conta Railway. PgVector foi desligado após a extração e voltou a não ter deploy ativo. Nenhum outro serviço de origem foi iniciado até esta atualização.
- **Proteção do destino:** uma tentativa de criar contêiner LUKS de 50 GB em `D:\CBN\vault\cbn-production.img` ficou presa na formatação de ext4 sobre loop/NTFS no WSL. A distro foi encerrada e reiniciada; os quatro serviços sintéticos voltaram a ficar saudáveis e HTTP 302 para onboarding foi confirmado. O contêiner incompleto permanece no HD, ocupa 50 GB e não contém dados reais; não deve ser montado ou usado. O apagamento automático foi recusado pela política de execução. Restam cerca de 765 GB livres. A chave de teste protegida por DPAPI permanece em `%USERPROFILE%\.cbn\vault.key.dpapi`. A restauração de dados reais aguarda um armazenamento criptografado confiável, por exemplo BitLocker com chave de recuperação preservada.
- **Etapas restantes:** restaurar em armazenamento protegido, copiar volumes e bucket, preservar segredos/sessões, comprovar paridade e recuperação; cutover em etapa separada.

## Pendências para completar o clone fiel

1. Continuar observando a estabilidade do HD Toshiba durante uso prolongado e mantê-lo conectado antes de iniciar WSL/Docker.
2. Concluído: Ubuntu 24.04 LTS verificado/importado em `D:\CBN\wsl`; Docker Engine e Compose instalados na distro WSL do HD externo; composição sintética validada em runtime.
3. Concluído: captura de serviços, versões, comandos, volumes, variáveis por nome e commits da origem; comparar com o destino usando o inventário de paridade.
4. Preparar área criptografada confiável no Toshiba; a tentativa LUKS sobre loop/NTFS falhou. A cópia DPAPI atual depende deste usuário Windows e ainda não é backup portátil. Definir storage S3 compatível após medir/copiar o bucket e atender criptografia em repouso.
5. WAHA não existe neste projeto Railway. Preparar a integração solicitada no plano sem apresentá-la como parte do clone atual.
6. Concluído: commit do gateway Telegram identificado e imagem local construída. Ainda faltam sessão protegida, endpoints e validação sem envio real.
7. Mapear ingresso, DNS, webhooks e egress do clone; ajustar somente o que a rede local exigir e manter o comportamento equivalente. Nenhuma mudança de DNS/webhook nem escolha de gateway até fechar esse mapa.
8. A autorização desta conversa cobre a extração para staging protegido; aplicação em BKL-016 e ativação produtiva ainda dependem dos gates de segurança e revisão correspondentes.
9. Backups recuperáveis, teste de restauração e validação ponta a ponta do clone antes de considerar cutover. Registrar e reverter inícios temporários de serviços na origem.

Referências consultadas em 25–28/09/2026: [MinIO Community](https://github.com/minio/minio), [AIStor Free — licenças/criptografia](https://docs.min.io/aistor/operations/licenses/), [WAHA Plus/Core](https://waha.devlike.pro/docs/how-to/waha-plus/), [Ubuntu 24.04 cloud image](https://cloud-images.ubuntu.com/releases/noble/release/), [importar distro WSL](https://learn.microsoft.com/en-us/windows/wsl/use-custom-distro).

O relatório local detalhado da Etapa 0 não deve ser publicado. O presente documento registra somente progresso e guardrails, sem IDs de serviço, endpoints privados ou valores secretos.
