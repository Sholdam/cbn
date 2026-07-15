# Prompt Codex — BKL-016 fase remota de desenvolvimento

Execute esta tarefa no repositório `Sholdam/cbn`.

## Classificação

- Projeto: CBN
- Tarefa: BKL-016 — fase remota isolada de desenvolvimento
- Esforço: 9/10
- Regra DE-003: executar pelo Codex em branch separada, sem merge ou deploy automático

## Objetivo

Preparar e, somente após autorização manual do usuário, validar a fundação da BKL-016 em um projeto Supabase remoto **isolado de desenvolvimento**, sem clientes reais, sem conexão com n8n, Appsmith, Telegram, Meta ou WhatsApp.

A fase local já foi validada e integrada na `main`. Esta etapa deve transformar essa fundação em um processo remoto reproduzível, auditável e seguro.

## Regras inegociáveis

1. Nunca usar projeto de produção.
2. Nunca usar dados reais, CPF real, RG, endereço, telefone, conta bancária, contrato ou link de assinatura real.
3. Nunca colocar senha, token, JWT, `service_role`, chave de banco, chave de criptografia ou sessão em:
   - Git;
   - prompt;
   - relatório;
   - terminal compartilhado;
   - screenshot;
   - documentação.
4. Não alterar `telegram-gateway/`.
5. Não conectar n8n ou Appsmith nesta tarefa.
6. Não criar política pública de Storage.
7. Não expor `app_private` ou `audit` no PostgREST.
8. Não executar merge na `main`.
9. Não aplicar migration em projeto remoto antes de uma parada de autorização explícita.
10. Não solicitar que o usuário cole credenciais no chat ou em arquivos versionados.

## Estado inicial esperado

A `main` deve conter o merge da fundação local BKL-016, incluindo:

- migration segura;
- seed sintético;
- suíte SQL/RLS;
- rollback;
- validador PowerShell;
- documentação da BKL-016.

Commit de referência da última correção local:

`f1255cdfe75c17158d17b040670d68234d4744d5`

## Etapa 1 — Preparação da branch

1. Execute:

```powershell
git status
git branch --show-current
git fetch origin
git switch main
git pull --ff-only origin main
git switch -c codex/bkl-016-remote-dev
```

2. Confirme árvore limpa.
3. Leia integralmente:

- `README.md`;
- `docs/HANDOFF.md`;
- `docs/BACKLOG_CHECKPOINT.md`;
- `docs/ARQUITETURA_TECNICA.md`;
- `docs/BKL-016_ARMAZENAMENTO_DADOS_SENSIVEIS.md`;
- `docs/DICIONARIO_DADOS.md`;
- migration, seed, testes e rollback da BKL-016.

## Etapa 2 — Diagnóstico seguro

Execute e registre apenas versões e estados não sensíveis:

```powershell
git log -1 --oneline
docker --version
docker compose version
supabase --version
psql --version
supabase projects list
```

Para `supabase projects list`:

- não exibir tokens;
- não registrar URLs, chaves ou senhas;
- informar somente se existe autenticação CLI ativa e se há projeto de desenvolvimento identificável;
- não escolher projeto automaticamente.

Verifique se existe vínculo remoto local em `supabase/.temp`, `.branches`, configuração ou metadados locais. Esses diretórios devem permanecer ignorados pelo Git.

## Etapa 3 — Entregas preparatórias antes do acesso remoto

Criar, revisar ou atualizar:

1. `docs/BKL-016_REMOTE_DEV_RUNBOOK.md`
2. `scripts/supabase-remote-preflight.ps1`
3. `scripts/supabase-remote-validate.ps1`
4. `scripts/supabase-remote-cleanup.ps1`, somente para objetos sintéticos explicitamente marcados
5. `.gitignore`, apenas se faltar proteção para artefatos locais
6. documentação e handoff afetados

### O preflight deve bloquear

