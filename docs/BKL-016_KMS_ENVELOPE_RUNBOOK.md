# BKL-016 — runbook de KMS e criptografia por envelope

**Status:** Em andamento
**Data da pesquisa de provedores:** 15/07/2026
**Escopo validado:** somente adaptador KMS local, chave efêmera em memória e dados sintéticos

## Limite desta etapa

Esta etapa não autentica em Google Cloud, AWS, Azure, Vault, Railway ou outro provedor; não cria KEK real, recurso pago, segredo remoto ou conexão com produção. O adaptador `LocalTestKmsAdapter` exige simultaneamente `environment: 'test'` e `allowLocalTestKms: true`, gera a KEK em memória por processo e não possui SDK ou chamada de rede.

## Contrato criptográfico v1

1. O backend recebe o conteúdo em memória e monta AAD canônica, sem PII em claro.
2. Gera uma DEK aleatória de 32 bytes e nonce aleatório de 12 bytes para cada gravação.
3. Cifra o conteúdo localmente com `AES-256-GCM`, produzindo ciphertext e tag obrigatória de 16 bytes.
4. Envia somente a DEK e o hash da AAD ao adaptador para wrapping pela KEK.
5. Persiste o envelope completo em uma única transação; KEK e DEK em claro nunca são persistidas.
6. Na leitura, versão, algoritmo, estrutura, AAD, referência de chave e tag precisam conferir. Qualquer divergência falha fechada.

A AAD v1 é JSON em ordem fixa e contém:

- `aadVersion` e `envelopeVersion`;
- `payloadType`;
- `clientId`, `operationId` e `proposalId`, quando aplicáveis;
- `bucketName` e `objectName`, quando o ciphertext estiver no Storage.

O hash SHA-256 da AAD pode ser persistido e usado para detectar troca de contexto. O hash não substitui `setAAD`: a AAD canônica completa participa da autenticação AES-GCM.

## Formato persistido

| Campo do serviço | PostgreSQL | Regra |
|---|---|---|
| `ciphertext` | `protected_payloads.ciphertext` ou objeto privado | nunca plaintext; pelo menos 1 byte para payload |
| `wrappedDek` | `wrapped_dek` | DEK cifrada; 32 a 16.384 bytes |
| `nonce` | `content_nonce` | exatamente 12 bytes |
| `tag` | `authentication_tag` | exatamente 16 bytes |
| `algorithm` | `envelope_algorithm` | somente `AES-256-GCM` |
| `envelopeVersion` | `envelope_version` | somente `1` |
| `keyReference.alias` | `encryption_key_ref` | referência não secreta e não vazia |
| `keyReference.version` | `encryption_version` | versão não secreta e não vazia |
| `aadVersion` | `aad_version` | somente `1` |
| `aadSha256` | `aad_sha256` | 64 caracteres hexadecimais minúsculos |

Os campos binários são colunas separadas. O adaptador local usa JSON versionado somente para representar a DEK embrulhada; não concatena binários sem estrutura.

## Compatibilidade e escrita

A migration incremental `20260717_001_bkl016_envelope_metadata.sql` não altera migrations remotas anteriores. Linhas antigas, com todos os novos campos nulos, continuam válidas para leitura/migração controlada. Novas escritas do serviço devem preencher o conjunto inteiro; o banco rejeita formato parcial.

O seed mantém deliberadamente uma fixture legada sintética e não guarda material criptográfico reutilizável. A suíte SQL cria envelopes completos apenas dentro de transação com `ROLLBACK`.

`client_sensitive_data` e `proposal_sensitive_data` permanecem no formato legado nesta etapa. Novas escritas de envelope devem usar `protected_payloads` ou `protected_file_refs` até uma migration futura definir, testar e migrar as tabelas especializadas sem misturar formatos.

## Rotação de KEK

1. Validar envelope e AAD.
2. Solicitar ao adaptador o rewrap da mesma DEK para a nova referência de KEK.
3. Não descriptografar nem recriptografar o payload.
4. Atualizar `wrapped_dek`, `encryption_key_ref` e `encryption_version` na mesma transação, com controle de concorrência.
5. Manter a versão anterior habilitada durante a janela de rollback.
6. Auditar apenas tipo do evento, algoritmo, versões e alias não secreto.

O teste local prova que ciphertext, nonce e tag permanecem iguais, a DEK embrulhada muda e tanto o envelope anterior quanto o novo são recuperáveis enquanto as duas versões locais existem.

## Rotação de DEK

1. Desembrulhar a DEK atual e descriptografar em memória.
2. Gerar nova DEK e novo nonce.
3. Recriptografar e embrulhar a nova DEK.
4. Validar o envelope novo antes de substituir o anterior.
5. Persistir a substituição atomicamente; em falha, conservar o envelope anterior.
6. Limpar buffers de plaintext e DEK quando tecnicamente possível.

