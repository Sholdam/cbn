param()

$ErrorActionPreference = 'Stop'
$mountedSource = & wsl.exe -d Ubuntu-CBN -u root -- findmnt -n -o SOURCE --target /srv/cbn-production
if ($LASTEXITCODE -ne 0 -or $mountedSource.Trim() -ne '/dev/mapper/cbn_production') {
    throw 'Inicie o clone CBN para montar o cofre antes de iniciar o WAHA.'
}

$scriptRoot = '/mnt/c/Users/GUILHERME/OneDrive/Documentos/ChatGPT/CBN/cbn-infrastructure-migration/infra'
& wsl.exe -d Ubuntu-CBN -u root -- bash "$scriptRoot/scripts/prepare-cbn-waha.sh"
if ($LASTEXITCODE -ne 0) { throw 'Falha ao preparar o WAHA no cofre.' }
& wsl.exe -d Ubuntu-CBN -u root -- docker compose -f "$scriptRoot/railway-clone-compose.yml" --profile physical --profile web --profile waha up -d waha-redis waha
if ($LASTEXITCODE -ne 0) { throw 'Falha ao iniciar o WAHA local.' }
Write-Output 'waha=http://127.0.0.1:3003/dashboard'
Write-Output 'waha_saida=internet_local'
& wsl.exe -d Ubuntu-CBN -u root -- test -f /srv/cbn-production/secrets/waha-chatwoot.json
if ($LASTEXITCODE -eq 0) {
    & wsl.exe -d Ubuntu-CBN -u root -- docker compose -f "$scriptRoot/railway-clone-compose.yml" --profile physical --profile web --profile waha up -d chatwoot-waha-worker
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao iniciar o processamento da caixa WAHA.' }
    Write-Output 'waha_worker=filas_locais_criticas_webhooks_midia'
}
