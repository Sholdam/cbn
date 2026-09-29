# Inventário de paridade — CRM CBN no Railway

## Estado verificado após reconexão — 29/09/2026

- Toshiba `D:` saudável, LUKS2 reaberto, PostgreSQL saudável e Web/site HTTP 200.
  O clone real está agora na porta 3000; a pilha sintética antiga foi parada.
- S3 local: 56/56 objetos e 10.708.446 bytes reconferidos por SHA-256.
- ActiveStorage: 64 referências; 56 S3 presentes, 2 S3 já ausentes na origem,
  2 arquivos locais no volume Chatwoot e 4 no volume Sidekiq separado. Web local
  alcança 58/64, reproduzindo a divisão original dos volumes.
- n8n: volume legível; 6 workflows, 10 credenciais, 5.091 execuções; execução
  permanece inerte. Sidekiq e Telegram também seguem desligados.
- Inicio local reproduzível por [`start-cbn-clone.ps1`](../infra/scripts/start-cbn-clone.ps1);
  parada segura por [`stop-cbn-clone.ps1`](../infra/scripts/stop-cbn-clone.ps1).

## Atualização de paridade — 29/09/2026

O inventário abaixo registra a captura inicial e contém estados locais antigos.
O checkpoint atual está em [CRM_INFRA_MIGRATION_STATUS.md](CRM_INFRA_MIGRATION_STATUS.md).
Antes da perda temporária do HD externo em 29/09 às 08:36, a comparação era:

| Componente | Evidência local | Pendente |
| --- | --- | --- |
| PgVector | backup físico verificado; versão `vector 0.8.5` e contagens de 97 tabelas, 4 usuários, 1 conta, 181 conversas, 1.952 mensagens e 52 anexos iguais à origem | revalidar após reconectar o HD |
| Redis | RDB validado e 251 chaves carregadas em `redis:8.2.1` | revalidar após reconectar |
| Chatwoot Web | imagem CBN 4.16.2, volume `/app/storage` copiado, HTTP 200 na porta 3001, base real sem onboarding | login humano e equivalência funcional completa |
| S3 | 56 objetos, 10.708.446 bytes e SHA-256 conferidos após restauração no Garage local | 6 de 64 referências de blob ausentes no S3 local; conferir se já faltavam na origem |
| n8n | volume/SQLite copiados; 6 workflows, 10 credenciais, 5.091 execuções, 3 workflows ativos no banco; imagem exata disponível | manter execução inerte até preparação segura e decisão de corte |
| Sidekiq | volume copiado; imagem Chatwoot disponível | consumidor de fila intencionalmente desligado |
| Gateway Telegram | código/commit e imagem local disponíveis | sessão e egress não ativados |
| Site CBN | código/commit da origem; HTTP 200 na porta 3002 | revalidar após reconectar |
| WAHA | inexistente no Railway deste projeto | integração adicional, separada da paridade |

Os serviços Railway usados para extração voltaram ao estado sem deploy ativo;
configuração Git, comandos de inicialização e pré-deploy do Chatwoot foram restaurados.
DNS, webhooks e corte não foram alterados.

## Captura inicial — 28/09/2026

Captura somente leitura de configuração em 28/09/2026, seguida de autorização
do usuário para iniciar serviços necessários e obter dados para o clone. Este
documento não contém valores de variáveis, IDs de clientes nem credenciais.

## Estado da origem

- Projeto CBN, ambiente `production`: nove serviços configurados, nenhum deploy
  ativo antes da extração. Os históricos recentes incluem deploys `REMOVED` e
  `FAILED`; serviço configurado não equivale a processo em funcionamento.
- PostgreSQL `pgvector/pgvector:pg18` foi iniciado para uma cópia lógica via SSH
  e desligado após a extração.
  Seu banco tem 97 tabelas públicas, quatro usuários, uma conta, 181 conversas,
  1.952 mensagens e 52 anexos. A cópia `pg_dump -Fc` foi cifrada diretamente
  com Windows DPAPI `CurrentUser` e verificada sem arquivo aberto em disco.
