# Arquitetura Técnica — Gateway de Crédito CBN

## Rota escolhida

### 1. API oficial Prospecta

Permanece como rota preferida caso a fornecedora entregue documentação, autenticação e endpoints operacionais comprovados.

### 2. Telegram MTProto

Rota provisória validada para operar o bot como conta de usuário real.

Provas concluídas em 12/07/2026:

- autorização da conta;
- envio e recebimento de mensagem;
- sessão persistente após reinício do processo;
- idempotência do envio por `operation_id`/`random_id` determinístico.

### 3. RPA no Telegram Web

Somente contingência. Não deve ser a base do MVP enquanto MTProto permanecer estável.

## Arquitetura de dados e sistema interno — DE-002

A arquitetura aprovada para a camada operacional é:

```text
Meta / WhatsApp / Telegram
            ↓
           n8n
            ↓
        Gateway CBN
            ↓
 Supabase / PostgreSQL protegido
            ↓
      Appsmith interno
            ↓
 Power BI opcional no futuro
```

### Responsabilidades por componente

- **Supabase/PostgreSQL:** fonte principal de clientes, consultas, ofertas, propostas, interações, pendências, estados, locks, auditoria e referências seguras.
- **Appsmith:** interface interna da equipe para consulta e operação autorizada.
- **n8n/Gateway:** regras de negócio, validações, integrações, idempotência, filas, retries e efeitos externos.
- **Google Sheets:** apoio temporário, exportação, contingência e leitura mascarada; não será a fonte de verdade.
- **Power BI:** dashboards gerenciais futuros, somente leitura e preferencialmente sobre views agregadas e mascaradas.

### Regras obrigatórias

1. Nenhuma credencial administrativa do Supabase fica no navegador ou no Appsmith.
2. A service role não pode ser exposta no cliente.
3. Operações críticas passam por API/n8n/Gateway com menor privilégio.
4. RLS deve permanecer ativa nas tabelas expostas.
5. CPF completo, documentos, dados bancários, links e retornos brutos ficam em armazenamento protegido.
6. O Appsmith não substitui a máquina de estados; apenas apresenta ações válidas.
7. O Power BI não pode criar, corrigir ou atualizar propostas.
8. O primeiro ambiente será de desenvolvimento e usará apenas dados sintéticos.

## Implantação progressiva

A mudança não interrompe o fluxo principal. Ela será implementada nas tasks já existentes:

- **BKL-016:** schema, criptografia/tokenização, RLS, backup, storage e secrets;
- **BKL-018:** autenticação e perfis no Supabase/Appsmith;
- **BKL-020:** trilha de auditoria no PostgreSQL;
- **BKL-024:** memória e máquina de estados persistidas;
- **BKL-035:** painel Appsmith para filas, sessões, erros e pendências;
- **BKL-048:** KPIs operacionais e futura avaliação do Power BI.

## Fundação BKL-016 preparada no código

A base está modelada em três schemas:

- `public`: dados operacionais mascarados, códigos, estados e referências;
- `app_private`: somente ciphertext e referências protegidas, fora dos schemas expostos pela API;
- `audit`: eventos mínimos append-only, sem valores sensíveis completos.

As chaves ficam em KMS/cofre externo; o PostgreSQL guarda somente o ciphertext e o alias da chave. O Storage usa buckets privados, objetos nomeados por UUID/hash e URLs assinadas efêmeras. RLS nega acesso sem perfil e impede acesso direto às tabelas privadas.

Nenhum papel PostgREST grava diretamente em `app_private`. A escrita/leitura de ciphertext por n8n/Gateway usará futuramente uma credencial PostgreSQL backend dedicada, guardada no cofre e limitada por grants, sem adicionar o schema privado a `api.schemas`. O Appsmith continuará apenas na API operacional e nunca receberá `service_role`.

Propostas exigem `final_authorization_evidence_payload_ref` válido e protegido. Máscaras operacionais de CPF/telefone devem conter `*` e não podem preservar a sequência numérica completa.

Essa arquitetura foi aplicada somente no projeto Supabase isolado de desenvolvimento `cbn-dev`, sem seed ou dados reais. Appsmith, n8n, Gateway e Power BI não foram conectados nesta etapa; produção permanece intocada.

### Gate para o primeiro ambiente remoto

A fase remota deve usar somente projeto Supabase isolado e claramente marcado como desenvolvimento. O fluxo possui dois gates humanos: primeiro antes de `supabase link`; depois do vínculo somente leitura e de `supabase db push --dry-run`, novamente antes de qualquer aplicação.

O runbook `docs/BKL-016_REMOTE_DEV_RUNBOOK.md` e os scripts `supabase-remote-preflight.ps1`, `supabase-remote-validate.ps1` e `supabase-remote-cleanup.ps1` bloqueiam branch/árvore inadequadas, alvo não confirmado, possível produção, dados não sintéticos, segredo, schema privado exposto e migration sem revisão. A limpeza aceita apenas manifesto local ignorado com IDs e objetos sintéticos explícitos.

