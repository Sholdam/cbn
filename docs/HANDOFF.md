# Handoff — CBN Crédito

## Identidade mínima do backend — 16/07/2026

- Branch `codex/bkl-016-backend-identity` preparada, sem merge ou aplicação remota.
- Quatro papéis `NOLOGIN` separam Gateway, operador de retenção, revisor de hold
  e executor de descarte; nenhum possui acesso direto a tabelas privadas/auditoria.
- Operações sensíveis usam somente wrappers `SECURITY DEFINER` tipados, com
  `search_path = ''` e grants mínimos.
- O operador que prepara o descarte não consegue concluí-lo; remoção de hold
  permanece dependente de revisor técnico distinto.
- 44 testes Node, cinco suítes SQL, rollback fail-closed, rollback limpo e
  reaplicação passaram em Supabase local descartável.
- Nenhuma credencial real foi criada. `service_role` não é a identidade final.
- BKL-016 continua **Em andamento**: login técnico futuro, KMS real, jurídico,
  backup remoto, aplicação autorizada e revisão independente seguem pendentes.

## Revisão corretiva da retenção — 16/07/2026

- Corrigidos os bloqueadores de auditoria, inventário de anonimização e escopo do
  legal hold em migration incremental `20260719_001`.
- Negações de política agora persistem `RETENTION_EVALUATED allowed=false` e o
  evento `ANONYMIZATION_DENIED` ou `DELETION_DENIED` sem continuar o descarte.
- Hold de cliente protege payload/arquivo relacionado e é revalidado antes do
  Storage e da conclusão do banco.
- Reidentificação pública ou privada de cliente anonimizado é bloqueada por
  triggers; dependências que exigem política própria recusam anonimização.
- Solicitante e aprovador da remoção do hold precisam ser distintos.
- Quatro suítes SQL, 36 testes Node, runtime Storage, rollback e reaplicação
  passaram localmente; nenhum ambiente remoto foi acessado.
- BKL-016 continua **Em andamento** e a branch não foi mesclada.

## Atualização 16/07/2026 — retenção e legal hold local

- Branch `codex/bkl-016-retention-legal-hold` preparada sem merge.
- Migration incremental `20260718` adiciona políticas configuráveis, controles
  privados, legal hold, anonimização idempotente e descarte em duas fases.
- Runtime local comprovou remoção do objeto Storage e só concluiu o banco após a
  verificação de ausência; falha simulada permaneceu pendente.
- Backup posterior à anonimização foi restaurado sem reintroduzir identificadores.
- Rollback recusou estado novo e funcionou em base descartável limpa.
- Nenhum prazo jurídico foi definido. Dados reais e produção continuam proibidos.
- Google Cloud KMS real segue bloqueado temporariamente por faturamento.
- BKL-016 permanece **Em andamento**, aguardando política jurídica, KMS real,
  identidade backend mínima, aplicação remota autorizada e revisão independente.

**Atualizado em:** 16/07/2026, após backup, restauração e recuperação sintética local da BKL-016
**Projeto:** CBN — operação autônoma de varredura e venda de crédito  
**Escopo inicial:** FGTS + Crédito do Trabalhador (CLT)

## Objetivo

Construir uma operação autônoma com captação pela Meta, atendimento no WhatsApp, consentimento, consulta dos dois produtos, consolidação das ofertas, digitação das propostas aceitas, acompanhamento e intervenção humana somente em exceções.

## Decisões estruturais vigentes

1. A varredura padrão consulta **FGTS e CLT** após consentimento e dados suficientes.
2. As ofertas devem vir somente dos sistemas reais; o agente não inventa banco, valor, prazo ou taxa.
3. O atendimento não fala diretamente com Telegram ou Prospecta. O n8n utilizará um **Gateway interno**.
4. Cada sessão Telegram processará somente uma operação ativa por vez.
5. Cada operação terá `operation_id` persistente para impedir duplicidade em timeout ou retry.
6. Proposta real somente com autorização final expressa do cliente/operador.
7. Status bruto, status normalizado, ação pendente, motivo e link são campos independentes.
8. CPF, RG, endereço, dados bancários, sessão Telegram e links operacionais ficam fora de planilhas e logs abertos.
9. **Supabase/PostgreSQL será a fonte principal de dados e memória operacional.**
10. **Appsmith será o sistema interno da equipe**, usado para clientes, consultas, ofertas, propostas, pendências, filas e monitoramento.
11. **n8n e Gateway continuam responsáveis por regras, integrações e execução.** A interface não deve concentrar lógica crítica.
12. **Power BI será opcional e somente analítico**, após existir volume real e dados confiáveis. Não será CRM nem sistema operacional.
13. **Toda atividade recebe uma estimativa de esforço de 1 a 10 antes da execução.**
14. **Atividades com esforço de 1 a 6 podem ser executadas diretamente no ChatGPT/conectores.**
15. **Atividades com esforço de 7 a 10 devem ser transformadas em prompt estruturado para o Codex**, executadas em branch própria e revisadas antes de merge ou deploy.
16. Codex não substitui revisão: toda entrega complexa passa por inspeção do diff, testes, segurança, documentação e aceite do usuário.

