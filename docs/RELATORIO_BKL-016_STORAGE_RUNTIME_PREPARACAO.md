# Relatório BKL-016 — preparação e execução do runtime de Storage

**Data:** 15/07/2026
**Estado:** runtime remoto, limpeza e revalidação SQL concluídos no desenvolvimento isolado

## Escopo e segurança

O trabalho ocorreu somente na branch `codex/bkl-016-storage-runtime`, criada a partir de `origin/main` atualizada. Não houve merge, deploy, seed remoto, rollback remoto, acesso a produção, conexão com n8n/Appsmith/Telegram, criação de usuário Auth ou uso de dado real. Após o gate humano, uma chave backend foi fornecida por entrada oculta e existiu somente no processo descartável.

Nenhum project-ref, chave, senha, JWT, URL assinada ou header de autorização está registrado neste relatório. O vínculo local preexistente permanece ignorado pelo Git.

## Diagnóstico sanitizado

| Item | Resultado |
|---|---|
| branch inicial após criação | `codex/bkl-016-storage-runtime` |
| base da branch | `322afc4 docs: add Codex prompt for BKL-016 Storage runtime validation` |
| distância inicial de `origin/main` | `0 0` |
| árvore inicial | limpa |
| Supabase CLI | `2.109.1` |
| Node.js | `v24.18.0` |
| npm | `11.16.0` |
| preflight remoto sem credencial backend | aprovado; migrations esperadas conciliadas e bucket temporário localizado, com alvo omitido |

O shim `npm.ps1` foi bloqueado pela política de execução já existente no Windows. Nenhuma política do sistema foi alterada; os comandos npm foram executados por `npm.cmd`.

## Implementação preparada

O backend usa `@supabase/supabase-js` `2.110.6`, dependência oficial fixada e isolada em `scripts/`. O runtime:

- exige branch, ambiente, vínculo e alvo coerentes;
- usa somente `cbn-temporary-private` e confirma `public=false` antes do upload;
- cria nome UUID e conteúdo sintético aleatório com o marcador `BKL016_STORAGE_SYNTHETIC_ONLY`, ambos em memória;
- consulta previamente o objeto e usa upload com `upsert: false`;
- confirma existência, tamanho e SHA-256;
- exige resposta anônima não-2xx;
- cria URL assinada nominal de 30 segundos, configurável somente entre 30 e 60 segundos;
- valida SHA-256 antes da expiração e exige não-2xx depois dela, com margem padrão de 5 segundos e tolerância máxima de 15 segundos;
- procura chave, token, URL e conteúdo sintético em arquivos, saída e histórico Git;
- remove o objeto em `finally` e confirma ausência por listagem e download;
- reexecuta a validação SQL remota somente depois do runtime e da limpeza.

O wrapper aceita a credencial somente na variável de processo `CBN_SUPABASE_BACKEND_KEY` ou por prompt oculto. O modo recomendado é o prompt, que evita argumento e histórico de shell, usa a variável apenas no processo filho e limpa a memória nativa/variáveis ao terminar.

## Testes locais executados

Os 9 testes Node.js passaram:

1. bucket fora da allowlist;
2. nome de objeto fora do padrão UUID;
3. tentativa de overwrite;
4. URL divergente do alvo confirmado;
5. execução na `main`;
6. ausência de confirmação sintética;
7. ausência de credencial local;
8. tentativa de imprimir/persistir URL assinada;
9. TTL fora da janela curta.

O parser do PowerShell aprovou o preflight, o wrapper e o validador. O validador estático aprovou estrutura, seed sintético e varredura de segredo/CPF. `git diff --check` também passou durante a preparação.

O preflight remoto sanitizado passou usando somente a autenticação já existente da CLI e o vínculo local ignorado. Após o gate, a primeira chamada autenticada confirmou `public=false` antes do upload. O ciclo real aprovou upload, metadados, SHA-256, negação anônima, download pré-expiração, expiração, varredura e limpeza. A validação SQL remota foi repetida e terminou com estado seguro `complete/passed`.

## Comandos executados

Valores sensíveis e identificadores remotos foram omitidos por desenho:

