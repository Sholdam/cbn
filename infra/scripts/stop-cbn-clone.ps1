param()

$ErrorActionPreference = 'Stop'
$mountedSource = & wsl.exe -d Ubuntu-CBN -u root -- findmnt -n -o SOURCE --target /srv/cbn-production
if ($LASTEXITCODE -ne 0 -or $mountedSource.Trim() -ne '/dev/mapper/cbn_production') {
    throw 'O cofre CBN nao esta montado no dispositivo esperado.'
}

$compose = '/mnt/c/Users/GUILHERME/OneDrive/Documentos/ChatGPT/CBN/cbn-infrastructure-migration/infra/railway-clone-compose.yml'
& wsl.exe -d Ubuntu-CBN -u root -- docker compose -f $compose --profile physical --profile web --profile site --profile inert stop chatwoot-web cbn-site n8n-volume-check garage redis postgres-physical
if ($LASTEXITCODE -ne 0) { throw 'Falha ao parar um ou mais servicos CBN.' }

& wsl.exe -d Ubuntu-CBN -u root -- sync
if ($LASTEXITCODE -ne 0) { throw 'Falha ao sincronizar o HD.' }
& wsl.exe -d Ubuntu-CBN -u root -- umount /srv/cbn-production
if ($LASTEXITCODE -ne 0) { throw 'Cofre em uso; nao e seguro remover o HD.' }
& wsl.exe -d Ubuntu-CBN -u root -- cryptsetup close cbn_production
if ($LASTEXITCODE -ne 0) { throw 'Falha ao fechar o cofre.' }

$pidFile = Join-Path (Join-Path $env:USERPROFILE '.cbn') 'wsl-keepalive.pid'
if (Test-Path -LiteralPath $pidFile -PathType Leaf) {
    $savedPid = 0
    if ([int]::TryParse((Get-Content -LiteralPath $pidFile -Raw).Trim(), [ref]$savedPid)) {
        $candidate = Get-CimInstance Win32_Process -Filter "ProcessId = $savedPid" -ErrorAction SilentlyContinue
        if ($candidate -and $candidate.Name -eq 'wsl.exe' -and
            $candidate.CommandLine -like '*Ubuntu-CBN*sleep*infinity*') {
            Stop-Process -Id $savedPid
        }
    }
    Remove-Item -LiteralPath $pidFile
}
Write-Output 'clone_parado_cofre_fechado'
