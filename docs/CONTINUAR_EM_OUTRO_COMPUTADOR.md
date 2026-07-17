# Continuar o projeto CBN em outro computador

## Fonte oficial

Use somente:

```text
https://github.com/Sholdam/cbn
```

A branch de retomada é `main`. Não use ZIPs antigos, a pasta Downloads ou cópias locais como fonte.

## Clonar e conferir

No PowerShell do novo computador:

```powershell
git clone https://github.com/Sholdam/cbn.git
cd cbn
git switch main
git pull --ff-only origin main
git status
git log -1 --oneline
```

O `git status` deve informar uma árvore limpa e a branch sincronizada.

## Orientação para o novo Codex

Envie:

```text
Abra o repositório CBN clonado e siga integralmente o AGENTS.md.

Leia README.md, docs/HANDOFF.md, docs/BACKLOG_CHECKPOINT.md e
docs/ARQUITETURA_TECNICA.md antes de propor alterações.

Confirme a branch, o status e o último commit. A próxima tarefa principal
registrada é a BKL-020. Informe o nível de esforço (Médio, Alto, Extralto ou
Ultra) antes de iniciar.

Não use dados reais, não faça deploy e não conecte serviços remotos sem
autorização expressa.
```

## O que não é transferido pelo GitHub

Por segurança, estes itens devem ser recriados ou configurados separadamente:

- dependências em `node_modules`;
- metadados temporários da CLI do Supabase;
- `.env`;
- sessões Telegram;
- tokens, senhas, JWTs e chaves;
- credenciais de Supabase, Railway, n8n, Appsmith ou KMS.

Não copie segredos pelo GitHub, chat, print ou documento. Quando uma credencial voltar a ser necessária, configure-a pelo fluxo seguro específico do serviço.

## Validação rápida do conteúdo

Arquivos essenciais que devem existir:

```text
AGENTS.md
README.md
docs/HANDOFF.md
docs/BACKLOG_CHECKPOINT.md
docs/ARQUITETURA_TECNICA.md
docs/CONTINUAR_EM_OUTRO_COMPUTADOR.md
supabase/migrations/
supabase/rollback/
supabase/tests/
scripts/
telegram-gateway/
```

O histórico detalhado das decisões e dos testes permanece nos runbooks e relatórios dentro de `docs/`.
