# Prompt Codex — BKL-016 KMS, cofre e criptografia por envelope

Continue o projeto CBN a partir da `main` atualizada.

## Regras obrigatórias

1. Crie a branch:

   `codex/bkl-016-kms-envelope`

2. Não faça merge.
3. Não faça deploy.
4. Não crie recurso pago.
5. Não crie chave real em Google Cloud, AWS, Azure, Vault ou outro provedor.
6. Não use produção, n8n, Appsmith, Telegram ou dados reais.
7. Não solicite nem registre token, senha, chave KMS, service role, credencial cloud ou segredo.
8. Trabalhe somente com dados sintéticos e adaptador KMS local de teste.
9. Pare obrigatoriamente antes de qualquer autenticação em provedor externo ou criação de chave remota.

## Objetivo

Preparar e validar localmente a arquitetura de criptografia por envelope da BKL-016, incluindo:

- DEK aleatória por payload/arquivo;
- KEK externa referenciada por alias e versão;
- AES-256-GCM para criptografia de aplicação;
- AAD vinculando o conteúdo ao contexto correto;
- rotação de KEK por rewrap da DEK;
- rotação de DEK por recriptografia completa;
- recuperação e falha fechada;
- persistência somente de material cifrado e metadados seguros;
- nenhum segredo em banco, logs, Git ou documentação.

## Etapa 1 — Diagnóstico e alinhamento

1. Confirme:

   - branch atual;
   - árvore limpa;
   - `main` atualizada;
   - migrations existentes;
   - campos atuais de `app_private.protected_payloads` e `app_private.protected_file_refs`;
   - usos atuais de `encryption_key_ref`, ciphertext e referências protegidas.

2. Leia e alinhe:

   - `docs/BKL-016_ARMAZENAMENTO_DADOS_SENSIVEIS.md`;
   - `docs/ARQUITETURA_TECNICA.md`;
   - `docs/BACKLOG_CHECKPOINT.md`;
   - `docs/HANDOFF.md`;
   - migrations, rollback, seed e testes da BKL-016.

3. Não altere `telegram-gateway/`.

## Etapa 2 — Modelo criptográfico

Documente e implemente um contrato claro contendo, no mínimo:

- algoritmo de conteúdo: `AES-256-GCM`;
- DEK: 32 bytes aleatórios por gravação ou objeto;
- nonce/IV: 12 bytes aleatórios e nunca reutilizados com a mesma DEK;
- authentication tag obrigatória;
- AAD obrigatório contendo identificadores canônicos, sem PII em claro, por exemplo:
  - versão do envelope;
  - tipo do payload;
  - `client_id` quando aplicável;
  - `operation_id` quando aplicável;
  - `proposal_id` quando aplicável;
  - bucket e object name quando for arquivo;
- KEK nunca armazenada no banco;
- DEK nunca armazenada em claro;
- DEK persistida somente embrulhada pelo adaptador KMS;
- alias da KEK e versão armazenados como referência não secreta;
- versão do formato do envelope;
- política de falha fechada quando AAD, tag, versão ou chave não conferirem.

O formato persistido deve distinguir claramente:

- ciphertext;
- wrapped DEK;
- nonce;
- tag;
- algoritmo;
- envelope version;
- key alias/ref;
- key version;
- AAD version ou hash seguro do contexto, quando necessário.

Não concatenar campos binários sem estrutura versionada.

## Etapa 3 — Abstração de KMS

Crie uma interface pequena e testável, sem SDK cloud obrigatório, com operações equivalentes a:

- `wrapKey`;
- `unwrapKey`;
- `getKeyReference`;
- `rewrapDataKey`;
- `healthCheck`.

Crie somente um adaptador local sintético para testes.

Regras do adaptador local:

- exclusivo para testes;
- nunca chamado de produção;
- chave mestra gerada em memória por processo ou fixture segura de teste;
- nenhuma chave fixa versionada;
- nenhum valor secreto emitido em logs;
- API incompatível com uso acidental em produção sem flag explícita de ambiente de teste.

A camada de aplicação deve depender da interface, não de um provedor específico.

## Etapa 4 — Serviço de envelope encryption

Implemente um serviço isolado e testável para:

1. criptografar payload sintético;
2. descriptografar somente com contexto/AAD idêntico;
3. recusar tag adulterada;
4. recusar nonce alterado;
5. recusar AAD de outro cliente/operação/proposta;
6. recusar key version inexistente;
7. recusar envelope version desconhecida;
8. impedir reutilização acidental de envelope incompleto;
9. limpar buffers sensíveis quando tecnicamente possível;
10. não registrar plaintext, DEK, wrapped DEK, nonce completo, tag completa ou conteúdo descriptografado.

Use primitivas nativas e bibliotecas oficiais bem mantidas. Não implemente criptografia própria.

## Etapa 5 — Rotação

Defina e teste dois fluxos distintos.

### Rotação de KEK

- rewrap da mesma DEK;
- payload não precisa ser descriptografado/recriptografado;
- atualiza key alias/version de forma atômica;
- mantém rollback seguro enquanto a versão anterior ainda for válida;
- gera evento de auditoria sem material secreto.