## DE-002 — Supabase + Appsmith + n8n; Power BI analítico

A implantação será progressiva, sem interromper a construção do fluxo principal:

- BKL-016: Supabase/PostgreSQL, criptografia, tokenização, RLS, backup e secrets;
- BKL-018: Supabase Auth/RLS e perfis equivalentes no Appsmith;
- BKL-020: trilha de auditoria canônica no PostgreSQL;
- BKL-024: memória e máquina de estados persistidas na base;
- BKL-035: tela Appsmith de monitoramento operacional;
- BKL-048: indicadores no Appsmith e avaliação posterior do Power BI.

O protótipo começa em ambiente isolado, sem dados reais. O Google Sheets permanece como apoio, exportação e contingência durante a transição.

## DE-003 — Escalonamento por esforço ao Codex

### Escala adotada

- **1–3:** atividade simples, localizada e de baixo risco;
- **4–6:** atividade moderada, com poucas dependências e revisão direta;
- **7–8:** atividade complexa, com múltiplos arquivos, integrações, migrations, testes ou risco de regressão;
- **9–10:** atividade crítica, com segurança, dados sensíveis, infraestrutura, arquitetura ou impacto amplo.

### Regra operacional

1. estimar o esforço antes de iniciar;
2. informar a nota no começo da atividade quando ela for relevante;
3. para esforço **7 ou maior**, criar `docs/PROMPT_CODEX_<TAREFA>.md`;
4. o prompt deve conter contexto, escopo, restrições, critérios de aceite, testes, segurança, arquivos esperados e formato do relatório final;
5. o Codex trabalha em branch própria, sem merge e sem deploy automático;
6. após a execução, revisar diff, testes, migrations, documentação, segredos e riscos;
7. somente depois da revisão e do aceite do usuário a mudança pode ser integrada.

### Exceções

- ações que dependem de login, segredo, pagamento, autorização, ambiente real ou interface do usuário continuam manuais;
- o Codex pode preparar código, scripts e instruções, mas não deve receber credenciais reais;
- uma urgência só pode quebrar essa regra com autorização explícita do usuário.

A BKL-016 foi classificada como **9/10** e já possui o arquivo `docs/PROMPT_CODEX_BKL-016.md`.

## Checkpoint técnico concluído

- três contas Telegram vinculáveis;
- CLT e FGTS simultâneos, sem mistura de contexto;
- conta de status com acesso cruzado às propostas;
- sessão MTProto persistente após reinício;
- retry idempotente com o mesmo `operation_id` e somente uma mensagem enviada.

A rota provisória do MVP é:

1. API oficial da fornecedora, quando disponível e comprovada;
2. MTProto com contas separadas enquanto isso;
3. Telegram Web RPA apenas como contingência.

A **BKL-014** está concluída.

## BKL-012 — mapeamento das propostas

### CLT confirmado

1. banco e oferta;
2. RG somente números; RG novo pode usar CPF;
3. órgão emissor;
4. UF emissora;
5. data `DD/MM/AAAA`, rejeitando data inválida ou futura;
6. código COMPE;
7. agência sem dígito ou possibilidade de pular;
8. conta com dígito e separador;
9. tipo de conta;
10. revisão e correção;
11. confirmação final;
12. criação e protocolo.

O endereço veio automaticamente do cadastro no fluxo observado. Só deve ser solicitado se o sistema pedir correção.

### FGTS pendente

A consulta, os pré-requisitos e os retornos sem oferta foram confirmados. Os campos pós-oferta continuam como **A confirmar FGTS** até surgir cliente autorizado com oferta real.

## BKL-013 — acompanhamento CLT

Já foram observados:

- proposta criada;
- consulta por número de contrato;
- status `Em análise de compliance`;
- assinatura pendente;
- motivo operacional;
- link de assinatura/coleta.

O parser deve manter separados:

- `status_raw`;
- `status_normalizado`;
- `acao_pendente`;
- `motivo_raw`;
- `link_assinatura_ref`;
- `last_checked_at`.

