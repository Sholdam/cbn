# Conexão compartilhada SDR e Rebeca — 02/11/2026

## Resultado

Criada e autenticada, a pedido de Guilherme, uma única identidade operacional para os dois projetos:

- CRM: `https://crm.cbncredito.tech`, conta `1`, na VPS atual da CBN.
- Usuário: **CBN IA — SDR e Rebeca**, ID **9**, nome de exibição **Rebeca**.
- Papel **agent**, vínculo somente com a caixa **5 — CBN WhatsApp (WAHA)**.
- Disponibilidade offline para não entrar como atendente disponível na distribuição comum. A API continua funcionando.
- Conta WAHA ID 7, conta humana e demais caixas preservadas. O usuário 8 encontrado na caixa é um ex-membro humano sem vínculo atual com a conta; não foi reutilizado nem alterado.
- Sem convite/e-mail: identidade de integração confirmada administrativamente. Não há senha ou token neste documento.

## Como os dois projetos usam

O plugin `cbn-crm@cbn-local` está instalado e habilitado. O runtime privado ausente foi restaurado e seu caminho foi validado por dois clientes MCP reais, um para cada perfil.

Na máquina CBN, a configuração padrão está em `%LOCALAPPDATA%\CBN\crm-plugin\config.json`. Os consumidores específicos devem selecionar:

| Consumidor | CBN_CRM_CONFIG | Identidade |
| --- | --- | --- |
| SDR | `%LOCALAPPDATA%\CBN\crm-plugin\config-sdr.json` | usuário 9, origem `sdr` |
| Rebeca | `%LOCALAPPDATA%\CBN\crm-plugin\config-rebeca.json` | usuário 9, origem `rebeca` |
| Plugin interativo padrão | `%LOCALAPPDATA%\CBN\crm-plugin\config.json` | usuário 9, origem `shared` |

Também existem os atalhos privados `crm-sdr.cmd` e `crm-rebeca.cmd` nessa pasta. Exemplo de consulta de autenticação: `crm-rebeca.cmd status`. Não passar token em argumento ou colar chave no chat.

Os três perfis referenciam a mesma credencial privada e o mesmo diretório de ações. Não criar cópias do token nos repositórios ou na extensão GoVoice. Ações persistidas incluem `integration_source`; executar/repreparar uma ação de outra origem é recusado. As mensagens novas preparadas pelo conector incluem essa origem em `content_attributes`, mantendo o mesmo autor CRM. Isso é atribuição operacional, não uma identidade de segurança independente.

Ao abrir um novo chat/recarregar o aplicativo, o plugin poderá carregar as ferramentas atualizadas. Um consumidor que já usa o CLI/configuração padrão encontra a credencial sem nova entrada manual. Se estiver com um processo MCP antigo aberto, reiniciar somente esse processo consumidor.

## Uso em serviço no VPS

A credencial operacional também está preservada no diretório privado `/srv/cbn-production/shared-ai`, com diretório 0700 e arquivo de token 0600. Os futuros serviços devem receber o segredo por montagem privada/somente leitura e identificar o consumidor em sua configuração; não embutir segredo na extensão ou em webhook público.

Este provisionamento não instala um plugin HTTPS no ChatGPT web. O conector validado é API/CLI e MCP stdio do Codex; a credencial também está disponível para os serviços de backend dos agentes. A conexão CBN Tabelas existente tem outro escopo e não deve receber acesso ao CRM.

## Estado entregue versus execução automática

**Concluído:** identidade comum, permissão de agente/caixa, segredo privado, configuração dos dois consumidores, restauração do runtime e conexão autenticada pela API e pelo MCP real.

**Não ativado nesta entrega:** envio de mensagens reais, importação do diário de ligações do SDR, criação de contatos, troca de responsáveis/status, consumidor da coluna Pronto para responder da BKO, AgentBot/webhooks e resposta autônoma da Rebeca. Esses fluxos devem consumir a conexão agora disponível, preservando seus controles atuais. Não apresentar a autenticação como se a passagem automática de atendimento já tivesse sido implementada.

Para a Rebeca, o usuário **9 deve ser classificado como automação**, e não como intervenção humana. Reconhecer apenas Guilherme como humano não é suficiente quando houver mais consultores: usar classificação explícita de identidades. O usuário WAHA 7 e o AgentBot legado também exigem tratamento próprio; não habilitar AUTO apenas por reabertura/status da conversa.

## Verificação

- Perfis SDR e Rebeca: autenticação HTTPS confirmada, mesma identidade 9/role agent, somente caixa 5 anunciada e consulta de conversas aceita. Conteúdo de clientes não foi impresso ou copiado para testes.
- Dois handshakes MCP reais: 13 ferramentas, `crm_status` autenticado em ambos os perfis, origem específica confirmada.
- 18 testes aprovados após incorporar as alterações existentes de anexos agendados: separação de origem, identidade esperada, caixa autorizada, replay, falha incerta, alterações concorrentes, anexos e handshake. Não foram feitos envios reais de homologação.
- Dependência Zod fixada em 4.6.7, lockfile e instalação privada/cache atualizados; `npm audit --omit=dev` sem vulnerabilidades reportadas.
- ACL da credencial local: apenas o usuário Windows atual e SYSTEM. A chave não foi exibida nem versionada.
- Usuário técnico sem administração; nenhuma rotina de atendimento, campanha, cron ou serviço público novo foi ativado.

## Referências conciliadas

Lidos os chats SDR - Codex, SDR, Rebeca ChatGPT e o estado recente da Rebeca no Codex. A conversa antiga da Rebeca ainda citava Lenovo/túnel; a inspeção desta entrega confirmou o Chatwoot atual na VPS. O layout atual da BKO é o simplificado A:K, com pronto em J e ID em K; a conexão não altera o layout nem processa linhas.
