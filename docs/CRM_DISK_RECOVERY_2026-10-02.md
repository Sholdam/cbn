# Recuperação do disco CBN — 02/10/2026

## Incidente e autorização

Depois da desconexão relatada pelo proprietário, o volume de produção apareceu
com `emergency_ro`. Uma reabertura controlada também apresentou o fallback
somente leitura do WSL no disco virtual do Ubuntu. O Windows reportou o Toshiba
como `Healthy`/`OK`; esse indicador não constitui auditoria física completa.

O usuário escolheu explicitamente reparar o original sem backup completo.
A tentativa de cópia temporária do VHDX no próprio Toshiba foi interrompida,
nunca foi considerada um backup válido e seu arquivo `.partial` foi descartado.
Backup independente permanece pendente.

## Reparos e evidências

- Distro auxiliar Debian `CBN-Recovery`, no Toshiba, permitiu trabalhar com o
  VHDX do Ubuntu conectado via `wsl --mount --vhd --bare` e sem montar seu ext4.
  Dispositivo identificado por UUID e inventário de montagens antes do reparo.
- `e2fsck -f -p` recuperou o journal externo e terminou com código 1.
  A checagem seguinte `e2fsck -n` informou `clean`. O VHDX foi desanexado antes
  de abrir o Ubuntu principal.
- Com Docker parado e o cofre aberto, mas desmontado, `e2fsck -f -p` também
  recuperou o journal interno e terminou com código 1; checagem seguinte `clean`.
  A chave DPAPI foi transmitida por stdin conforme o wrapper existente, sem
  imprimir ou persistir chave em texto no Windows.
- Root e cofre montaram `rw`, sem `emergency_ro`. Gravação temporária seguida
  de `fsync` no cofre e o comando `sync` concluíram.
- Saúde final: CRM local 200, site local 200, CRM público 200, site público 200,
  API sem autenticação 401, dez containers ativos e sessão WhatsApp `WORKING`.
  Keepalive pelo Agendador ativo e recuperação por minuto habilitada.
- `CBN-Recovery` foi parada após o uso. Não contém dados/sessões do CRM.

## Correções de inicialização

O Docker, iniciado antes da abertura do cofre, via o diretório subjacente
em seu namespace de montagem; `garage.toml` aparecia como diretório para o
daemon e como arquivo regular na sessão WSL. Isso impediu a primeira subida.

`cbn-native-vault.sh` agora confirma o dispositivo esperado no namespace da
sessão e garante a montagem no systemd e no Docker ativo. A montagem inesperada
é recusada. `cbn-unmount-vault.sh`, chamado pela parada segura, desmonta as
vistas de Docker/systemd/sessão antes do fechamento do mapper LUKS.
O helper e a saúde recusam `ro`/`emergency_ro`; o supervisor não reinicia
containers sobre um cofre somente leitura. A conferência final reportou
`vault_writable: true` e `healthy: true`; última execução do Agendador terminou
com resultado 0.

`start-cbn-clone.ps1` aguarda até cinco minutos pelo Rails, alinhando-se à
tolerância do supervisor. Neste incidente, o primeiro limite de um minuto
expirou, mas o CRM concluiu o boot sem precisar de novo restart.

Validação: sintaxe Bash, parser PowerShell e execução idempotente do helper de
montagem no ambiente recuperado. A parada completa não foi repetida depois
da restauração para manter o atendimento disponível.

## Limites

Não houve novo envio de mensagem de teste, reprocessamento do histórico nem
ativação dos fluxos legados de n8n/Telegram. O reparo dos sistemas de arquivos
e os checks de serviço não provam integridade completa de cada registro/anexo.
O endereço atual é <https://crmcbn.up.railway.app/>; a prévia do site está em
<https://crmcbn.up.railway.app/site/>. O endereço longo antigo foi renomeado.

Procedimento de referência: [Microsoft Learn — WSL disk space](https://learn.microsoft.com/en-us/windows/wsl/disk-space#how-to-repair-a-vhd-mounting-error).
