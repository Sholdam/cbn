# Menu de crédito para chegada direta — 22/10/2026

## Correção do atalho Retomar bot — 22/10/2026

O atalho anterior só procurava coletas de CPF/matrícula e não encontrava fluxo na chegada direta anterior à ativação. O serviço autenticado agora direciona conversas sem coleta/campanha para o menu. Conversas de campanhas continuam no serviço de coleta existente.

- Primeiro clique: saudação e opções em duas mensagens, inclusive para chegada anterior à ativação. Clique posterior com menu iniciado: somente as opções. Menu concluído apenas informa conclusão.
- Preservados autenticação/política da conversa, usuário humano, escopo conta 1/caixa 5, bloqueio de contato, conversa aberta/Secretária, UUID, trava, cooldown de 30 segundos e auditoria de ator/etapa/mensagem. Configuração e regra pausadas continuam impedindo envio.
- Clique explícito pode retomar após intervenção humana e renova a janela do menu; as respostas antigas não são reprocessadas. A próxima resposta é comparada à nova pergunta. Não remove etiquetas nem altera os dados cadastrais.
- Imagem web atual: `cbn/chatwoot:4.16.2-cbn-generic-menu-resume-20261022`, derivada da imagem de anexos agendados existente. Somente backend/initializer adicionados; frontend e anexos preservados. Worker carrega o mesmo initializer por volume. WAHA não reiniciado; configurações próprias e de coleta preservadas.
- Fonte atual do menu SHA256 `5f6a85d1b1b83d0b50b9c3f2ad6064bc8d2281774779b63fd60800dd9965e8fa`. Build/sintaxe e carregamento conferidos. Backup/manifesto: `/opt/cbn/builds/generic-menu-resume-20261022/`, backup `before-20261022T160853Z/`.
- Atendimento real solicitado pelo proprietário na conversa 445, via rota autenticada `bot_resume`: mensagens 4980 e 4981, regra 12, remetente automático sem assinatura humana, ambas `delivered`. Etapa `aguardando_opcao`, auditoria registrada às `2026-10-22T16:09:39Z`. Nenhuma mensagem de teste ou replay geral. A seleção do cliente ainda não foi observada.

Build reproduzível: usar `infra/cbn-generic-menu/Dockerfile.resume` em contexto contendo `lead_bot_resume_service.rb` atualizado de `infra/cbn-leads/` e `cbn_generic_menu.rb` desta pasta.

Retorno desta correção: restaurar somente a imagem web anterior `cbn/chatwoot:4.16.2-cbn-scheduled-media-ui-20261020` e o initializer do backup dessa correção, recriando web/worker com `--no-deps`. Preservar as mensagens já entregues e o estado; não reenviá-las. O retorno completo do menu está ao final do documento.

## Escopo e comportamento

Pedido do proprietário: saudação seguida de outra mensagem com opções para quem chega sem produto definido. Implementação isolada em `infra/cbn-generic-menu/`, com textos em regras nativas e remetente automático, sem assinatura de atendente.

- Conta 1, caixa WAHA 5; somente mensagem pública recebida de contato após ativação.
- Conversa aberta, sem agente atribuído, sem envio público anterior, sem estado de coleta, sem etiqueta de produto e sem envelope conhecido de anúncio. Não reprocessa histórico nem dispara para a conversa de exemplo.
- Duas mensagens uma vez por conversa, dentro da mesma transação/trava. Estado em `additional_attributes.cbn_generic_credit_menu_v1` e etapa técnica `custom_attributes.cbn_menu_credito_etapa`.
- Escolha por número 1–6, inclusive emoji numérico, ou expressão curta exata configurada. CPF, texto longo e números contidos em frases não viram opções. Uma orientação para resposta textual inválida, sem repetição automática.
- Escolha válida etiqueta contato e conversa, preserva agente existente ou atribui a Guilherme (usuário 1), confirma encaminhamento e conclui. Não inicia coleta documental nem decisão de crédito.
- Resposta pública humana ou de outro agente após o menu interrompe o bot. Entrada posterior a sete dias expira o menu. Não existe reabertura automática desse menu na mesma conversa.
- É menu de texto numerado; não são botões interativos do WhatsApp. A entrega depende de a sessão WhatsApp permanecer conectada.

## Mensagens editáveis em Configurações → Automações

**12 — CBN — Menu inicial de crédito**, evento `message_created`, ações sequenciais:

> Olá! 👋 Seja bem-vindo(a) à **CBN Crédito**! Sou a assistente virtual e vou ajudar a direcionar seu atendimento.

Segunda mensagem:

```text
Hoje trabalhamos com as opções abaixo. Qual delas você procura?

1️⃣ Recebo benefício do INSS
2️⃣ Sou servidor público federal (SIAPE)
3️⃣ Sou servidor estadual ou de prefeitura
4️⃣ Trabalho com carteira assinada (CLT)
5️⃣ Empréstimo com carro em garantia
6️⃣ Outros assuntos / falar com atendente

Responda com o número da opção.
```