- Cinco volumes persistidos ainda aparecem como `READY`: n8n (~2,7 GB), Redis
  (~152 MB), Chatwoot (~84 MB), PostgreSQL (~244 MB) e Sidekiq (~83 MB).
- O bucket `chatwoot-media` na região `sjc` contém 56 objetos (~10,7 MB).
  O Chatwoot usa `ACTIVE_STORAGE_SERVICE=s3_compatible`.
- O n8n possui chave de criptografia configurada; o gateway Telegram possui
  sessão configurada. Os valores não foram exibidos nem salvos neste repositório.
- WAHA não consta entre os serviços deste projeto Railway. Sua implantação
  local é uma integração adicional solicitada no plano original, não uma
  cópia de um serviço existente neste projeto.

## Correspondência dos serviços

| Railway | Origem exata | Estado local |
| --- | --- | --- |
| PgVector | `pgvector/pgvector:pg18` | mesma imagem na base sintética; cópia lógica cifrada da origem obtida |
| Redis | `redis:8.2.1`, volume `/data`, senha | mesma versão local, mas estado da origem ainda não copiado |
| Chatwoot | `Sholdam/cbn` `main` em `11575f76132a`, Dockerfile `chatwoot-cbn`, volume `/app/storage` e bucket S3 | imagem customizada local com mesmo código e ajuste local de heap; banco e mídia ainda não restaurados |
| SideKiq | mesmo repositório, comando Railway `sleep 3600`, volume `/app/storage` | Sidekiq sintético executa a fila; estado original ainda não copiado |
| Chatwoot-CBN-v2 | mesmo commit, Web customizado, sem volume próprio | código/imagem local preparados; configuração real pendente |
| SideKiq-CBN-v2 | mesmo commit, `bundle exec sidekiq -C config/sidekiq.yml` | imagem local preparada; único consumidor deve ser escolhido no corte |
| n8n-cbn-bot | `n8nio/n8n:2.28.7`, volume `/home/node/.n8n` | imagem exata baixada; volume, chave e workflows ainda não restaurados |
| telegram-gateway-clt | branch `codex/clt-telegram-gateway`, commit `af89119da4a4`, código em `/telegram-gateway` | fonte exata extraída para `D:\CBN\source`; imagem local construída, sem sessão/egress ativo |
| cbn | branch `codex/cbn-railway-site`, commit `23b0d2fe51ca`, código em `/site` | fonte exata extraída para `D:\CBN\source`; serviço ainda não iniciado |

## Sequência restante

1. Preparar volume criptografado confiável no Toshiba e conferir a recuperação
   da chave. A tentativa de LUKS em arquivo sobre NTFS/WSL falhou; a imagem
   incompleta de 50 GB permanece em `D:\CBN\vault`, sem dados reais. O dump
   DPAPI atual depende deste usuário Windows e não substitui backup recuperável
   em outro computador.
2. Trazer os cinco volumes e os 56 objetos do bucket por canal protegido, com
   manifesto de arquivos, tamanhos e hashes. Serviços com workflows ou filas
   precisam subir de forma inerte apenas para dar acesso aos volumes.
3. Restaurar PostgreSQL, mídia e estado n8n no armazenamento protegido;
   preservar as chaves e variáveis originais fora do Git. Reconciliar dados,
   anexos, workflows, versões e endpoints.
4. Validar Chatwoot, Sidekiq, n8n, gateway Telegram e site sem mensagens,
   webhooks ou jobs de produção durante a prova. Decidir o ingresso público e
   o WAHA solicitado separadamente da paridade com este projeto Railway.
5. Preparar backup recuperável, provar restauração e decidir o corte em etapa
   própria. O início temporário do banco na origem não muda DNS nem webhooks.