```powershell
git status
git branch --show-current
git log -1 --oneline
git fetch origin --prune
git rev-list --left-right --count origin/main...HEAD
git switch -c codex/bkl-016-storage-runtime origin/main
supabase --version
node --version
npm.cmd --version
npm.cmd view @supabase/supabase-js version engines --json
npm.cmd install --prefix scripts
npm.cmd test --prefix scripts
git diff --check
powershell.exe -ExecutionPolicy Bypass -File .\scripts\validate-bkl016.ps1
powershell.exe -ExecutionPolicy Bypass -File .\scripts\supabase-remote-preflight.ps1 -Phase StorageRuntime <confirmações seguras, sem valor sensível>
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\supabase\.temp\run-bkl016-storage-runtime.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\supabase\.temp\run-bkl016-remote-validation.ps1
```

Também foi feita validação sintática dos arquivos PowerShell pela API de parser do próprio PowerShell. Nenhum comando de `supabase link`, `supabase db push`, seed, reset ou rollback foi executado nesta fase.

## Gate humano atual

O gate foi atravessado somente após confirmação explícita do operador. A entrada ficou oculta, não foi enviada ao chat e foi removida do processo pelo wrapper. O valor não foi salvo em `.env`, perfil, arquivo, screenshot, relatório ou Git.

## Marcadores finais

Os seis marcadores obrigatórios foram comprovados:

| Marcador | Resultado |
|---|---|
| `BKL-016 Storage upload passed` | aprovado; 94 bytes e SHA-256 registrado somente como evidência sanitizada |
| `BKL-016 anonymous access denied` | aprovado; resposta `4xx` |
| `BKL-016 signed URL pre-expiry download passed` | aprovado; 94 bytes e hash idêntico |
| `BKL-016 signed URL expiration passed` | aprovado; TTL nominal 30 s, expiração observada em 36 s, resposta `4xx` |
| `BKL-016 Storage cleanup passed` | aprovado; remoção confirmada por listagem/download e listagem recursiva final com zero objetos |
| `BKL-016 Storage runtime validation passed` | aprovado após revalidação SQL `complete/passed` |

O tempo nominal foi 30 segundos e a falha pós-expiração foi observada em 36 segundos, dentro da margem limitada. A URL assinada nunca foi impressa. A varredura local passou enquanto os valores efêmeros ainda estavam em memória; a varredura SQL remota e a inspeção do Git passaram depois da limpeza. A listagem recursiva final do bucket temporário retornou zero objetos.

## Falhas encontradas e correções

- `npm` via shim PowerShell falhou pela política local; foi usado `npm.cmd`, sem alterar o sistema operacional ou a política.
- o primeiro nome de script npm não oferecia o alias padrão `test`; o alias foi adicionado.
- o scanner interpretou a versão numérica concatenada de uma migration como possível CPF; o preflight passou a derivar a versão a partir do nome com separador, preservando a detecção de CPF real.
- a CLI envia mensagens normais de progresso pelo canal de erro e retorna JSON nesta instalação; o preflight passou a capturar o código real, descartar progresso e validar o JSON explicitamente. Depois da correção, o preflight passou.
- a captura de saída do primeiro executor interativo impediu o segundo `Read-Host`; o runtime já havia concluído e removido o objeto. A revalidação SQL foi então executada diretamente, com senha em entrada oculta, e terminou `complete/passed`.

## Arquivos criados ou alterados

- `.gitignore`;
- `scripts/package.json`;
- `scripts/package-lock.json`;
- `scripts/supabase-storage-runtime-test.mjs`;
- `scripts/supabase-storage-runtime-test.test.mjs`;
- `scripts/supabase-storage-runtime-run.ps1`;
- `scripts/supabase-remote-preflight.ps1`;
- `scripts/validate-bkl016.ps1`;
- `supabase/tests/bkl016_remote_validation.sql`;
- `docs/BKL-016_ARMAZENAMENTO_DADOS_SENSIVEIS.md`;
- `docs/BKL-016_REMOTE_DEV_RUNBOOK.md`;
- `docs/BACKLOG_CHECKPOINT.md`;
- `docs/HANDOFF.md`;
- `docs/ARQUITETURA_TECNICA.md`;
- `README.md`;
- este relatório.

`telegram-gateway/` e `.env.example` não foram alterados.

## Riscos e pendências

- futuras repetições podem variar alguns segundos por tolerância de relógio, limitada no script;
- KMS/cofre, rotação, restauração, retenção, legal hold e policies finais continuam pendentes;
- revisão independente ainda é necessária;
- a BKL-016 geral permanece **Em andamento**.

Não houve merge, produção, n8n, Appsmith, Telegram, dado real ou credencial persistida nesta execução.