- branch `main`;
- árvore Git suja;
- ausência do marcador de ambiente `CBN_ENVIRONMENT=development`;
- project ref vazio;
- project ref igual a qualquer valor explicitamente marcado como produção;
- tentativa de uso de dados reais;
- presença de `.env` versionado;
- presença de `service_role`, JWT, senha ou chave no repositório;
- vínculo remoto não confirmado pelo usuário;
- migration pendente sem dry-run/revisão;
- qualquer schema privado na lista exposta pelo PostgREST.

### O validador remoto deve verificar

- migration aplicada;
- RLS ativo nas tabelas operacionais;
- roles `admin`, `operations`, `support` e `auditor`;
- usuário autenticado sem perfil sem acesso;
- `anon` sem acesso operacional;
- `app_private` e `audit` não expostos;
- funções `SECURITY DEFINER` com `search_path` seguro;
- grants mínimos;
- buckets privados;
- ausência de política pública;
- integridade cliente/produto/operação;
- evidência final vinculada ao mesmo cliente e operação;
- snapshots de oferta imutáveis;
- auditoria append-only;
- ausência de dados reais;
- ausência de segredo em objetos, logs e documentação.

## Etapa 4 — Parada obrigatória para ação manual do usuário

Antes de qualquer `supabase link`, `db push`, migration remota ou criação de usuário remoto, pare e entregue uma lista curta de ações manuais.

O usuário deverá criar ou selecionar no painel um projeto Supabase exclusivo de desenvolvimento para a CBN.

Requisitos mínimos do projeto:

- nome claramente marcado como desenvolvimento, por exemplo `cbn-dev`;
- organização correta do usuário;
- região escolhida conscientemente;
- senha do banco forte e guardada fora do Git;
- nenhuma integração externa conectada;
- nenhum dado real;
- nenhuma chave compartilhada no chat.

Solicite ao usuário somente confirmação de que o projeto foi criado e o **project ref não secreto**. Não solicitar senha ou token no chat.

A autenticação da CLI deve ocorrer de forma interativa/local ou por mecanismo seguro já configurado na máquina. Nenhuma credencial deve ser escrita por você em arquivo versionado.

Não prossiga até autorização explícita do usuário.

## Etapa 5 — Vinculação e inspeção remota, após autorização

Após o usuário confirmar o projeto isolado:

1. Confirmar novamente a branch `codex/bkl-016-remote-dev`.
2. Executar o preflight.
3. Vincular somente ao project ref informado e confirmado.
4. Verificar o alvo duas vezes antes de qualquer escrita.
5. Inspecionar schema remoto sem alterar.
6. Confirmar que o projeto está vazio ou compatível com a aplicação inicial.
7. Executar o equivalente seguro de dry-run disponível na versão instalada da Supabase CLI.
8. Se a CLI não oferecer dry-run para o comando necessário, gerar e revisar a lista de migrations pendentes e o SQL antes de aplicar.
9. Parar novamente se houver qualquer objeto inesperado, migration divergente ou risco de perda.

## Etapa 6 — Aplicação remota controlada

Somente após o dry-run e nova confirmação explícita:

1. Aplicar migrations no projeto de desenvolvimento.
2. Não executar seed automático indiscriminadamente.
3. Inserir apenas fixtures sintéticas claramente identificadas e removíveis.
4. Criar usuários Auth sintéticos separados para:
   - admin;
   - operations;
   - support;
   - auditor;
   - authenticated sem perfil.
5. Usar e-mails sintéticos controlados, sem pessoas reais.
6. Não guardar senha desses usuários no Git ou relatório.
7. Executar a suíte de validação remota.
8. Registrar somente resultados, IDs mascarados e contagens; nunca credenciais.

## Etapa 7 — Storage remoto

Validar em desenvolvimento:

