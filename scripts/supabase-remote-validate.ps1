[CmdletBinding()]
param(
  [string]$ProjectRef = $env:SUPABASE_PROJECT_REF,
  [switch]$RemoteTargetConfirmed,
  [switch]$SyntheticDataConfirmed,
  [switch]$MigrationDryRunReviewed,
  [string[]]$ProductionProjectRefs = @(),
  [string]$DatabaseUrlVariable = 'CBN_REMOTE_DATABASE_URL'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

$preflightPath = Join-Path $PSScriptRoot 'supabase-remote-preflight.ps1'
& $preflightPath `
  -ProjectRef $ProjectRef `
  -Phase RemoteValidation `
  -RemoteTargetConfirmed:$RemoteTargetConfirmed `
  -SyntheticDataConfirmed:$SyntheticDataConfirmed `
  -MigrationDryRunReviewed:$MigrationDryRunReviewed `
  -ProductionProjectRefs $ProductionProjectRefs
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

if ($DatabaseUrlVariable -cnotmatch '^[A-Z][A-Z0-9_]{2,80}$') {
  Write-Error 'O nome da variavel local de conexao nao e valido.'
  exit 1
}

$databaseUrl = [Environment]::GetEnvironmentVariable($DatabaseUrlVariable, 'Process')
if ([string]::IsNullOrWhiteSpace($databaseUrl)) {
  Write-Error "Defina a conexao remota somente na variavel local $DatabaseUrlVariable; nao use arquivo versionado nem cole a credencial no chat."
  exit 1
}

try {
  $uri = [Uri]$databaseUrl
  if ($uri.Scheme -notin @('postgres', 'postgresql')) {
    throw 'scheme'
  }
  $separator = $uri.UserInfo.IndexOf(':')
  if ($separator -lt 1 -or [string]::IsNullOrWhiteSpace($uri.Host)) {
    throw 'userinfo'
  }

  $pgUser = [Uri]::UnescapeDataString($uri.UserInfo.Substring(0, $separator))
  $pgPassword = [Uri]::UnescapeDataString($uri.UserInfo.Substring($separator + 1))
  $pgDatabase = [Uri]::UnescapeDataString($uri.AbsolutePath.TrimStart('/'))
  if ([string]::IsNullOrWhiteSpace($pgDatabase)) { $pgDatabase = 'postgres' }
  $pgPort = if ($uri.IsDefaultPort) { '5432' } else { $uri.Port.ToString() }
} catch {
  Write-Error 'A URL de conexao local nao possui formato PostgreSQL valido; o valor foi omitido.'
  exit 1
}

if (-not (Get-Command psql -ErrorAction SilentlyContinue)) {
  Write-Error 'psql nao esta disponivel no PATH.'
  exit 1
}

$savedPgEnvironment = @{}
foreach ($name in @('PGHOST', 'PGPORT', 'PGDATABASE', 'PGUSER', 'PGPASSWORD', 'PGSSLMODE')) {
  $savedPgEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}

try {
  [Environment]::SetEnvironmentVariable('PGHOST', $uri.Host, 'Process')
  [Environment]::SetEnvironmentVariable('PGPORT', $pgPort, 'Process')
  [Environment]::SetEnvironmentVariable('PGDATABASE', $pgDatabase, 'Process')
  [Environment]::SetEnvironmentVariable('PGUSER', $pgUser, 'Process')
  [Environment]::SetEnvironmentVariable('PGPASSWORD', $pgPassword, 'Process')
  [Environment]::SetEnvironmentVariable('PGSSLMODE', 'require', 'Process')

  $checks = @(
    @{
      Path = 'supabase\tests\bkl016_remote_validation.sql'
      Expected = 'BKL-016 remote structural checks passed'
      Label = 'estrutura remota, RLS, grants e Storage'
    },
    @{
      Path = 'supabase\tests\bkl016_secure_storage_test.sql'
      Expected = 'BKL-016 database and RLS checks passed'
      Label = 'suite transacional de papeis e integridade'
    }
  )

  foreach ($check in $checks) {
    $output = (& psql -X -v ON_ERROR_STOP=1 -f $check.Path 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0) {
      Write-Error "Falha na validacao de $($check.Label); a saida detalhada foi omitida para evitar exposicao de dados."
      exit 1
    }
    if ($output -notmatch [regex]::Escape($check.Expected)) {
      Write-Error "A validacao de $($check.Label) nao produziu o marcador final esperado."
      exit 1
    }
    Write-Host "$($check.Expected)"
  }
} finally {
  foreach ($name in $savedPgEnvironment.Keys) {
    [Environment]::SetEnvironmentVariable($name, $savedPgEnvironment[$name], 'Process')
  }
  $databaseUrl = $null
  $pgPassword = $null
}

Write-Host 'BKL-016 remote validation passed; identifiers and credentials omitted.'
