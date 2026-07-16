# Relatório BKL-016 — do gate humano à conclusão do runtime de Storage

**Data:** 15/07/2026

## Ponto inicial deste relatório

Este relatório continua a partir do seguinte estado já entregue:

> Preparação concluída e parada corretamente no gate humano, antes de qualquer credencial backend.
>
> Branch: `codex/bkl-016-storage-runtime`
>
> Hash naquele ponto: `020a20c35ac06d987f18ff5cdde36c7bb0558255`
>
> Branch enviada ao GitHub, sem merge.

Naquele momento já estavam prontos o runtime Node.js, o wrapper PowerShell, os testes negativos, o preflight sanitizado e a documentação do gate. Nenhuma operação autenticada de Storage havia sido executada.

## Obtenção segura da credencial

O operador foi orientado a acessar o projeto isolado `cbn-dev` no painel do Supabase e usar uma chave do tipo **Secret**, exclusiva para backend. O valor:

- não foi enviado ao chat;
- não foi exibido pelo Codex;
- não foi salvo em `.env`, perfil, script ou Git;
- foi informado somente em prompt oculto;
- existiu apenas na variável de processo `CBN_SUPABASE_BACKEND_KEY` durante o runtime;
- foi removido do processo ao terminar.

Nenhuma chave `Publishable` ou `anon` foi usada como credencial administrativa. Nenhuma credencial foi colocada em navegador, Appsmith, n8n ou código cliente.

## Execução interativa

A primeira tentativa de abrir automaticamente uma janela PowerShell ocorreu em uma sessão invisível do executor. O processo foi identificado e encerrado antes de receber credencial ou iniciar upload.

Uma segunda tentativa de janela automática também não apareceu na área de trabalho do operador e foi encerrada com segurança. Em seguida, o operador abriu seu próprio PowerShell e iniciou o executor local descartável.

O prompt oculto recebeu a chave backend sem mostrar caracteres. O runtime avançou normalmente pelas fases de preflight, upload, acesso anônimo, URL assinada, expiração, varredura e limpeza.

## Resultado real do Storage

O objeto usado foi exclusivamente sintético, com nome UUID, conteúdo aleatório em memória e marcador `BKL016_STORAGE_SYNTHETIC_ONLY`. Nenhum dado real ou nome humano foi usado.

Resultados sanitizados:

| Verificação | Resultado |
|---|---|
| bucket | `cbn-temporary-private`, confirmado privado antes do upload |
| upload | aprovado |
| tamanho | 94 bytes |
| overwrite | bloqueado por consulta prévia e `upsert: false` |
| metadados | existência e tamanho confirmados |
| acesso anônimo | negado com resposta `4xx` |
| download antes da expiração | aprovado |
| integridade | SHA-256 do download idêntico ao conteúdo em memória |
| TTL nominal | 30 segundos |
| expiração observada | 36 segundos |
| acesso depois da expiração | negado com resposta `4xx` |
| varredura local | aprovada |
| limpeza | objeto removido e ausência confirmada |

Marcadores emitidos pelo runtime:

```text
BKL-016 Storage backend preflight passed
BKL-016 Storage upload passed
BKL-016 anonymous access denied
BKL-016 signed URL pre-expiry download passed
BKL-016 signed URL expiration passed
BKL-016 Storage local leak scan passed
BKL-016 Storage cleanup passed
```

A URL assinada não foi impressa, copiada para relatório ou persistida. O log sanitizado continha somente bucket lógico, tamanho, hash, TTL, tempo observado e classe HTTP.

## Falha operacional após a limpeza

O primeiro executor interativo capturava a saída com `Tee-Object`. Essa captura permitiu o prompt da chave backend, mas impediu o segundo `Read-Host`, que pediria a senha do banco para a revalidação SQL.

Quando isso ocorreu:

- o upload já havia sido validado;
- a expiração já havia sido comprovada;
- a varredura local já havia passado;
- o objeto remoto já havia sido removido;
- o marcador `BKL-016 Storage cleanup passed` já havia sido emitido.

Portanto não houve objeto órfão. O problema foi restrito à forma de abrir o segundo prompt interativo.

## Revalidação SQL separada

Foi preparado um executor local ignorado pelo Git para chamar diretamente o validador SQL existente, sem captura de saída. O operador informou a senha do banco em prompt oculto.

O arquivo seguro de status registrou:

```json
{"phase":"complete","result":"passed","category":"none"}
```

Isso comprovou a conclusão da validação estrutural e transacional remota após o ciclo de Storage. Nenhuma senha, URL de banco ou fixture foi persistida.

Após confirmar os marcadores do runtime e o status SQL, foi consolidado o marcador:

```text
BKL-016 Storage runtime validation passed
```

## Confirmação adicional de limpeza

A listagem recursiva sanitizada do bucket temporário foi repetida depois da revalidação SQL.

Resultado final:

```text
TEMP_BUCKET_RESIDUAL_OBJECT_COUNT=0
```

Os executores auxiliares, log sanitizado e arquivos de status em `supabase/.temp` foram removidos. O vínculo local e os arquivos operacionais preexistentes da CLI permaneceram ignorados e não foram alterados desnecessariamente.

## Validações finais executadas

Foram executados novamente:

```powershell
git fetch origin --prune
git diff --check
npm.cmd test --prefix scripts
powershell.exe -ExecutionPolicy Bypass -File .\scripts\validate-bkl016.ps1
powershell.exe -ExecutionPolicy Bypass -File .\scripts\supabase-remote-preflight.ps1 -Phase StorageRuntime <confirmações seguras>
supabase --experimental storage ls --linked <bucket permitido> --recursive --output-format json
```

Resultados:

- 9 testes negativos aprovados;
- validador estático aprovado;
- preflight remoto aprovado;
- migrations esperadas conciliadas;
- bucket temporário sem objeto residual;
- `telegram-gateway/` inalterado;
- `.env.example` inalterado;
- nenhum `.env` real;
- nenhuma URL assinada, chave, senha, JWT ou PII versionada;
- árvore Git limpa após o commit;
- branch zero commits atrás de `origin/main` naquele momento.

## Documentação atualizada

O resultado real foi incorporado a:

- `README.md`;
- `docs/ARQUITETURA_TECNICA.md`;
- `docs/BACKLOG_CHECKPOINT.md`;
- `docs/BKL-016_ARMAZENAMENTO_DADOS_SENSIVEIS.md`;
- `docs/BKL-016_REMOTE_DEV_RUNBOOK.md`;
- `docs/HANDOFF.md`;
- `docs/RELATORIO_BKL-016_STORAGE_RUNTIME_PREPARACAO.md`.

O commit que registrou a conclusão do runtime foi:

```text
e034be2e0f3b70b6febadd2fbf85070348a10fc9
```

## Situação final e limites

O ciclo real de Storage da BKL-016 está comprovado no ambiente isolado de desenvolvimento:

- upload sintético;
- bloqueio anônimo;
- URL assinada funcional antes do vencimento;
- expiração efetiva;
- ausência de vazamento;
- remoção do objeto;
- bucket vazio ao final;
- revalidação SQL aprovada.

A BKL-016 geral continua **Em andamento**. Permanecem pendentes:

- definição e aprovação de KMS/cofre;
- rotação de chaves;
- restauração comprovada;
- retenção e `legal hold`;
- policies finais de Storage;
- revisão técnica independente.

Não houve merge, deploy, acesso a produção, seed remoto, rollback remoto, conexão com n8n/Appsmith/Telegram, usuário Auth, fixture persistente ou dado real.
