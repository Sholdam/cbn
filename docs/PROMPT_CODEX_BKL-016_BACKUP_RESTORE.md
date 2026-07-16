# Prompt Codex — BKL-016 backup, restauração e recuperação sintética

## Classificação e branch

- Esforço: **9/10**.
- Base: `main` atualizada.
- Branch obrigatória: `codex/bkl-016-backup-restore`.
- Não fazer merge.

## Leitura obrigatória antes de executar

Leia integralmente os prompts, runbooks e relatórios existentes da BKL-016, com atenção especial às fases de Storage e KMS/envelope. Leia também `HANDOFF.md`, `BACKLOG_CHECKPOINT.md`, `ARQUITETURA_TECNICA.md`, migrations, rollback, seed e validadores.

## Limites inegociáveis

1. Somente dados sintéticos e stack Supabase local descartável.
2. Não usar `supabase link`, `--linked`, projeto remoto, produção, n8n, Appsmith, Telegram ou credencial externa.
3. Não fazer upload para nuvem, ativar billing, criar recurso pago ou autenticar em provedor.
4. Google Cloud KMS real permanece bloqueado por faturamento.
5. O adaptador local é exclusivo de teste; dados reais e produção permanecem proibidos.
6. Não alterar `telegram-gateway/` nem `.env.example`.
7. Nenhum segredo, URL assinada, chave, JWT, credencial, plaintext protegido ou PII pode entrar em log, relatório ou commit.
8. Limpar stack, volumes temporários, objetos e dumps ao final.

## Objetivo

Comprovar localmente:

- backup de schema e dados exclusivamente sintéticos;
- restauração da estrutura por migrations em ambiente descartável;
- restauração dos dados a partir de dump separado;
- backup/restauração de objeto Storage sintético com hash;
- recuperação de envelope AES-256-GCM usando a KEK efêmera correta;
- falha fechada quando a versão da KEK não estiver disponível;
- falha fechada após adulteração do ciphertext;
- rollback que recusa remover metadados necessários à recuperação;
- inventário explícito das dependências entre banco, Storage e material de chave;
- RTO/RPO preliminares, sem prometer SLA de produção.

## Estratégia de recuperação

O schema canônico deve ser reconstruído pelas migrations versionadas. Gere também um dump de schema para auditoria e verificação. Os dados sintéticos devem ter dump próprio. Objetos Storage devem ser tratados como plano separado, com manifesto contendo apenas bucket, object key UUID, hash e tamanho. A KEK nunca pertence ao dump do banco nem ao backup do Storage.

O teste de recuperação deve manter a KEK local somente em memória durante a execução. Um segundo adaptador, sem a versão necessária, deve falhar explicitamente. Não exporte a KEK para “fazer o teste passar”.

## Critérios de aceite

1. Schema reaplicado por migrations sem acesso remoto.
2. Dados sintéticos restaurados e integridades preservadas.
3. Objeto Storage restaurado com SHA-256 idêntico.
4. Envelope restaurado descriptografado somente com a KEK correta.
5. Ausência da versão da KEK retorna falha fechada.
6. Adulteração retorna falha de autenticação, sem plaintext.
7. Rollback incremental recusa perda de envelopes.
8. Dumps e manifestos temporários passam por scanner e são removidos.
9. Stack local é encerrada com `--no-backup` e não sobra objeto/container da execução.
10. Testes Node, SQL existentes, `git diff --check` e validador BKL-016 passam.

## Entrega

Atualize o runbook, documentação principal, handoff, backlog e arquitetura. Crie relatório sanitizado com comandos, marcadores, RTO observado, RPO preliminar, falhas/correções e riscos. Faça commit e push da branch. Não faça merge.
