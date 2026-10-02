param([switch]$AutomaticRecovery)

$ErrorActionPreference = 'Stop'
$volume = Get-Volume -DriveLetter D -ErrorAction Stop
if ($volume.FileSystemLabel -ne 'FAMULUS_DATA' -or $volume.HealthStatus -ne 'Healthy') {
    throw 'O HD Toshiba esperado nao esta saudavel em D:.'
}
if (-not (Test-Path -LiteralPath 'D:\CBN\wsl\Ubuntu-CBN\ext4.vhdx' -PathType Leaf)) {
    throw 'O disco WSL CBN nao foi encontrado no Toshiba.'
}

$stateDirectory = Join-Path $env:USERPROFILE '.cbn'
[void][System.IO.Directory]::CreateDirectory($stateDirectory)
$maintenanceFlag = Join-Path $stateDirectory 'maintenance.flag'
if (Test-Path -LiteralPath $maintenanceFlag) {
    if ($AutomaticRecovery) { throw 'Parada segura ativa; recuperacao automatica recusada.' }
    Remove-Item -LiteralPath $maintenanceFlag
}
& (Join-Path $PSScriptRoot 'ensure-cbn-keepalive.ps1') | Out-Null
# The scheduled keepalive has a lifetime independent of this terminal/chat.

& (Join-Path $PSScriptRoot 'cbn-native-vault.ps1') -Mode mount | Out-Null
$mountedSource = & wsl.exe -d Ubuntu-CBN -u root -- findmnt -n -o SOURCE --target /srv/cbn-production
if ($LASTEXITCODE -ne 0 -or $mountedSource.Trim() -ne '/dev/mapper/cbn_production') {
    throw 'Cofre CBN nao foi confirmado no dispositivo LUKS esperado.'
}

$compose = '/mnt/c/Users/GUILHERME/OneDrive/Documentos/ChatGPT/CBN/cbn-infrastructure-migration/infra/railway-clone-compose.yml'
if ($AutomaticRecovery -and (Test-Path -LiteralPath $maintenanceFlag)) { throw 'Parada segura solicitada.' }
& wsl.exe -d Ubuntu-CBN -u root -- docker compose -f $compose --profile physical --profile web --profile site up -d postgres-physical redis garage chatwoot-web cbn-site
if ($LASTEXITCODE -ne 0) { throw 'Falha ao iniciar o clone local.' }

$webReady = $false
# Match the recovery supervisor's five-minute allowance for Rails cold boots.
for ($attempt = 0; $attempt -lt 150; $attempt++) {
    try {
        $response = Invoke-WebRequest -Uri 'http://127.0.0.1:3000/' -SkipHttpErrorCheck -TimeoutSec 2 -ErrorAction Stop
        if ([int]$response.StatusCode -eq 200) { $webReady = $true; break }
    } catch { }
    Start-Sleep -Seconds 2
}
if (-not $webReady) { throw 'Chatwoot iniciou, mas nao respondeu HTTP 200 no tempo esperado.' }

$siteResponse = Invoke-WebRequest -Uri 'http://127.0.0.1:3002/' -SkipHttpErrorCheck -TimeoutSec 3 -ErrorAction Stop
if ([int]$siteResponse.StatusCode -ne 200) { throw 'Site CBN nao respondeu HTTP 200.' }

Write-Output 'cofre=LUKS2_montado'
Write-Output 'crm=http://127.0.0.1:3000/'
Write-Output 'site=http://127.0.0.1:3002/'
Write-Output 'automacoes_legadas=desligadas'
& wsl.exe -d Ubuntu-CBN -u root -- test -f /srv/cbn-production/secrets/waha-chatwoot.json
if ($LASTEXITCODE -eq 0) {
    & (Join-Path $PSScriptRoot 'start-cbn-waha.ps1')
}