## BKL-015 — Dicionário de Dados multiproduto

**Status: Concluído v1.**

Foi criada na planilha a aba `Dicionário de Dados`, com `DD-001` a `DD-072`, cobrindo:

1. Cliente;
2. Consulta;
3. Oferta;
4. Proposta;
5. Interação;
6. Pendência;
7. Operação técnica.

Também foram alinhadas as estruturas operacionais:

- `Clientes`;
- `Consultas`;
- `Ofertas`;
- `Propostas`;
- `Interações`;
- `Pendências`;
- `Operações Técnicas`.

As abas agora usam identificadores próprios, referências entre entidades, produto separado, `operation_id`, aliases, códigos, estados normalizados e versões mascaradas.

### Regras de segurança incorporadas

- CPF completo: referência segura ou tokenização;
- planilha: somente CPF mascarado;
- RG, endereço e conta bancária: storage criptografado;
- sessão MTProto: cofre de secrets; operação usa somente `session_alias`;
- link de assinatura: referência protegida;
- retorno bruto e logs: storage protegido, mascaramento e retenção;
- retry: mesmo `operation_id`; `random_id` determinístico na rota MTProto.

Campos FGTS ainda não observados entram como manutenção do dicionário, sem reabrir a arquitetura.

## Próxima tarefa

### BKL-016 — Base protegida e fundação do sistema interno

**Status: Em andamento.**

**Esforço estimado: 9/10 — execução pelo Codex, com revisão obrigatória.**

Decisão inicial aprovada:

- Supabase/PostgreSQL como base principal;
- Appsmith como interface interna futura;
- Sheets como apoio temporário;
- Power BI somente depois, para dashboards gerenciais.

Próximas ações:

1. o usuário cria ou seleciona manualmente um projeto Supabase exclusivo de desenvolvimento, vazio e sem integrações;
2. o usuário confirma somente a criação e o project ref não secreto;
3. após autorização explícita, executar o preflight na fase `LinkInspection` e conferir o alvo duas vezes;
4. vincular somente ao projeto confirmado, inspecionar sem alterar e executar `supabase db push --dry-run`;
5. parar novamente para revisão e nova autorização antes de qualquer migration remota;
6. validar RLS, Storage e integridades somente com transações/fixtures sintéticas removíveis;
7. registrar a decisão de KMS/cofre, backup, retenção, anonimização e recuperação;
8. manter Appsmith e n8n desconectados durante toda esta tarefa.

### Preparação em código realizada em 15/07/2026

- criada migration reversível/revisável para schemas `public`, `app_private` e `audit`;
- criadas as estruturas mínimas operacionais, privadas, perfis e auditoria append-only;
- RLS ativada com negação por padrão e papéis iniciais conservadores;
- buckets privados preparados sem policy pública;
- criado seed exclusivamente sintético;
- criados teste SQL e varredura estática de segredo/CPF;
- criada documentação de acesso, Storage, cofre, retenção, anonimização, backup e aplicação.

Naquela preparação inicial a migration ainda não havia sido aplicada. Posteriormente ela foi aplicada somente no projeto isolado `cbn-dev`; produção, usuários reais, KMS/cofre, policies finais de Storage, restauração e retenção legal permanecem intocados ou pendentes. A BKL-016 continua **Em andamento** até essas validações e revisão independente.

### Correções da revisão técnica preparadas

- corrigida a constraint de `interactions.event_type`;
- máscaras de CPF e telefone agora exigem `*` e rejeitam sequências completas;
- proposta exige evidência de autorização vinculada a `app_private.protected_payloads`;
- a FK da autorização final compara payload, cliente, operação e tipo; uma evidência de outro dono não pode ser reutilizada;
- a evidência final nasce ligada ao cliente e à operação antes da proposta, evitando dependência circular;
- consultas e propostas validam `operation_id`, cliente e produto por FK composta, impedindo reutilização cruzada de operação;
- rollback local respeita a proteção do Supabase Storage e remove somente buckets vazios;
- rollback reordenado para remover dependências privadas antes das tabelas públicas;
- testes SQL passaram a usar usuários Auth sintéticos, troca de role/claims e operações reais de RLS;
- `anon` perdeu permissões de execução desnecessárias;
- escrita futura de ciphertext foi definida como conexão PostgreSQL backend dedicada, fora do PostgREST.

Em 15/07/2026, migration, seed, suíte SQL/RLS, rollback com preservação de bucket contendo objeto e reaplicação foram aprovados em Supabase local descartável. A suíte terminou duas vezes com `BKL-016 database and RLS checks passed`. Nenhum projeto remoto foi vinculado, e nenhum deploy foi realizado.

