[CmdletBinding()]
param([switch]$EnableWrites)
$ErrorActionPreference = 'Stop'
$cbnSourceRoot = Split-Path -Parent $PSScriptRoot
$cbnLocalHome = Join-Path $env:LOCALAPPDATA 'CBN\crm-plugin'
$cbnPluginPath = Join-Path $cbnLocalHome 'plugins\cbn-crm'
$cbnMarketplaceDir = Join-Path $cbnLocalHome '.agents\plugins'
New-Item -ItemType Directory -Force -Path $cbnPluginPath,$cbnMarketplaceDir,(Join-Path $cbnLocalHome 'uploads') | Out-Null
# Credentials, cached media and drafts stay outside OneDrive and the repository.
$cbnIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
& icacls.exe $cbnLocalHome /inheritance:r /grant:r "${cbnIdentity}:(OI)(CI)F" '*S-1-5-18:(OI)(CI)F' | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Não foi possível restringir as permissões da pasta privada.' }
foreach ($cbnEntry in @('src','scripts','plugin.json','mcp.json','package.json','package-lock.json','README.md','config.example.json')) {
    Copy-Item -LiteralPath (Join-Path $cbnSourceRoot $cbnEntry) -Destination $cbnPluginPath -Recurse -Force
}
$cbnMcpPath = Join-Path $cbnPluginPath 'mcp.json'
$cbnMcp = Get-Content -LiteralPath $cbnMcpPath -Raw | ConvertFrom-Json
$cbnMcp.mcpServers.cbn_crm.command = (Get-Command node.exe).Source
$cbnMcp.mcpServers.cbn_crm.args = @((Join-Path $cbnPluginPath 'src\server.mjs'))
$cbnConfigPath = Join-Path $cbnLocalHome 'config.json'
$cbnMcp.mcpServers.cbn_crm | Add-Member -NotePropertyName env -NotePropertyValue @{ CBN_CRM_CONFIG = $cbnConfigPath } -Force
[IO.File]::WriteAllText($cbnMcpPath, ($cbnMcp | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
if (-not (Test-Path -LiteralPath $cbnConfigPath)) {
    Copy-Item -LiteralPath (Join-Path $cbnSourceRoot 'config.example.json') -Destination $cbnConfigPath
}
if ($EnableWrites) {
    $cbnConfiguration = Get-Content -LiteralPath $cbnConfigPath -Raw | ConvertFrom-Json
    $cbnConfiguration.writesEnabled = $true
    [IO.File]::WriteAllText($cbnConfigPath, ($cbnConfiguration | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
}
Push-Location $cbnPluginPath
try {
    & npm.cmd ci --omit=dev --ignore-scripts --fetch-retries=0 --fetch-timeout=20000
    if ($LASTEXITCODE -ne 0) { throw 'Instalação das dependências falhou.' }
} finally { Pop-Location }
$cbnMarketplace = @{
    name = 'cbn-local'
    interface = @{ displayName = 'CBN — integrações locais' }
    plugins = @(@{
        name = 'cbn-crm'
        source = @{ source = 'local'; path = './plugins/cbn-crm' }
        policy = @{ installation = 'AVAILABLE'; authentication = 'ON_INSTALL' }
        category = 'Productivity'
    })
}
[IO.File]::WriteAllText((Join-Path $cbnMarketplaceDir 'marketplace.json'), ($cbnMarketplace | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
& codex plugin marketplace add $cbnLocalHome --json
if ($LASTEXITCODE -ne 0) { throw 'Registro do marketplace falhou.' }
& codex plugin add 'cbn-crm@cbn-local' --json
if ($LASTEXITCODE -ne 0) { throw 'Instalação do plugin no Codex falhou.' }
Write-Output "CBN CRM instalado. Configuração privada: $cbnConfigPath"
Write-Output 'Abra uma nova conversa ou recarregue o aplicativo para carregar as ferramentas.'
