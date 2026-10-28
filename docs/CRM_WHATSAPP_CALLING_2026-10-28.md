# Atendimento de chamadas WhatsApp — 28/10/2026

## Pedido e diagnóstico

Pedido: atender ligações de clientes pelo próprio CRM.

Consulta de leitura no VPS confirmou WAHA `2026.9.1`, tier `CORE`, engine `GOWS`, sessão `WORKING` e conexão pronta. A caixa operacional CBN WhatsApp (WAHA) é `Channel::Api`. Existe também caixa legada CBN Api `Channel::Whatsapp`; a consulta não comprovou conexão, elegibilidade ou licença de chamadas dessa caixa.

A [documentação oficial WAHA](https://waha.devlike.pro/docs/how-to/calls/) oferece rejeição de chamadas e eventos de recebimento/aceitação/encerramento. `call.accepted` significa atendimento em outro aparelho. Não documenta API para atender e transportar áudio ao navegador. Não é suficiente adicionar botão no Chatwoot.

O [recurso oficial do Chatwoot](https://www.chatwoot.com/hc/user-guide/articles/1779871708-connecting-whats_app-voice-channel) exige WhatsApp Cloud API, plano pago da instalação Enterprise a partir de 4.15.0 e número elegível no WhatsApp Business Calling API. A documentação consultada cita limite diário mínimo de 2.000 destinatários únicos; é requisito de capacidade da conta, não obrigação de enviar esse volume. Confirmar requisitos Meta e custos antes de qualquer migração.

## Resultado e próxima decisão

- Atendimento de áudio no CRM **não habilitado**: integração atual não oferece a função documentada.
- Nenhuma mudança em caixa, sessão, regras, licença ou cobrança; nenhum envio ou chamada de teste.
- Se o proprietário optar pela via oficial, conferir elegibilidade do número e disponibilidade de licença; preparar migração com preservação de histórico e plano de retorno. Não presumir que a caixa legada representa o mesmo número atual.
- Enquanto isso, o atendimento das chamadas permanece pelos dispositivos WhatsApp compatíveis vinculados ao número. Alertas de chamadas no CRM seriam função distinta e não atenderiam ao pedido de áudio.

Consulta ao OpenAPI local no caminho `/api-json` retornou erro HTTP; não é evidência de inexistência de outras rotas. A limitação acima é baseada no contrato de funcionalidades publicado pelo WAHA e no tipo real da integração.
