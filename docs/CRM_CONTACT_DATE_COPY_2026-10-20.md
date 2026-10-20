# Cópia da data de nascimento

## Correção solicitada

O botão Copiar do componente `CustomAttribute.vue` emitia o valor bruto do
atributo `cbn_data_nascimento`, em `AAAA-MM-DD`. A visualização podia estar em
formato brasileiro, mas a área de transferência continuava recebendo ISO.

O patch em `infra/cbn-contact-date/` faz a data de nascimento aparecer e ser
copiada em `DD/MM/AAAA`. A conversão reorganiza somente as partes do calendário,
sem converter fuso ou alterar o dia. Valores ISO com horário preservam a parte
de data; valores legados já formatados permanecem como recebidos.

O banco/API e o campo HTML de edição continuam usando o formato existente.
CPF, matrícula, demais atributos, bot e integração WhatsApp não são alterados.

## Publicação e retorno

Imagem derivada da versão ativa com Retomar bot:
`cbn/chatwoot:4.16.2-cbn-date-copy-20261020`. O build aplica um patch com âncoras
exatas e recompila o frontend com o lockfile existente. Não atualiza pacotes.

Publicação prevista somente no serviço web. Backup e manifesto ficam em
`/opt/cbn/builds/date-copy-20261020/`. Rollback consiste em restaurar apenas a
imagem web anterior `cbn/chatwoot:4.16.2-cbn-bot-resume-20261020`, preservando
alterações concorrentes de compose. Não exige restaurar dados ou sessão WAHA.

## Resultado

- Build Vite concluído. A primeira tentativa atingiu o heap de 2560 MB;
  desativar sourcemaps no estágio de build, como no build anterior, permitiu
  concluir com o mesmo limite e sem atualizar dependências.
- Imagem publicada somente no web em 20/10/2026; worker e WAHA preservados.
  Backup: `/opt/cbn/builds/date-copy-20261020/before-20261020T141331Z/`.
- Após a publicação, CRM respondeu HTTP 200 e WAHA permaneceu `WORKING`;
  web, worker e WAHA em execução.
- `git diff --check` sem problemas. Nenhum teste automatizado, envio de mensagem
  ou alteração de dados de clientes. Abas abertas precisam recarregar para
  carregar o frontend novo; preservar rascunhos antes de recarregar.
