param()

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
$pidFile = Join-Path $stateDirectory 'wsl-keepalive.pid'
$keepalive = $null
if (Test-Path -LiteralPath $pidFile -PathType Leaf) {
    $savedPid = 0
    if ([int]::TryParse((Get-Content -LiteralPath $pidFile -Raw).Trim(), [ref]$savedPid)) {
        $candidate = Get-CimInstance Win32_Process -Filter "ProcessId = $savedPid" -ErrorAction SilentlyContinue
        if ($candidate -and $candidate.Name -eq 'wsl.exe' -and
            $candidate.CommandLine -like '*Ubuntu-CBN*sleep*infinity*') {
            $keepalive = $candidate
        }
    }
}
if (-not $keepalive) {
    $process = Start-Process -FilePath 'wsl.exe' -ArgumentList @(
        '-d', 'Ubuntu-CBN', '-u', 'root', '--', '/bin/sleep', 'infinity'
    ) -WindowStyle Hidden -PassThru
    Set-Content -LiteralPath $pidFile -Value $process.Id -NoNewline
}

& (Join-Path $PSScriptRoot 'cbn-native-vault.ps1') -Mode mount | Out-Null
$mountedSource = & wsl.exe -d Ubuntu-CBN -u root -- findmnt -n -o SOURCE --target /srv/cbn-production
if ($LASTEXITCODE -ne 0 -or $mountedSource.Trim() -ne '/dev/mapper/cbn_production') {
    throw 'Cofre CBN nao foi confirmado no dispositivo LUKS esperado.'
}

$compose = '/mnt/c/Users/GUILHERME/OneDrive/Documentos/ChatGPT/CBN/cbn-infrastructure-migration/infra/railway-clone-compose.yml'
& wsl.exe -d Ubuntu-CBN -u root -- docker compose -f $compose --profile physical --profile web --profile site up -d postgres-physical redis garage chatwoot-web cbn-site
if ($LASTEXITCODE -ne 0) { throw 'Falha ao iniciar o clone local.' }

$webReady = $false
for ($attempt = 0; $attempt -lt 30; $attempt++) {
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
Write-Output 'automacoes=desligadas'
& wsl.exe -d Ubuntu-CBN -u root -- test -f /srv/cbn-production/secrets/waha-chatwoot.json
if ($LASTEXITCODE -eq 0) {
    & (Join-Path $PSScriptRoot 'start-cbn-waha.ps1')
}