Na preparação de 15/07/2026, o projeto isolado `cbn-dev` foi confirmado, vinculado e inspecionado antes de escrita. A migration-base foi aplicada sem seed. Depois do hardening corretivo, as migrations `20260715` e `20260716` ficaram conciliadas, as 13 tabelas esperadas permaneceram sem linhas estimadas e os dois marcadores da validação SQL remota foram atingidos. Nenhum usuário Auth, fixture persistente ou integração n8n/Appsmith foi criado.

A primeira validação estrutural remota detectou que default privileges do projeto concederam acesso operacional a `anon`, apesar da ausência de policy. A arquitetura passa a exigir revogação explícita de `PUBLIC` e `anon` em cada tabela operacional, além de RLS. A migration incremental aplicou essa correção e a repetição integral da suíte comprovou grants, RLS, funções `SECURITY DEFINER`, integridades, snapshot e auditoria append-only.

Os quatro buckets esperados foram confirmados privados, sem policy pública e sem objeto persistente. A CLI experimental inicialmente recusou upload remoto com `Unsupported operation`; a lacuna foi depois fechada pelo runtime backend oficial, sem colocar credencial administrativa em navegador ou cliente.

O runtime real de Storage foi preparado separadamente em backend Node.js com a biblioteca oficial `@supabase/supabase-js` fixada. O controle exige um único bucket temporário privado, objeto UUID, conteúdo sintético em memória, upload sem overwrite, confirmação de metadados e SHA-256, acesso anônimo não-2xx, URL assinada de 30 a 60 segundos, falha pós-expiração e remoção no `finally`. Um wrapper PowerShell mantém a credencial apenas em variável do processo ou entrada oculta e encadeia a revalidação SQL depois da limpeza.

Após o gate humano, o runtime real confirmou bucket privado, upload sintético, acesso anônimo `4xx`, hash idêntico antes da expiração, falha `4xx` após 36 segundos para TTL nominal de 30 segundos, varredura sem vazamento, remoção e revalidação SQL. A listagem recursiva final encontrou zero objetos. A credencial existiu somente no processo backend; produção, navegador, Appsmith e n8n permaneceram sem credencial administrativa.

Para criptografia de aplicação, a recomendação é KMS gerenciado com envelope encryption: um DEK por gravação/objeto, AES-256-GCM local e KEK mantida no KMS, com alias versionado no banco. [Cloud KMS](https://docs.cloud.google.com/kms/docs/envelope-encryption) documenta esse modelo; [Vault Transit](https://developer.hashicorp.com/vault/docs/secrets/transit) permanece alternativa quando houver capacidade operacional própria, e um secrets manager simples fica restrito a credenciais. A escolha do provedor e a criação de chaves continuam pendentes.

O painel confirmou que o `cbn-dev` está no plano Free: não há backup agendado e PITR exige plano/add-on pago. Um dump manual somente de schema foi gerado, verificado sem dados ou credenciais e removido; restauração gerenciada e teste de recuperação continuam pendentes.

## Sessões previstas

- sessão CLT;
- sessão FGTS;
- sessão Propostas/Status.

Cada sessão possui fila exclusiva e somente uma operação ativa.

## Contrato interno do Gateway

O atendimento e o sistema interno chamam operações internas, por exemplo:

- `consultar_clt`;
- `consultar_fgts`;
- `criar_proposta`;
- `consultar_status`.

O Gateway converte a operação para API, MTProto ou contingência sem expor essa decisão ao agente comercial ou ao Appsmith.

## Idempotência

Cada operação deve possuir um `operation_id` persistente.

Regras:

1. gerar ou receber o `operation_id` antes do primeiro envio;
2. persistir o estado antes de executar efeito externo;
3. derivar um identificador determinístico de envio;
4. em retry, reutilizar o mesmo identificador;
5. nunca reenviar cegamente após timeout;
6. consultar histórico/estado antes de repetir uma etapa;
7. confirmação de proposta exige trava adicional e autorização final.

## Lock por sessão

Campos mínimos do lock:

- `session_id`;
- `operation_id`;
- `status`;
- `lease_expires_at`;
- `heartbeat_at`;
- `current_step`.

O lock deve expirar de forma segura e retornar a operação para revisão ou retry idempotente.

## Estados mínimos da operação

- `RECEIVED`;
- `LOCK_ACQUIRED`;
- `COMMAND_PREPARED`;
- `COMMAND_SENT`;
- `WAITING_RESPONSE`;
- `RESPONSE_RECEIVED`;
- `NORMALIZED`;
- `COMPLETED`;
- `RETRY_PENDING`;
- `HUMAN_REVIEW`;
- `FAILED_FINAL`.

## Observabilidade

Registrar:

- `operation_id`;
- produto;
- sessão;
- etapa;
- tentativa;
- tempo de resposta;
- retorno bruto mascarado;
- retorno normalizado;
- erro;
- decisão de retry;
- origem da alteração.

A trilha canônica ficará no PostgreSQL protegido. O Appsmith exibirá somente o necessário para operação; o Sheets poderá receber resumo exportado.

Nunca registrar segredo ou documento completo.

## Segurança

- `api_id`, `api_hash` e sessão em cofre de secrets;
- 2FA nas contas;
- revogação e rotação documentadas;
- logs mascarados;
- permissões mínimas;
- RLS no banco;
- backups e recuperação testados;
- nenhuma credencial no GitHub.
