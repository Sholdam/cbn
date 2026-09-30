param()
$ErrorActionPreference = 'Stop'
$stateDirectory = Join-Path $env:USERPROFILE '.cbn'
[void][System.IO.Directory]::CreateDirectory($stateDirectory)
if (Test-Path -LiteralPath (Join-Path $stateDirectory 'maintenance.flag')) { exit 0 }

function Write-CbnRecoveryEvent([string]$State) {
    $record = @{ time = [DateTimeOffset]::Now.ToString('o'); state = $State } | ConvertTo-Json -Compress
    Add-Content -LiteralPath (Join-Path $stateDirectory 'service-recovery.log') -Value $record
}
try {
    $volume = Get-Volume -DriveLetter D -ErrorAction Stop
    if ($volume.FileSystemLabel -ne 'FAMULUS_DATA' -or $volume.HealthStatus -ne 'Healthy' -or
        -not (Test-Path -LiteralPath 'D:\CBN\wsl\Ubuntu-CBN\ext4.vhdx' -PathType Leaf)) {
        Write-CbnRecoveryEvent 'expected_disk_unavailable'
        exit 1
    }
    & (Join-Path $PSScriptRoot 'ensure-cbn-keepalive.ps1') | Out-Null
    $healthScript = '/mnt/c/Users/GUILHERME/OneDrive/Documentos/ChatGPT/CBN/cbn-infrastructure-migration/infra/scripts/cbn-service-health.py'
    $raw = & wsl.exe -d Ubuntu-CBN -u root -- python3 $healthScript
    $health = if ($LASTEXITCODE -eq 0) { $raw | ConvertFrom-Json } else { $null }
    if ($health -and $health.healthy) { exit 0 }

    Write-CbnRecoveryEvent 'recovery_started'
    if (Test-Path -LiteralPath (Join-Path $stateDirectory 'maintenance.flag')) { exit 0 }
    try { & (Join-Path $PSScriptRoot 'start-cbn-public.ps1') -AutomaticRecovery | Out-Null } catch { }
    $mountedSource = & wsl.exe -d Ubuntu-CBN -u root -- findmnt -n -o SOURCE --target /srv/cbn-production
    if ($LASTEXITCODE -ne 0 -or $mountedSource.Trim() -ne '/dev/mapper/cbn_production') {
        throw 'Encrypted vault unavailable; refusing container recovery'
    }
    $raw = & wsl.exe -d Ubuntu-CBN -u root -- python3 $healthScript
    $health = if ($LASTEXITCODE -eq 0) { $raw | ConvertFrom-Json } else { $null }
    if (-not $health) { throw 'Health inspection unavailable' }
    if (Test-Path -LiteralPath (Join-Path $stateDirectory 'maintenance.flag')) { exit 0 }

    # Restart only an unhealthy running component after the safe mount/start.
    # Never consume inherited queues or start n8n/Telegram.
    if ($health.local_crm -ne 200) {
        & wsl.exe -d Ubuntu-CBN -u root -- docker restart cbn-railway-clone-chatwoot-web-1 | Out-Null
    }
    if ($health.local_crm -eq 200 -and $health.public_crm -ne 200) {
        & wsl.exe -d Ubuntu-CBN -u root -- docker restart cbn-outbound-tunnel-frpc-1 | Out-Null
    }
    if ($health.local_site -ne 200) {
        & wsl.exe -d Ubuntu-CBN -u root -- docker restart cbn-railway-clone-cbn-site-1 | Out-Null
    }
    if ($health.whatsapp -notin @('WORKING', 'STARTING', 'SCAN_QR_CODE')) {
        $restartFile = Join-Path $stateDirectory 'waha-recovery-time.txt'
        $canRestart = $true
        if (Test-Path -LiteralPath $restartFile) {
            $previousRestart = [DateTimeOffset]::Parse((Get-Content -LiteralPath $restartFile -Raw).Trim())
            $canRestart = ([DateTimeOffset]::Now - $previousRestart).TotalMinutes -ge 15
        }
        if ($canRestart) {
            Set-Content -LiteralPath $restartFile -Value ([DateTimeOffset]::Now.ToString('o'))
            & wsl.exe -d Ubuntu-CBN -u root -- docker restart cbn-railway-clone-waha-1 | Out-Null
        }
    }
    # An expired session requires the owner's phone; do not repeatedly reset QR.
    Write-CbnRecoveryEvent $(if ($health.healthy) { 'recovered' } else { 'awaiting_service_or_pairing' })
} catch {
    # Avoid serializing command errors that might contain private configuration.
    Write-CbnRecoveryEvent 'recovery_failed'
    exit 1
}