### Rotação de DEK

- descriptografa em memória;
- gera nova DEK e novo nonce;
- recriptografa o conteúdo;
- embrulha a nova DEK;
- grava novo envelope atomicamente;
- falha sem destruir o envelope anterior;
- exige teste de recuperação.

Não executar rotação remota real.

## Etapa 6 — Banco de dados

Avalie se o schema atual suporta o envelope com integridade suficiente.

Caso precise de ajuste:

1. crie migration nova, nunca edite silenciosamente uma migration já aplicada no remoto;
2. atualize rollback;
3. mantenha compatibilidade explícita com registros anteriores;
4. adicione constraints para:
   - algoritmo permitido;
   - envelope version permitida;
   - tamanhos/formato de nonce e tag;
   - presença coerente dos campos criptográficos;
   - key alias/ref e key version não vazios;
5. impeça mistura parcial entre formato antigo e novo;
6. não armazene plaintext nem segredo;
7. não aplique a migration no Supabase remoto.

Se uma migration não for necessária nesta fase, documente de forma objetiva por quê.

## Etapa 7 — Testes obrigatórios

Crie testes sintéticos cobrindo pelo menos:

- round-trip positivo;
- plaintext vazio rejeitado ou tratado por regra explícita;
- DEK diferente para duas criptografias do mesmo conteúdo;
- nonce diferente para cada envelope;
- ciphertext diferente para o mesmo plaintext;
- AAD correto aceita;
- AAD de outro cliente rejeita;
- AAD de outra operação rejeita;
- AAD de outra proposta rejeita;
- tag adulterada rejeita;
- ciphertext adulterado rejeita;
- nonce adulterado rejeita;
- wrapped DEK adulterada rejeita;
- key version incorreta rejeita;
- envelope version desconhecida rejeita;
- rotação de KEK preserva o plaintext;
- rotação de DEK preserva o plaintext e muda ciphertext/nonce/DEK;
- falha durante rotação não destrói o envelope anterior;
- nenhuma saída contém plaintext, chave, token ou material criptográfico completo.

Caso haja SQL novo, adicione testes de constraints e rollback local.

## Etapa 8 — Decisão de provedor

Crie uma matriz curta e objetiva, sem escolher ou contratar ainda, comparando no máximo três caminhos:

1. KMS gerenciado de nuvem;
2. HashiCorp Vault Transit gerenciado ou operado;
3. cofre/secrets manager para credenciais combinado com serviço próprio de envelope no Gateway.

Avalie:

- segurança;
- custo operacional;
- custo financeiro;
- facilidade de rotação;
- auditoria;
- disponibilidade;
- recuperação;
- dependência de fornecedor;
- adequação ao n8n/Gateway/Railway;
- complexidade para uma operação pequena.

Use somente documentação oficial e informe a data da consulta. Caso não tenha acesso à internet, não invente preços nem recursos: marque como pendente de verificação humana.

Não escolher provedor automaticamente. Produza uma recomendação técnica preliminar e um gate de decisão para Guilherme.

## Etapa 9 — Segurança e validação

Execute:

```powershell
git diff --check
npm.cmd test --prefix scripts
powershell.exe -ExecutionPolicy Bypass -File .\scripts\validate-bkl016.ps1
```

Adicione validações específicas para garantir:

- nenhuma chave fixa;
- nenhum segredo em `.env` versionado;
- nenhum plaintext sintético persistido fora de fixture controlada;
- nenhum wrapped DEK, nonce, tag ou ciphertext completo em logs;
- nenhuma credencial cloud;
- nenhuma alteração em `telegram-gateway/`;
- `.env.example` somente se estritamente necessário e sempre sem valores.

## Etapa 10 — Documentação

Atualize:

- `docs/BKL-016_ARMAZENAMENTO_DADOS_SENSIVEIS.md`;
- `docs/ARQUITETURA_TECNICA.md`;
- `docs/BACKLOG_CHECKPOINT.md`;
- `docs/HANDOFF.md`;
- runbook específico de KMS/envelope;
- relatório da execução local.

O status deve permanecer **Em andamento** até:

- provedor aprovado;
- chave remota criada com autorização humana;
- rotação e recuperação remotas validadas;
- restauração e retenção concluídas;
- revisão técnica independente.

## Commit e entrega

Faça commit e push na branch `codex/bkl-016-kms-envelope`.

Mensagem sugerida:

`feat: prepare BKL-016 envelope encryption and key rotation`

Não faça merge.

No relatório final, informe:

- arquivos alterados;
- arquitetura adotada;
- campos de envelope;
- testes executados e resultados;
- migration criada ou justificativa para não criar;
- resultado da rotação de KEK e DEK sintéticas;
- matriz de provedores;
- riscos restantes;
- ponto exato do gate humano;
- hash do commit;
- confirmação de que nenhum recurso externo, chave real, segredo, produção, n8n, Appsmith ou Telegram foi acessado.
