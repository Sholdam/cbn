# Relatório BKL-016 — preparação do runtime de Storage

**Data:** 15/07/2026
**Estado:** código e validações locais preparados; execução parada no gate humano anterior à credencial backend

## Escopo e segurança

O trabalho ocorreu somente na branch `codex/bkl-016-storage-runtime`, criada a partir de `origin/main` atualizada. Não houve merge, deploy, seed remoto, rollback remoto, acesso a produção, conexão com n8n/Appsmith/Telegram, criação de usuário Auth, uso de dado real ou uso de credencial backend.

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
```

Também foi feita validação sintática dos arquivos PowerShell pela API de parser do próprio PowerShell. Nenhum comando de `supabase link`, `supabase db push`, seed, reset ou rollback foi executado nesta fase.

## Gate humano atual

A primeira operação que requer credencial backend **não foi executada**. Para retomar, o operador deve obter no painel do projeto isolado de desenvolvimento uma chave secreta apropriada a backend, sem revelar o valor no chat, e confirmar que está pronto para usar a entrada oculta do wrapper. A variável interna reservada é `CBN_SUPABASE_BACKEND_KEY`; ela não deve ser salva em `.env`, perfil, arquivo, screenshot ou relatório.

## Marcadores finais

Os seis marcadores abaixo estão **não executados**, e não aprovados, porque dependem de atravessar o gate:

| Marcador | Resultado nesta preparação |
|---|---|
| `BKL-016 Storage upload passed` | não executado |
| `BKL-016 anonymous access denied` | não executado |
| `BKL-016 signed URL pre-expiry download passed` | não executado |
| `BKL-016 signed URL expiration passed` | não executado |
| `BKL-016 Storage cleanup passed` | não executado |
| `BKL-016 Storage runtime validation passed` | não executado |

Consequentemente, o tempo nominal configurado é 30 segundos, mas o tempo efetivo observado ainda não existe. Acesso anônimo negado, remoção remota e ausência da URL/credencial no banco após um ciclo real ainda precisam ser comprovados. A varredura local estática passou; a varredura SQL foi ampliada, mas não foi reexecutada nesta preparação.

## Falhas encontradas e correções

- `npm` via shim PowerShell falhou pela política local; foi usado `npm.cmd`, sem alterar o sistema operacional ou a política.
- o primeiro nome de script npm não oferecia o alias padrão `test`; o alias foi adicionado.
- o scanner interpretou a versão numérica concatenada de uma migration como possível CPF; o preflight passou a derivar a versão a partir do nome com separador, preservando a detecção de CPF real.

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

- runtime remoto e expiração real ainda dependem do gate humano;
- resultado pode variar por tolerância de relógio do serviço, limitada no script;
- a revalidação SQL após o ciclo ainda não foi executada;
- KMS/cofre, rotação, restauração, retenção, legal hold e policies finais continuam pendentes;
- revisão independente ainda é necessária;
- a BKL-016 geral permanece **Em andamento**.

Não houve merge, produção, n8n, Appsmith, Telegram, dado real ou credencial backend nesta preparação.