O teste local comprova plaintext preservado, novo ciphertext, nonce e wrapped DEK, além de recuperação do envelope original após falha sintética.

## Recuperação e falha fechada

- referência/versão de KEK indisponível: não tentar outra chave silenciosamente;
- AAD de outro dono ou objeto: rejeitar antes da descriptografia;
- tag, nonce, ciphertext ou wrapped DEK adulterados: rejeitar;
- envelope desconhecido/incompleto: rejeitar;
- falha do KMS: manter o envelope anterior e registrar somente categoria segura;
- recuperação de desastre: restaurar banco/objetos e garantir que as versões de KEK ainda estejam habilitadas antes de liberar tráfego;
- exclusão de versão antiga: somente após inventário, rewrap concluído, amostragem de recuperação e aprovação humana.

O rollback SQL desta migration também falha fechado se encontrar qualquer envelope novo, porque remover seus metadados tornaria o ciphertext irrecuperável.

## Matriz preliminar de provedores

Pesquisa feita em 15/07/2026 somente em documentação oficial. Nenhum provedor foi escolhido ou acessado.

| Caminho | Segurança e auditoria | Operação/disponibilidade/recuperação | Custo e dependência | Adequação ao CBN |
|---|---|---|---|---|
| KMS gerenciado de nuvem, representado pelo Google Cloud KMS | KEK central, IAM e trilha do serviço; modelo oficial recomenda DEK local por gravação e AES-256-GCM | menor carga operacional; rotação de KEK versionada e rewrap pela aplicação; recuperação depende de região, IAM e versões não destruídas | cobrança oficial por versão ativa e operação; requer billing e cria dependência da API/IAM do provedor | melhor simplicidade preliminar para operação pequena; Gateway chama KMS, n8n chama o Gateway, Railway guarda somente credencial de workload |
| HashiCorp Vault Transit gerenciado ou operado | criptografia como serviço, ACL, keyring versionado e endpoint de rewrap sem expor plaintext | boa rotação; operação própria exige HA, armazenamento, unseal, backup, monitoramento e recuperação; gerenciado reduz parte da carga | preço gerenciado depende do plano; self-managed transfere custo para infraestrutura/equipe; maior complexidade operacional | bom se já existir competência Vault ou requisito multicloud; excessivo para equipe pequena sem operação 24x7 |
| Cofre de credenciais + envelope próprio no Gateway | separa credenciais, mas o cofre não substitui KMS; a equipe passa a custodiar a KEK e todo o ciclo criptográfico | disponibilidade e recuperação ficam sob responsabilidade do Gateway; rotação de KEK exige disciplina própria | pode aproveitar Railway/secrets existente, mas cria custo oculto de engenharia e risco de concentração; maior lock-in no código interno | aceitável apenas como transição controlada; Railway sealed variables não são recuperáveis pela UI/API, mas entram no runtime e não oferecem operações KMS/auditoria criptográfica |

Fontes oficiais:

- [Google Cloud KMS — envelope encryption](https://docs.cloud.google.com/kms/docs/envelope-encryption)
- [Google Cloud KMS — preços](https://cloud.google.com/kms/pricing)
- [HashiCorp Vault — Transit secrets engine](https://developer.hashicorp.com/vault/docs/secrets/transit)
- [HashiCorp Vault — preços](https://www.hashicorp.com/products/vault/pricing)
- [Railway — variables e sealed variables](https://docs.railway.com/variables)

## Recomendação técnica preliminar e gate de Guilherme

A direção preliminar é avaliar primeiro um KMS gerenciado de software, por reduzir a operação própria e encaixar diretamente no contrato de KEK/DEK. Isto não é escolha, contratação ou autorização para criar chave.

Guilherme deve aprovar, em registro separado:

1. provedor e região;
2. estimativa de custo com volume real de operações e versões;
3. identidade de workload e política mínima de wrap/unwrap/rewrap;
4. retenção e janela de destruição de versões;
5. auditoria, alertas, backup e procedimento de recuperação;
6. integração exclusiva pelo Gateway, sem chave no n8n/Appsmith;
7. plano de teste sintético e rollback em ambiente isolado.

## Parada humana obrigatória

**Ponto exato de parada:** antes de login/autenticação em qualquer provedor, criação/importação de KEK, ativação de API, configuração de billing, criação de Vault, gravação de variável Railway ou uso de credencial externa.

Depois da aprovação documentada, uma tarefa separada deverá executar o adaptador do provedor em ambiente isolado, primeiro com dado sintético, e parar novamente antes de qualquer produção.