### Preparação da fase remota realizada em 15/07/2026

- criada a branch `codex/bkl-016-remote-dev` a partir da `main` atualizada por fast-forward;
- diagnóstico confirmou Docker 29.6.1, Compose 5.3.0, Supabase CLI 2.109.1 e psql 17.10;
- a CLI Supabase foi autenticada interativamente pelo usuário e o projeto isolado `cbn-dev` foi confirmado duas vezes pelo ref não secreto;
- o vínculo local corresponde ao alvo confirmado e seus metadados permanecem ignorados em `supabase/.temp`/`.branches`;
- criado `docs/BKL-016_REMOTE_DEV_RUNBOOK.md` com duas paradas humanas e proibição de credenciais no chat;
- criados preflight, validador remoto, limpeza por manifesto sintético e teste estrutural remoto;
- o preflight falha de forma segura sem ambiente, alvo, confirmação e revisão do dry-run;
- `app_private` e `audit` continuam fora da lista local de schemas expostos;
- `.gitignore` já protegia os metadados locais da CLI e não precisou ser alterado.

Após autorização, o `supabase link` foi concluído sem senha em argumento. A inspeção somente leitura confirmou histórico remoto de migrations vazio, migration local `20260715` pendente e nenhuma tabela reportada pelo inspetor. Com autorização separada, `supabase db push --dry-run --linked` listou somente `20260715_001_bkl016_secure_storage.sql` e não fez escrita.

Após uma terceira autorização explícita, `supabase db push --linked` aplicou somente `20260715_001_bkl016_secure_storage.sql`, sem seed. A primeira validação remota encontrou grant indevido de `anon`; a migration corretiva `20260716_001_bkl016_revoke_anon_operational_grants.sql` passou em dry-run, foi aplicada sem seed e conciliou o histórico local/remoto.

Depois da correção, a validação estrutural e a suíte transacional completa passaram. RLS e integridades foram exercitadas com claims/papéis sintéticos; todas as fixtures terminaram em `ROLLBACK`, nenhum usuário Auth foi criado e as 13 tabelas ficaram com zero linhas estimadas. Os buckets privados e a ausência de policy pública foram confirmados.

O primeiro upload pela CLI experimental foi recusado antes de criar objeto; essa lacuna foi posteriormente fechada pelo runtime backend validado abaixo. O plano Free não oferece backup agendado nem PITR; dump manual somente de schema passou, mas restauração não foi comprovada. KMS gerenciado com envelope encryption é a recomendação técnica, ainda pendente de provedor/aprovação. A BKL-016 continua **Em andamento**, sem integração n8n/Appsmith e sem alteração em produção.

### Runtime de Storage validado

A branch `codex/bkl-016-storage-runtime` parte da `main` atualizada e contém preflight reforçado, wrapper PowerShell com entrada oculta e teste Node.js backend usando `@supabase/supabase-js` `2.110.6`. O fluxo está limitado ao bucket temporário, a objeto UUID/conteúdo sintético em memória, URL assinada nominal de 30 segundos, hash SHA-256, negação anônima, varredura de vazamento e limpeza em `finally`.

Os 9 testes negativos locais e o preflight remoto sanitizado passaram. Após o gate humano, o ciclo real aprovou upload de 94 bytes, negação anônima `4xx`, SHA-256 antes da expiração, falha `4xx` após 36 segundos para TTL de 30 segundos, varredura local, limpeza e revalidação SQL `complete/passed`. A listagem recursiva final encontrou zero objetos; chave, senha e URL não foram impressas nem persistidas.

Os seis marcadores finais do runtime foram atingidos. **Ponto exato de retomada:** decidir KMS/cofre e rotação, comprovar restauração, definir retenção/legal hold e revisar policies finais. Não houve produção, n8n, Appsmith, usuário Auth, fixture persistente ou dado real. BKL-016 segue **Em andamento** até essas pendências e revisão independente.

### KMS e envelope validados somente em ambiente local

A branch `codex/bkl-016-kms-envelope` acrescenta contrato KMS neutro, adaptador local bloqueado fora de teste e serviço de envelope com primitivas nativas do Node.js. O formato v1 usa AES-256-GCM, DEK de 32 bytes e nonce de 12 bytes aleatórios por gravação, tag obrigatória e AAD de contexto sem PII. Logs/auditoria ficam limitados a evento, algoritmo, alias e versões.

