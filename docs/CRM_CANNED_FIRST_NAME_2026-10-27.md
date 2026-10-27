# Primeiro nome nas respostas prontas — 27/10/2026

## Configuração aplicada

O atalho `tele` (resposta pronta 10) começa com:

```text
Oi, {{contact.first_name}}, tudo bem?
```

A variável usa o primeiro nome do contato da conversa, com inicial maiúscula e restante minúsculo. Exemplo sintético: `MARIA DA SILVA` resulta em `Oi, Maria, tudo bem?`. Pode ser reutilizada nas demais respostas prontas. No seletor nativo aparece como `Contact first name`.

Somente a primeira linha foi substituída; o restante da resposta foi preservado. Não houve alteração de cadastro, código ou implantação.

## Conferência e limites

- Confirmado no código em execução: `ContactDrop#first_name` aplica `split.first.capitalize`; o editor também normaliza as partes do nome.
- Atualização pela API autenticada nativa e releitura confirmaram conteúdo exato e preservação do corpo.
- Nenhuma mensagem enviada, nenhum teste executado. A apresentação no próximo uso real ainda não foi observada.
- Depende do nome cadastrado; nomes incompletos ou incorretos precisam ser corrigidos no contato. Não garante grafias especiais internas, como nomes com maiúsculas no meio.
- Para desfazer, editar a primeira linha da resposta pronta nas configurações. As demais mensagens não foram alteradas.
