# Menu inicial de crédito — escopo

Pedido do proprietário: saudação em uma mensagem e, em outra, opções para
novos clientes sem atendimento/rota definida: INSS, federal/SIAPE, servidor
estadual/municipal, CLT, carro em garantia e outros.

Implementar no CRM existente, usando regras nativas para os textos, remetente
automático sem assinatura humana, estado mínimo persistido e trava por conversa.
Uma seleção identifica a opção por etiqueta e encaminha ao humano; não inventar
aprovação de crédito, solicitar documentos ou modificar CPF/coletas existentes.

Escopo técnico: complemento isolado carregado no worker de automações, com
configuração própria; regras editáveis/pausáveis no CRM. Não alterar os fluxos
CLT/INSS/Colatina de anúncios, conta/caixas, WhatsApp ou credenciais.

Aceite: duas mensagens iniciais uma única vez por conversa; escolha 1–6; uma
orientação para entrada inválida; preservação de atendente e interrupção após
resposta humana; sem leitura de CPF como número da opção. Excluir histórico
anterior à ativação, contatos bloqueados, conta técnica, anúncios e conversas
já em atendimento. Pausar regra/configuração deve impedir a resposta correspondente.

Não disparar para a conversa de exemplo nem reprocessar histórico. Não criar
envios de teste ou executar suítes não solicitadas. Conferir sintaxe, fontes
publicadas, regras, carregamento e disponibilidade. Registrar limites, backup,
retorno e estado final em documentação sem PII. Commit/push em branch própria.
