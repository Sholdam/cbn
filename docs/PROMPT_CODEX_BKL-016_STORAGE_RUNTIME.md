# Prompt Codex — BKL-016 Storage runtime em desenvolvimento

Execute esta tarefa no repositório `Sholdam/cbn`.

## Contexto canônico

A fundação da BKL-016 já foi validada localmente e no projeto Supabase remoto isolado de desenvolvimento `cbn-dev`.

Já estão comprovados:

- migrations aplicadas sem seed remoto;
- RLS, grants e funções `SECURITY DEFINER`;
- bloqueio de `anon` e de acesso direto a `app_private`;
- integridades de cliente, produto, operação e evidência;
- quatro buckets privados;
- produção, n8n e Appsmith permaneceram intocados.

Ainda falta comprovar o ciclo real de Storage com objeto sintético e URL assinada.

## Regras inegociáveis

- Não acessar, vincular ou alterar produção.
- Trabalhar somente no projeto isolado `cbn-dev`.
- Não usar dados reais, nomes reais, CPF, telefone, RG, endereço, conta bancária ou documento real.
- Não executar `supabase db reset`, rollback estrutural ou seed remoto.
- Não conectar n8n, Appsmith, Telegram ou qualquer sistema externo.
- Não colocar chave, senha, token, JWT, URL assinada, project-ref ou credencial em arquivo versionado, commit, log, relatório ou conversa.
- Nunca usar `service_role` em navegador, Appsmith ou código cliente.
- Caso seja necessária credencial administrativa, ela deve existir apenas como variável de ambiente do processo local ou entrada oculta, usada por um script backend descartável.
- Não fazer merge na `main`.
- Não excluir a branch ao final.

## Branch

Parta da `main` atualizada e crie:

```text
codex/bkl-016-storage-runtime
```

Antes de qualquer acesso remoto, execute e registre somente saídas sanitizadas:

```powershell
git status
git branch --show-current
git log -1 --oneline
git fetch origin
git rev-list --left-right --count origin/main...HEAD
supabase --version
node --version
npm --version
```

A árvore deve estar limpa e a branch não pode estar atrasada da `main`.

## Objetivo

Comprovar, no bucket `cbn-temporary-private`, o ciclo completo:

1. upload de objeto sintético;
2. confirmação de existência e metadados mínimos;
3. bloqueio de acesso público/anônimo;
4. geração de URL assinada temporária;
5. download válido antes da expiração;
6. falha de acesso após expiração;
7. ausência da URL em banco, logs persistentes e arquivos versionados;
8. remoção do objeto;
9. comprovação de que o objeto não existe mais.

## Etapa 1 — Preflight fail-closed

Reutilize e fortaleça, quando necessário:

- `scripts/supabase-remote-preflight.ps1`;
- `scripts/supabase-remote-validate.ps1`;
- `scripts/supabase-remote-cleanup.ps1`.

O preflight deve confirmar:

- branch exata `codex/bkl-016-storage-runtime`;
- ambiente `development`;
- alvo remoto confirmado como `cbn-dev`;
- project-ref diferente de qualquer referência marcada como produção;
- vínculo local existente e coerente;
- migrations remotas `20260715` e `20260716` conciliadas;
- bucket `cbn-temporary-private` existente e privado;
- árvore Git limpa antes da operação;
- nenhum segredo ou dado pessoal no repositório/histórico.

Se qualquer verificação falhar, pare sem criar objeto.

## Etapa 2 — Implementação do teste backend

Crie um script backend explícito, preferencialmente em Node.js, por exemplo:

```text
scripts/supabase-storage-runtime-test.mjs
```

Use biblioteca oficial mantida pelo Supabase ou API oficial documentada. Não invente endpoints.

O script deve:

- ler URL do projeto e credencial backend somente de variáveis de ambiente do processo;
- recusar execução quando a URL ou o alvo não corresponderem ao ambiente confirmado;
- não imprimir credenciais, headers, URL assinada completa ou project-ref;
- não persistir a URL assinada;
- criar um arquivo sintético pequeno, sem PII, em memória ou dentro de `supabase/.temp`;
- usar conteúdo aleatório ou marcador como `BKL016_STORAGE_SYNTHETIC_ONLY`;
- gerar nome de objeto apenas com UUID/hash, sem nomes humanos;
- usar exclusivamente `cbn-temporary-private`;
- definir MIME type simples e seguro;
- recusar overwrite de objeto existente;
- validar hash do conteúdo baixado;
- apagar arquivos temporários no `finally`;
- remover o objeto remoto mesmo se uma verificação posterior falhar;
- produzir somente marcadores sanitizados de fase e resultado.

Não versionar dependências desnecessárias. Caso uma dependência oficial seja necessária, documente e fixe versão compatível. Não alterar o aplicativo principal.

## Etapa 3 — Gate humano de credencial

Antes da primeira operação que exija credencial backend:

1. prepare todo o código e validações estáticas;
2. explique exatamente qual variável local precisa ser definida;
3. não mostre nem solicite o valor na conversa;
4. instrua o operador a obtê-la no painel do projeto `cbn-dev` e defini-la somente na sessão atual;
5. pare até confirmação explícita do operador.