**13 — CBN — Menu: confirmar opção e encaminhar**:

> Obrigado! Registrei sua opção e encaminhei seu atendimento. Um atendente dará continuidade por aqui.

**14 — CBN — Menu: orientar escolha**:

> Para direcionar seu atendimento, responda com um número de 1 a 6 do menu acima. Se preferir falar com um atendente, escolha 6.

Etiquetas por opção: `inss`, `siape`, `servidor-publico`, `clt`, `garantia-veiculo`, `outros-assuntos`. As três últimas novas definições criadas nesta tarefa são `siape`, `garantia-veiculo` e `outros-assuntos`; as demais já existiam.

## Operação e isolamento

Fonte: `/opt/cbn/infra/cbn-leads/cbn_generic_menu.rb`.
Configuração: `/srv/cbn-production/chatwoot_storage/cbn-generic-menu-config.json`, dono 1000:1000, modo 0600. IDs e aliases sem segredos. Usar `enabled_at` da ativação real, nunca a data ilustrativa do exemplo para implantação nova.

Somente o serviço `chatwoot-waha-worker` recebe este volume adicional no compose existente:

```yaml
- ./cbn-leads/cbn_generic_menu.rb:/app/config/initializers/cbn_generic_menu.rb:ro
```

As regras 13/14 têm condições técnicas reservadas `opcao_recebida`/`orientar_opcao`, mas sua execução é chamada diretamente pelo complemento, sob escopo de thread e trava da conversa. Eventos arbitrários não podem invocá-las. O envio e a atualização final de etapa ficam na mesma transação; retorno nativo ausente aborta a transação, mesmo que o serviço nativo capture uma exceção interna.

Manter o marcador `[CBN_GENERIC_MENU_V1]` na descrição das três regras. Ele bloqueia essas ações mesmo se a configuração estiver ausente ou ilegível. Erro de configuração não impede regras de outros fluxos. IDs da configuração também identificam as regras, permitindo editar os nomes.

Pausar a regra 12 impede novos menus. Pausar a regra 13 impede concluir/confirmar escolhas; regra 14 pausada impede orientação. Para pausar todo o fluxo, definir `active: false` na configuração própria (gravação atômica). Não mexer na configuração `cbn-lead-capture-config.json`.

O botão **Retomar bot** também inicia ou retoma o menu desde a correção descrita no início deste documento. Mensagem não reconhecida após a única orientação e menu expirado ficam para atendimento humano ou retomada explícita.

## Implantação e conferências

- Ativo desde **22/10/2026 às 12:50:58 de Brasília** (`2026-10-22T15:50:58Z`): configuração própria ativa e regras 12, 13, 14 ativas. Regra inicial ativada por último, após confirmação das dependências.
- Regras e etiquetas provisionadas pela API autenticada do plugin CBN CRM; regras criadas inativas antes da instalação.
- Ruby `-c` aprovado; módulos carregados no worker. Ordem observada: `CbnLeadCapture::Listener` → `CbnGenericMenu::Listener` → listener nativo; actions na mesma ordem. APIs nativas e retorno de `Messages::MessageBuilder` conferidos no código instalado.
- Sem suíte de testes, simulação de atendimento, mensagens de teste, replay de eventos ou envio à conversa de exemplo. O primeiro atendimento orgânico ainda precisa confirmar o comportamento completo de entrega e resposta.
- Código de coleta existente preservado: SHA256 `3f5503dcdd0aa1ebef15c61e8d984967295ce6a70c4a26f55d6cc163c328b30b`; configuração de coleta preservada: SHA256 `fb8192964a83b7b1a7c77831798d1e7b9f604d69a10f88a9a72ded3a8540f4cc`.
- Fonte do menu publicada: SHA256 `9039068d07ecc946e0593f20c56c968e17d051b391d92c470f16c67d26556a32`. Consulta final: módulos carregados, agente disponível, seis etiquetas existentes, CRM HTTP 200, WhatsApp `WORKING`, nenhum erro do menu nos logs desde a ativação. Nenhum atendimento orgânico havia iniciado o menu no instante dessa consulta.
- Backup do compose anterior e da configuração de coleta: `/opt/cbn/builds/generic-menu-20261022/before-runtime-20261022T154738Z/`. Manifesto da implantação no mesmo diretório pai, `deployment.json`.
- Web, sessão WAHA, filas de agendamento e imagens existentes não foram modificadas. Apenas o worker de integração foi recriado para carregar o novo initializer.

## Retorno

1. Desativar as regras nativas 12, 13 e 14 e a configuração própria.
2. Remover somente o volume `cbn_generic_menu.rb` do serviço `chatwoot-waha-worker` e recriar apenas esse serviço com `--no-deps`. Não substituir o compose completo por backup se outras tarefas o tiverem modificado depois.
3. Preservar estados registrados e etiquetas; não reenviar histórico. Remover definições de etiquetas/campos exige avaliar uso posterior.

O novo initializer depende de `CbnLeadCapture` já instalado e deve ficar restrito ao worker que já o carrega.
