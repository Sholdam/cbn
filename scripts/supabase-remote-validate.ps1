[CmdletBinding()]
param(
  [string]$ProjectRef = $env:SUPABASE_PROJECT_REF,
  [switch]$RemoteTargetConfirmed,
  [switch]$SyntheticDataConfirmed,
  [switch]$MigrationDryRunReviewed,
  [string[]]$ProductionProjectRefs = @(),
  [string]$DatabaseUrlVariable = 'CBN_REMOTE_DATABASE_URL',
  [switch]$PromptForDatabasePassword
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

$safeStatusPath = Join-Path $repoRoot 'supabase\.temp\bkl016-remote-validation-status.json'
function Write-SafeValidationStatus {
  param(
    [string]$Phase,
    [string]$Result,
    [string]$Category
  )
  $status = [ordered]@{
    phase = $Phase
    result = $Result
    category = $Category
  } | ConvertTo-Json -Compress
  [IO.File]::WriteAllText($safeStatusPath, $status, [Text.UTF8Encoding]::new($false))
}
Write-SafeValidationStatus -Phase 'preflight' -Result 'started' -Category 'none'

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
$securePassword = $null
$passwordPointer = [IntPtr]::Zero

if ([string]::IsNullOrWhiteSpace($databaseUrl) -and -not $PromptForDatabasePassword) {
  Write-Error "Defina a conexao remota somente na variavel local $DatabaseUrlVariable ou use -PromptForDatabasePassword; nao cole credencial no chat."
  exit 1
}

try {
  if ($PromptForDatabasePassword) {
    if (-not [string]::IsNullOrWhiteSpace($databaseUrl)) {
      Write-Error 'Escolha somente um mecanismo de credencial: variavel local ou prompt protegido.'
      exit 1
    }

    $poolerPath = Join-Path $repoRoot 'supabase\.temp\pooler-url'
    if (-not (Test-Path -LiteralPath $poolerPath -PathType Leaf)) {
      throw 'pooler'
    }
    $uri = [Uri](Get-Content -Raw -LiteralPath $poolerPath).Trim()
    if ($uri.Scheme -notin @('postgres', 'postgresql') -or
        [string]::IsNullOrWhiteSpace($uri.Host) -or
        [string]::IsNullOrWhiteSpace($uri.UserInfo)) {
      throw 'pooler-format'
    }

    $pgUser = [Uri]::UnescapeDataString(($uri.UserInfo -split ':', 2)[0])
    $securePassword = Read-Host 'Digite a senha do banco cbn-dev (entrada oculta)' -AsSecureString
    $passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    $pgPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer)
    if ([string]::IsNullOrWhiteSpace($pgPassword)) { throw 'empty-password' }
  } else {
    $uri = [Uri]$databaseUrl
    if ($uri.Scheme -notin @('postgres', 'postgresql')) { throw 'scheme' }
    $separator = $uri.UserInfo.IndexOf(':')
    if ($separator -lt 1 -or [string]::IsNullOrWhiteSpace($uri.Host)) {
      throw 'userinfo'
    }
    $pgUser = [Uri]::UnescapeDataString($uri.UserInfo.Substring(0, $separator))
    $pgPassword = [Uri]::UnescapeDataString($uri.UserInfo.Substring($separator + 1))
  }

  $pgHost = $uri.Host
  $pgDatabase = [Uri]::UnescapeDataString($uri.AbsolutePath.TrimStart('/'))
  if ([string]::IsNullOrWhiteSpace($pgDatabase)) { $pgDatabase = 'postgres' }
  $pgPort = if ($uri.IsDefaultPort) { '5432' } else { $uri.Port.ToString() }
} catch {
  Write-SafeValidationStatus -Phase 'credential' -Result 'failed' -Category 'credential_prepare_failed'
  Write-Error 'A conexao local ou a senha nao pode ser preparada; valores omitidos.'
  exit 1
} finally {
  if ($passwordPointer -ne [IntPtr]::Zero) {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer)
    $passwordPointer = [IntPtr]::Zero
  }
  $securePassword = $null
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
  [Environment]::SetEnvironmentVariable('PGHOST', $pgHost, 'Process')
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
    Write-SafeValidationStatus -Phase $check.Label -Result 'started' -Category 'none'
    $previousErrorActionPreference = $ErrorActionPreference
    try {
      $ErrorActionPreference = 'Continue'
      $output = (& psql -X -v ON_ERROR_STOP=1 -f $check.Path 2>&1 | Out-String)
      $psqlExitCode = $LASTEXITCODE
    } finally {
      $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($psqlExitCode -ne 0) {
      $category = if ($output -match '(?i)password authentication failed|authentication failed') {
        'database_authentication_failed'
      } elseif ($output -match '(?i)could not connect|connection (?:timed out|refused|failed)|timeout expired|could not translate host') {
        'database_connection_failed'
      } elseif ($output -match '(?i)permission denied|must be (?:owner|superuser)|insufficient privilege') {
        'database_privilege_failed'
      } elseif ($output -match '(?i)Migration BKL-016|RLS desativada|SECURITY DEFINER|grant inesperado|schema privado|Buckets privados|Bucket BKL-016|Policy publica|Integridade|Protecao|Usuario Auth nao sintetico|Dado real ou segredo') {
        'database_assertion_failed'
      } else {
        'sql_execution_failed'
      }
      Write-SafeValidationStatus -Phase $check.Label -Result 'failed' -Category $category
      Write-Error "Falha na validacao de $($check.Label); a saida detalhada foi omitida para evitar exposicao de dados."
      exit 1
    }
    if ($output -notmatch [regex]::Escape($check.Expected)) {
      Write-SafeValidationStatus -Phase $check.Label -Result 'failed' -Category 'expected_marker_missing'
      Write-Error "A validacao de $($check.Label) nao produziu o marcador final esperado."
      exit 1
    }
    Write-SafeValidationStatus -Phase $check.Label -Result 'passed' -Category 'none'
    Write-Host "$($check.Expected)"
  }
} finally {
  foreach ($name in $savedPgEnvironment.Keys) {
    [Environment]::SetEnvironmentVariable($name, $savedPgEnvironment[$name], 'Process')
  }
  $databaseUrl = $null
  $pgPassword = $null
}

Write-SafeValidationStatus -Phase 'complete' -Result 'passed' -Category 'none'
Write-Host 'BKL-016 remote validation passed; identifiers and credentials omitted.'