A credencial não pode ser salva em `.env`, arquivo de perfil, histórico de shell, screenshot, relatório ou Git.

## Etapa 4 — Teste real autorizado

Após a confirmação humana, execute o ciclo no bucket temporário.

### Upload

- criar objeto sintético novo;
- confirmar que o upload retornou sucesso;
- confirmar que o objeto aparece somente no bucket esperado;
- registrar apenas bucket lógico, tamanho, hash e marcador sintético — sem URL ou identificadores sensíveis.

### Acesso público negado

Comprove que uma requisição sem autenticação não obtém o objeto.

Resultado esperado: 401, 403 ou 404, conforme comportamento oficial do Supabase. Não aceitar 2xx.

### URL assinada

- gerar URL assinada com expiração curta, preferencialmente entre 30 e 60 segundos;
- não imprimir a URL;
- acessar antes da expiração e validar hash/conteúdo;
- aguardar a janela necessária;
- tentar novamente após expiração;
- exigir falha não-2xx.

Se o ambiente aplicar tolerância de relógio, documente e use margem limitada; não estenda para minutos longos apenas para fazer o teste passar.

### Ausência de vazamento

Após o teste, varrer:

- arquivos versionados e não versionados relevantes;
- `supabase/.temp`;
- logs produzidos pelo script;
- tabelas públicas BKL-016;
- `audit.events`;
- histórico Git da branch.

Confirmar que não existe:

- URL assinada;
- token JWT;
- chave backend;
- header Authorization;
- parâmetro `token=` ou equivalente;
- conteúdo sintético fora do local temporário previsto.

A varredura não deve imprimir valores encontrados; apenas categoria e caminho sanitizado quando houver falha.

### Limpeza

- apagar o objeto remoto pelo caminho oficial do Storage;
- confirmar que listagem/download posterior não encontra o objeto;
- apagar manifesto e arquivo local temporário;
- zerar/restaurar variáveis sensíveis do processo quando possível;
- executar novamente a validação estrutural remota já existente.

Marcadores finais esperados:

```text
BKL-016 Storage upload passed
BKL-016 anonymous access denied
BKL-016 signed URL pre-expiry download passed
BKL-016 signed URL expiration passed
BKL-016 Storage cleanup passed
BKL-016 Storage runtime validation passed
```

## Etapa 5 — Testes negativos obrigatórios

Sem criar dados persistentes adicionais, validar que o script rejeita:

- bucket fora da allowlist;
- nome de objeto sem padrão UUID/hash;
- overwrite de objeto existente;
- URL de projeto divergente do alvo confirmado;
- execução na `main`;
- execução sem confirmação de ambiente sintético;
- execução sem credencial local;
- tentativa de imprimir ou persistir URL assinada.

## Etapa 6 — Documentação

Atualize, sem expor identificadores ou segredos:

- `docs/BKL-016_ARMAZENAMENTO_DADOS_SENSIVEIS.md`;
- `docs/BKL-016_REMOTE_DEV_RUNBOOK.md`;
- `docs/BACKLOG_CHECKPOINT.md`;
- `docs/HANDOFF.md`;
- `docs/ARQUITETURA_TECNICA.md`;
- `README.md` somente se necessário;
- relatório específico desta execução.

Registre claramente:

- mecanismo usado para upload/download;
- duração nominal e duração efetiva da URL assinada;
- resultado antes e depois da expiração;
- evidência sanitizada da limpeza;
- ausência de persistência da URL;
- limitações restantes;
- que produção não foi acessada.

Não marque KMS, backup/restauração, retenção ou BKL-016 geral como concluídos.

## Etapa 7 — Validações finais

Execute:

```powershell
git diff --check
powershell.exe -ExecutionPolicy Bypass -File .\scripts\validate-bkl016.ps1
powershell.exe -ExecutionPolicy Bypass -File .\scripts\supabase-remote-preflight.ps1 <parâmetros seguros já usados no projeto>
```

Confirme ainda:

- `telegram-gateway/` inalterado;
- `.env.example` inalterado, salvo necessidade documental sem valor real;
- nenhum `.env` real;
- nenhum segredo, URL assinada ou PII versionado;
- nenhuma alteração em produção;
- nenhum usuário Auth ou fixture persistente;
- bucket temporário sem objeto residual;
- árvore Git limpa depois do commit.

## Entrega Git

Faça commits pequenos e claros na branch `codex/bkl-016-storage-runtime`.

Mensagem final sugerida:

```text
feat: validate BKL-016 Storage runtime in remote development
```

Faça push da branch.

Não faça merge.

## Relatório final obrigatório

Entregue:

- branch e hash final;
- arquivos criados/alterados;
- biblioteca/API usada;
- cada comando executado, com valores sensíveis omitidos;
- resultados dos seis marcadores finais;
- tempo configurado e observado da expiração;
- confirmação de acesso anônimo negado;
- confirmação de objeto removido;
- confirmação de ausência de URL/credencial em logs, banco e Git;
- falhas encontradas e correções;
- testes não executados e motivo;
- riscos restantes;
- declaração explícita de que não houve merge, produção, n8n, Appsmith ou dados reais.

Se a credencial backend ainda não estiver disponível, pare no gate humano e não afirme que o teste real foi executado.