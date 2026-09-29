param()

$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'start-cbn-clone.ps1') | Out-Null

$mountedSource = & wsl.exe -d Ubuntu-CBN -u root -- findmnt -n -o SOURCE --target /srv/cbn-production
if ($LASTEXITCODE -ne 0 -or $mountedSource.Trim() -ne '/dev/mapper/cbn_production') {
    throw 'O cofre CBN nao esta montado no dispositivo esperado.'
}

$clientEnv = '/srv/cbn-production/secrets/frp/client.env'
& wsl.exe -d Ubuntu-CBN -u root -- test -f $clientEnv
if ($LASTEXITCODE -ne 0) { throw 'Endpoint Railway nao configurado no cofre.' }

$compose = '/mnt/c/Users/GUILHERME/OneDrive/Documentos/ChatGPT/CBN/cbn-infrastructure-migration/infra/tunnel/local/compose.yml'
& wsl.exe -d Ubuntu-CBN -u root -- docker compose -f $compose --profile public up -d site-preview frpc
if ($LASTEXITCODE -ne 0) { throw 'Falha ao iniciar o tunel CBN.' }

$status = & wsl.exe -d Ubuntu-CBN -u root -- docker inspect --format '{{.State.Running}}' cbn-outbound-tunnel-frpc-1
if ($LASTEXITCODE -ne 0 -or $status.Trim() -ne 'true') {
    throw 'O tunel CBN iniciou, mas nao permaneceu ativo.'
}
$siteStatus = & wsl.exe -d Ubuntu-CBN -u root -- docker inspect --format '{{.State.Running}}' cbn-outbound-tunnel-site-preview-1
if ($LASTEXITCODE -ne 0 -or $siteStatus.Trim() -ne 'true') {
    throw 'O encaminhamento do site CBN nao permaneceu ativo.'
}
$domain = & wsl.exe -d Ubuntu-CBN -u root -- docker exec cbn-outbound-tunnel-frpc-1 printenv FRP_CRM_DOMAIN
if ($LASTEXITCODE -ne 0 -or $domain.Trim() -notmatch '^[a-zA-Z0-9.-]+\.up\.railway\.app$') {
    throw 'Dominio publico do tunel inesperado.'
}
$baseUrl = "https://$($domain.Trim())"
$publicReady = $false
for ($attempt = 0; $attempt -lt 12; $attempt++) {
    try {
        $crm = Invoke-WebRequest -Uri "$baseUrl/" -SkipHttpErrorCheck -TimeoutSec 3
        $site = Invoke-WebRequest -Uri "$baseUrl/site/" -SkipHttpErrorCheck -TimeoutSec 3
        if ([int]$crm.StatusCode -eq 401 -and [int]$site.StatusCode -eq 200) {
            $publicReady = $true
            break
        }
    } catch { }
    Start-Sleep -Seconds 2
}
if (-not $publicReady) { throw 'As rotas publicas do CRM e do site nao responderam como esperado.' }
Write-Output "crm_publico=$baseUrl/"
Write-Output "site_previa=$baseUrl/site/"
Write-Output 'tunel=ativo'