A migration nova `20260717_001_bkl016_envelope_metadata.sql` foi criada em vez de editar migrations já aplicadas. Ela preserva linhas legadas, rejeita envelope parcial e cobre payloads e referências de arquivos. O rollback incremental falha fechado quando existirem envelopes novos.

Rotação de KEK foi modelada como rewrap da mesma DEK, sem tocar no ciphertext; rotação de DEK descriptografa/recriptografa em memória e conserva o envelope anterior em falha. Testes locais exercitam ambos os fluxos e recuperação. O runbook e relatório desta fase são `docs/BKL-016_KMS_ENVELOPE_RUNBOOK.md` e `docs/RELATORIO_BKL-016_KMS_ENVELOPE_LOCAL.md`.

A comparação oficial de 15/07/2026 mantém três caminhos: KMS gerenciado, Vault Transit e cofre de credenciais mais envelope próprio. A recomendação técnica preliminar é avaliar KMS gerenciado primeiro, mas **nenhum provedor foi escolhido ou acessado e nenhuma chave real foi criada**.

**Ponto exato de retomada:** Guilherme decide provedor/região/custo/IAM/auditoria/recuperação. Parar antes de autenticar, ativar API/billing, criar/importar KEK, criar Vault ou gravar segredo Railway. Depois disso, abrir tarefa separada para adaptador remoto sintético. BKL-016 segue **Em andamento**.

### Backup/restauração sintética local — 16/07/2026

A branch `codex/bkl-016-backup-restore` comprovou, sem conexão remota, backup de schema/dados sintéticos, reconstrução do schema por migrations, restauração do dump, backup/restauração de objeto Storage por hash e recuperação de envelope com KEK local efêmera. A ausência da versão da KEK e a adulteração falharam fechadas; o rollback incremental preservou o envelope.

As suítes SQL/RLS e constraints passaram dentro da prova. RTO local final: **105,08 s**. RPO do teste: snapshot exato; em operação será o intervalo entre backups até haver PITR. Todos os artefatos, objetos e containers foram removidos. Google Cloud KMS real permanece bloqueado por faturamento; dados reais e produção continuam proibidos.

**Ponto de retomada:** retenção/legal hold e policies finais podem avançar localmente. KMS real só retoma após disponibilidade financeira e nova autorização humana. A BKL-016 geral permanece **Em andamento**.

## Tarefas vivas paralelas

- BKL-007 — validação regulatória e operacional;
- BKL-011 — catálogo de produtos contínuo;
- BKL-012 — fluxo FGTS pós-oferta;
- BKL-013 — assinatura, análise, aprovação, pagamento ou cancelamento.

## Arquivos do repositório

- `telegram-gateway/src/auth.js`
- `telegram-gateway/src/check-session.js`
- `telegram-gateway/src/idempotency-test.js`
- `docs/DICIONARIO_DADOS.md`
- `docs/BACKLOG_CHECKPOINT.md`
- `docs/ARQUITETURA_TECNICA.md`
- `docs/PROMPT_CODEX_BKL-016.md`
- `docs/PROMPT_CODEX_BKL-016_REMOTE_DEV.md`
- `docs/BKL-016_REMOTE_DEV_RUNBOOK.md`
- `docs/BKL-016_BACKUP_RESTORE_RUNBOOK.md`
- `docs/PROMPT_CODEX_BKL-016_BACKUP_RESTORE.md`
- `scripts/supabase-remote-preflight.ps1`
- `scripts/supabase-remote-validate.ps1`
- `scripts/supabase-remote-cleanup.ps1`
- `scripts/supabase-storage-runtime-run.ps1`
- `scripts/supabase-storage-runtime-test.mjs`
- `scripts/supabase-storage-runtime-test.test.mjs`
- `.env.example` sem credenciais

## Regras para retomar

1. abrir este handoff;
2. estimar o esforço da próxima atividade em escala de 1 a 10;
3. se o esforço for 7 ou maior, criar prompt para o Codex antes da execução;
4. continuar pela BKL-016;
5. revisar a preparação remota e criar/selecionar somente um Supabase de desenvolvimento isolado, sem dados reais;
6. informar ao Codex apenas a confirmação e o project ref não secreto, nunca senha ou token;
7. implementar Appsmith progressivamente nas tarefas correspondentes, sem parar o fluxo principal;
8. manter BKL-012 e BKL-013 como tarefas vivas não bloqueantes;
9. não gerar nova sessão Telegram sem necessidade;
10. não registrar segredo ou dado completo de cliente em código, planilha, print ou chat;
11. não criar proposta sem autorização final expressa.
