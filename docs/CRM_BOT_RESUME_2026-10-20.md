# Retomar bot no CRM

## Ampliação para o menu inicial — 22/10/2026

O botão agora também inicia/retoma o menu de crédito em conversas sem coleta/campanha. Primeiro clique envia saudação e menu; cliques posteriores reenviam apenas o menu, preservando trava, UUID e cooldown. Conversa anterior à ativação pode iniciar mediante clique explícito. Atendimento indicado pelo proprietário acionado pela rota autenticada; duas mensagens entregues. [Publicação atual e rollback](CRM_GENERIC_CREDIT_MENU_2026-10-22.md).

As seções abaixo descrevem a coleta original; o limite de uma mensagem por clique aplica-se à coleta e à retomada de menu já iniciado. A primeira iniciação do menu envia duas mensagens.

## Pedido

O proprietário pediu um atalho para continuar o atendimento automático quando
uma coleta trava, em vez de depender de correção técnica ou resposta manual.

## Experiência

Botão “↻ Retomar bot” no cabeçalho, perto das etiquetas e Resolver/Reabrir, nas
conversas da caixa WAHA 5 da conta CBN 1. Cada clique é uma solicitação explícita
do atendente para retomar a coleta. Pode enviar uma pergunta ao cliente.

- Consulta a etapa e os dados cadastrados; procura uma resposta válida recebida
  depois da pergunta e ainda não processada, incluindo o corpo de anúncio WAHA.
- Se o CPF já consta, segue para matrícula; se matrícula consta, segue para
  vínculo. Quando todos os dados constam, usa a confirmação/encaminhamento nativo.
- Se falta dado, repete somente a pergunta da etapa pendente.
- Regras/textos continuam em Configurações → Automação. Regra pausada bloqueia
  o envio e informa o motivo. CLT conserva sua coleta de CPF; INSS não é incluído.
- Coleta concluída com dados completos apenas informa que já terminou. Coleta
  interrompida por resposta humana pode ser retomada explicitamente.
- Divergências de CPF/matrícula/vínculo exigem revisão. Não sobrescreve valores
  conflitantes nem funde contatos. Contato bloqueado ou conversa fechada não envia.
- Coleta expirada renova a janela mediante clique explícito, usando dados já
  cadastrados e sem capturar respostas históricas anteriores à nova pergunta.
- Um clique envia no máximo uma mensagem. Cliques simultâneos/seguidos têm trava,
  UUID e proteção de 30 segundos na mesma etapa. Se a requisição falhar sem
  confirmação, o cliente é orientado a conferir a conversa antes de tentar de novo.

## Implementação e acesso

- `CbnBotResume.vue`: botão com estado de carregamento e avisos do servidor.
- `POST /api/v1/accounts/:account_id/conversations/:conversation_id/bot_resume`.
  Usa autenticação nativa do Chatwoot, conta atual e política `ConversationPolicy#show?`.
  Exige usuário humano da conta; identidade técnica WAHA 7 e AgentBot rejeitados.
  Nenhuma chave ou token adicional é exposto no frontend.
- `Cbn::LeadBotResumeService`: executa sob trava da conversa, chama extratores
  e ações nativas, mantém guardas de configuração/etapa e guarda somente ator,
  UUID, horário, etapa e ID da mensagem em `additional_attributes.cbn_bot_resume`.
- Retomada humana tem exceção temporária à supressão por intervenção humana,
  limitada à conversa/Thread autenticada e restaurada em `ensure`. A nova pergunta
  fica como referência para as respostas futuras. Fluxo automático normal mantém
  sua regra de não interromper atendimento humano.
- Mensagens usam remetente automático e `automation_rule_id`, conservando a
  exclusão da assinatura GUILHERME. Não usa nova IA, n8n ou serviço externo.

## Publicação

Publicado no VPS na imagem
`cbn/chatwoot:4.16.2-cbn-bot-resume-20261020`. Fontes e manifesto operacional em
`/opt/cbn/builds/bot-resume-20261020/`, backup de compose/initializer/configuração
em `before-20261020T120341Z/`. Fonte de captura persistente SHA-256
`3f5503dcdd0aa1ebef15c61e8d984967295ce6a70c4a26f55d6cc163c328b30b`.

Web e worker recriados para carregar backend/rota; WAHA e configuração ativa de
regras preservados. A publicação não enviou mensagens. Mantém a barra de
formatação fixa, conversão WhatsApp, etiquetas e demais alterações anteriores.

Conferências: build Vite, sintaxe Ruby dos três arquivos, `git diff --check`,
carregamento de serviço/controlador/rota por inspeção Rails e CRM HTTP 200.
Controlador herda autenticação nativa e aplica autorização à conversa. Navegador
confirmou botão habilitado ao lado de Resolver; captura apenas do cabeçalho:
`outputs/crm-retomar-bot-2026-10-20.png`, fora do repositório e sem dados de contato.
Não foram executados testes automatizados nem acionado o botão para enviar uma
mensagem de teste. O primeiro uso operacional será feito explicitamente pelo
atendente. Abas abertas precisam recarregar para receber o novo componente.

Rollback: restaurar imagem web anterior
`cbn/chatwoot:4.16.2-cbn-whatsapp-toolbar-20261020` e somente o initializer do
backup, preservando outras alterações posteriores de compose/configuração.
Recriar web e worker com os perfis usuais. Não restaurar banco, apagar dados
capturados nem repetir mensagens já criadas. A correção de leitura do CPF dentro
do anúncio existe na versão anterior e deve permanecer.
