# CRM CBN — anúncio Colatina, cadastro e etiquetas

## Pedido autorizado em 19/10/2026

Guilherme pediu automação para o anúncio de servidor da Prefeitura de Colatina,
CPF seguido de matrícula, gravação dos dados no contato, captura de CPF também
no fluxo CLT, origem Facebook para primeiro contato por anúncio, confirmação
ao final e etiquetas editáveis junto a Resolver/Reabrir.

## Regras nativas, criadas e ativadas pelo plugin CBN CRM

Conta 1, caixa 5 (CBN WhatsApp WAHA). Regras existentes 1, 3, 4, 5, 6 e 7
mantidas. Novas regras 8, 9 e 10, com textos editáveis em Configurações → Automação:

1. **CBN — Colatina: solicitar CPF** (8): mensagem recebida contendo o ID
   `120248430438870710` ou o título “Servidor da Prefeitura de Colatina?”.
   Etiquetas `servidor-publico` e `colatina`; mensagem:

   > Olá! 👋 Sou a assistente virtual da CBN Crédito.
   >
   > Para iniciar seu atendimento, envie seu CPF com os 11 números, por favor.

2. **CBN — Colatina: solicitar matrícula após CPF** (9): atualização da etapa
   técnica para `cpf_recebido`; mensagem:

   > Obrigado! Agora, pode me informar sua matrícula para verificarmos as opções disponíveis para você?

3. **CBN — Colatina: confirmar dados e chamar atendente** (10): etapa
   `dados_recebidos`; mantém responsável existente ou atribui a Guilherme;
   mensagem:

   > Obrigado pelos dados! Já encaminhei seu atendimento para um atendente. Ele dará continuidade por aqui assim que estiver disponível.

## Complemento no servidor

`infra/cbn-leads/cbn_lead_capture.rb` complementa as ações nativas; não depende
de Codex, computador local, modelo de IA, n8n nem chave de API de IA.

- Executa no listener assíncrono do worker Chatwoot e conserva os textos nas
  regras nativas. A ativação individual da regra controla os envios dessa etapa.
- Novas mensagens após a ativação, sem varredura ou reprocessamento de histórico.
- CPF com ou sem máscara, mensagem composta apenas pelo documento ou prefixo
  “CPF”; valida tamanho e dígitos verificadores. Conversas comuns não são
  varridas por números. Resposta deve pertencer a uma coleta iniciada.
- CLT: a regra 5 coleta o CPF; a regra 6/“Apresentação” também tem captura. INSS
  na regra 5 conserva seu comportamento anterior. Resposta nova a solicitação
  nativa CLT/Apresentação de até sete dias pode ser cadastrada sem novo envio.
- CPF vai para `cbn_cpf`. Colatina pede matrícula após salvar CPF. Matrícula
  numérica vai para `cbn_matricula_beneficio`, texto preservando zeros iniciais.
- Origem `cbn_origem_contato` recebe “Anúncio do Facebook” quando o primeiro
  contato recebido possui evidência do anúncio. Origem anterior é preservada;
  ID do anúncio fica em `additional_attributes.cbn_anuncio_id` quando informado.
- Etiquetas nativas da conversa são espelhadas no contato na entrada do fluxo.
- Travas de conversa/contato e marcadores de mensagem/etapa evitam duplicação
  de perguntas. Etapas expiram após sete dias. Erros não registram documentos.
- Documento já cadastrado diferente, ou CPF existente em outro contato: não
  sobrescreve nem funde cadastros; etapa técnica passa a revisão manual.
- Resposta humana após a pergunta impede nova pergunta/agradecimento automático
  nessa etapa. Campo ainda pode ser capturado; responsabilidade não é substituída.
- O complemento não altera status aberto/pendente/resolvido/adiado.

## Interface e persistência

- Etiquetas da conversa ficam no cabeçalho, antes de Resolver/Reabrir, com
  busca, adição e remoção. Todas as etiquetas selecionadas são exibidas e
  quebram linha. Usa a mesma API/Vuex nativa do painel lateral.
- “Matrícula / benefício” fica entre nascimento e origem, com ordem estável.
- Preserva seletor rápido de status da lista, tema compilado e demais ajustes.
- Imagem de interface: `cbn/chatwoot:4.16.2-cbn-leads-labels-20261019`.
- Worker: montagem persistente
  `/opt/cbn/infra/cbn-leads/cbn_lead_capture.rb` → initializer Rails.
- Configuração sem credenciais:
  `/srv/cbn-production/chatwoot_storage/cbn-lead-capture-config.json`.
- Fontes de build no servidor: `/opt/cbn/builds/crm-leads-20261019`.
- WhatsApp/WAHA, banco, anexos e status das conversas não foram reiniciados ou
  reorganizados. Worker e web recarregados para aplicar código/manifesto.
- A conversa 298 recebeu somente as duas etiquetas por UI, conforme o anúncio
  apresentado. Seus documentos históricos não foram retroativamente preenchidos.

## Conferência e limites

Build Vite e sintaxe Ruby concluídos; carregamento dos módulos no worker
confirmado. Plugin confirmou regras ativas. Navegador confirmou novo campo,
botão de etiquetas e gravação das duas etiquetas na conversa solicitada.
Não foi executado disparo de teste nem jornada fictícia contra clientes reais;
entrega e coleta completa devem ser acompanhadas no primeiro lead orgânico.

## Rollback

1. Pausar regras 8/9/10 pelo CBN CRM e definir `active:false` na configuração
   do complemento (retorna comportamento original das regras 5/6).
2. Restaurar imagem web anterior `cbn/chatwoot:4.16.2-cbn-document-viewer-20261009`
   e retirar apenas a montagem do complemento no worker, recriando os dois.
3. Preservar campos, etiquetas e valores de contato já coletados. Não restaurar
   o banco inteiro nem alterar status para reverter uma interface.

Backup inicial de regras/cadastros de definição em diretório privado
`/app/storage/cbn-lead-capture-backups/`. Compose e rollback estático preservados
em `/opt/cbn/builds/crm-leads-20261019/before-runtime-*` e `/var/lib/cbn-assets/`.