- buckets privados esperados;
- nenhuma política pública;
- `anon` sem leitura e escrita;
- `support` sem acesso direto a documentos sensíveis;
- `operations` e `admin` somente pelos caminhos definidos;
- objeto sintético com nome UUID/hash sem PII;
- URL assinada temporária não persistida em tabela pública ou log;
- limpeza do objeto sintético ao final.

Não definir política definitiva de produção sem revisão independente. Nesta etapa, preparar uma proposta conservadora e validá-la apenas com artefatos sintéticos.

## Etapa 8 — KMS/cofre

Não inventar uma solução de criptografia.

Produzir uma decisão técnica comparando no máximo três opções compatíveis com o projeto CBN, considerando:

- custo;
- simplicidade;
- rotação de chave;
- recuperação;
- integração com n8n/Gateway;
- segregação entre desenvolvimento e produção;
- risco de exposição no navegador/Appsmith;
- portabilidade futura.

A decisão final depende do usuário e deve ficar registrada como pendência se não for aprovada.

Nenhuma chave real deve ser criada ou versionada nesta tarefa sem autorização específica.

## Etapa 9 — Backup, restauração e retenção

1. Documentar o que o plano atual do Supabase oferece no projeto criado.
2. Não afirmar que existe PITR ou backup gerenciado sem comprovação no painel/projeto.
3. Preparar teste de exportação/restauração somente com dados sintéticos.
4. Não baixar dump com segredo ou credencial embutida.
5. Registrar riscos de retenção legal e `legal hold` como pendência para validação jurídica.

## Etapa 10 — Limpeza e repetibilidade

Ao final dos testes:

- remover usuários e fixtures sintéticas criadas exclusivamente para validação, quando seguro;
- remover objetos sintéticos do Storage;
- manter migrations e estrutura aprovada;
- garantir que nenhum dado real foi criado;
- executar novamente o validador remoto;
- confirmar que o projeto permanece isolado e sem integrações.

## Validações obrigatórias

```powershell
git diff --check
powershell.exe -ExecutionPolicy Bypass -File .\scripts\validate-bkl016.ps1
powershell.exe -ExecutionPolicy Bypass -File .\scripts\supabase-remote-preflight.ps1
powershell.exe -ExecutionPolicy Bypass -File .\scripts\supabase-remote-validate.ps1
```

Também confirmar:

- `telegram-gateway/` inalterado;
- nenhum `.env` real;
- nenhum segredo no histórico ou diff;
- nenhum cliente real;
- nenhum vínculo com produção;
- nenhuma conexão com n8n/Appsmith;
- nenhuma política pública de Storage.

## Status e documentação

Atualizar:

- `docs/HANDOFF.md`;
- `docs/BACKLOG_CHECKPOINT.md`;
- `docs/ARQUITETURA_TECNICA.md`;
- `docs/BKL-016_ARMAZENAMENTO_DADOS_SENSIVEIS.md`;
- `docs/BKL-016_REMOTE_DEV_RUNBOOK.md`;
- `README.md`, somente se necessário.

A BKL-016 só pode ser marcada como concluída quando os critérios explicitamente definidos no backlog estiverem atendidos. A validação remota de desenvolvimento não significa produção pronta.

## Commit e entrega

Usar branch:

`codex/bkl-016-remote-dev`

Não fazer merge.

Mensagens sugeridas:

- preparação antes do acesso remoto:
  `chore: prepare BKL-016 remote development validation`
- correções após validação:
  `fix: validate BKL-016 in isolated Supabase development`

Entregar relatório com:

- branch e commit;
- arquivos alterados;
- comandos executados;
- ponto exato em que pediu autorização manual;
- identificação não sensível do ambiente validado;
- migration e testes executados;
- resultados de RLS e Storage;
- fixtures criadas e removidas;
- backup/restauração testados ou motivo da pendência;
- decisão de KMS/cofre ou pendência;
- riscos restantes;
- confirmação de ausência de segredo e dados reais.
