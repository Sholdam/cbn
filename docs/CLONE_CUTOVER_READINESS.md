# Prontidão do clone CBN para eventual corte

Atualizado em 29/09/2026. Este documento registra evidência e decisões pendentes;
não autoriza mudar DNS, webhooks ou iniciar mensageria.

O usuário escolheu manter um domínio Railway com túnel de saída do PC. O
gateway e o cliente foram preparados localmente, sem implantação ou exposição;
ver [`RAILWAY_TUNNEL_PLAN.md`](RAILWAY_TUNNEL_PLAN.md). A cópia de segurança
independente foi adiada pelo usuário; dados reais não serão enviados ao GitHub.

## Estado reproduzido localmente

- O Toshiba `D:` contém `Ubuntu-CBN`, Docker e o cofre LUKS2. O CRM real abre em
  `http://127.0.0.1:3000/` e o site em `http://127.0.0.1:3002/` apenas no host.
  O dashboard CBN abriu com os canais e 4 conversas abertas; a pilha sintética
  anterior foi parada sem excluir volumes.
- PostgreSQL foi restaurado de backup físico verificado, com `vector 0.8.5` e
  as mesmas contagens observadas na origem: 97 tabelas públicas, 4 usuários,
  1 conta, 181 conversas, 1.952 mensagens e 52 anexos.
- Redis 8.2.1 carregou o RDB original. O bucket contém 56 objetos e
  10.708.446 bytes, todos relidos com SHA-256 correspondente ao manifesto.
- Volumes de Chatwoot, Sidekiq e n8n foram preservados separadamente. n8n
  contém 6 workflows, 10 credenciais e 5.091 execuções. O serviço foi montado
  apenas em modo inerte; 3 workflows estavam marcados ativos no SQLite.
- A origem Railway voltou ao estado sem deploy ativo para os serviços usados na
  extração. O serviço Chatwoot voltou ao Git `Sholdam/cbn`, branch `main`, e
  aos comandos de inicialização e pré-deploy originais.
- `infra/scripts/start-cbn-clone.ps1` e `stop-cbn-clone.ps1` passaram por um
  ciclo real de parada, fechamento LUKS e retomada. O Web e o site responderam
  HTTP 200 após a retomada.

## Diferenças observadas

| Área | Evidência | Tratamento antes do corte |
| --- | --- | --- |
| S3 | 58 blobs apontam para S3; 56 objetos existem. As outras 2 chaves também não existem no bucket Railway. | Decidir se serão mantidas como referências órfãs ou recuperadas de outra fonte. |
| Disco local | 6 blobs apontam para `local`; 2 arquivos estão no volume Chatwoot e 4 no volume Sidekiq da origem. | Decidir se os 4 arquivos serão copiados para o volume Web durante uma correção explícita. Os originais seguem separados. |
| Objeto S3 | Railway oferece bucket gerenciado; local usa Garage 2.4.1 com os mesmos bytes e chaves. | Conferir upload/download por navegador e URL assinada usando o domínio final. |
| Imagem Web | Código CBN do mesmo commit; compilação local teve limite de heap Node aumentado no Dockerfile. | Comparar funções CBN e assets no navegador. |
| Rede | Portas 3000/3002 são locais; URLs, TLS e webhooks públicos não foram configurados. | Definir domínio, ingresso e egress antes de ativar conectores. |
| Processos | Sidekiq, n8n e Telegram do clone real não estão executando fluxos. A pilha sintética está parada. WAHA não existia no projeto Railway. | Escolher um único Sidekiq real, revisar workflows e sessão Telegram; tratar WAHA como integração adicional. |
| Recuperação | Chave LUKS protegida por DPAPI no perfil Windows atual; dados no único HD externo. | Criar recuperação independente e backup em outro dispositivo/destino, depois provar restauração. |

## Sequência de decisão

1. Provar login com um usuário existente, abrir conversas representativas e
   validar anexos presentes sem enviar mensagens.
2. Definir tratamento das 6 referências não acessíveis pelo Web e validar
   upload/download do S3 local em um domínio de teste.
3. Quando houver outro destino, criar backup criptografado independente,
   preservar chave de recuperação fora deste perfil Windows e provar restauração.
4. Definir ingresso público/TLS, DNS, webhooks e um único consumidor Sidekiq;
   revisar os 3 workflows n8n ativos e a sessão Telegram antes de executar.
5. Registrar uma captura final da origem e do destino sem escritas concorrentes;
   aprovar janela de corte, critérios de aceite e caminho de reversão.

Até essas decisões, a instalação local é uma cópia navegável para conferência,
sem operação pública ou automações.
