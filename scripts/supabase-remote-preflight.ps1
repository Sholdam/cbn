[CmdletBinding()]
param(
  [string]$ProjectRef = $env:SUPABASE_PROJECT_REF,

  [ValidateSet('LinkInspection', 'RemoteWrite', 'RemoteValidation', 'StorageRuntime', 'Cleanup')]
  [string]$Phase = 'RemoteWrite',

  [switch]$RemoteTargetConfirmed,
  [switch]$SyntheticDataConfirmed,
  [switch]$MigrationDryRunReviewed,
  [string[]]$ProductionProjectRefs = @()
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

$failures = [System.Collections.Generic.List[string]]::new()

function Add-Failure {
  param([string]$Message)
  $failures.Add($Message)
}

function Test-GitCommand {
  param([string[]]$Arguments)
  $output = @(& git @Arguments 2>$null)
  if ($LASTEXITCODE -ne 0) {
    Add-Failure "Falha ao executar git $($Arguments -join ' ')."
    return @()
  }
  return $output
}

$branch = (Test-GitCommand -Arguments @('branch', '--show-current') | Select-Object -First 1)
if ([string]::IsNullOrWhiteSpace($branch)) {
  Add-Failure 'Nao foi possivel identificar a branch atual.'
} elseif ($branch -eq 'main') {
  Add-Failure 'A branch main e bloqueada para a validacao remota.'
} elseif ($Phase -eq 'StorageRuntime' -and $branch -ne 'codex/bkl-016-storage-runtime') {
  Add-Failure 'O runtime de Storage deve ocorrer na branch codex/bkl-016-storage-runtime.'
} elseif ($Phase -ne 'StorageRuntime' -and
    $branch -notin @('codex/bkl-016-remote-dev', 'codex/bkl-016-storage-runtime')) {
  Add-Failure 'A validacao remota deve ocorrer em uma branch BKL-016 explicitamente permitida.'
}

$mainDistance = @(Test-GitCommand -Arguments @('rev-list', '--left-right', '--count', 'origin/main...HEAD'))
if ($mainDistance.Count -ne 1 -or $mainDistance[0] -notmatch '^\s*(\d+)\s+(\d+)\s*$') {
  Add-Failure 'Nao foi possivel comparar a branch com origin/main.'
} elseif ([int]$Matches[1] -ne 0) {
  Add-Failure 'A branch esta atras de origin/main; sincronize antes de qualquer acesso remoto.'
}

$dirty = @(Test-GitCommand -Arguments @('status', '--porcelain', '--untracked-files=all'))
if ($dirty.Count -gt 0) {
  Add-Failure 'A arvore Git esta suja; revise e registre as alteracoes antes de acesso remoto.'
}

if ($env:CBN_ENVIRONMENT -cne 'development') {
  Add-Failure 'Defina CBN_ENVIRONMENT=development apenas na sessao local.'
}

if (-not $SyntheticDataConfirmed) {
  Add-Failure 'Confirme explicitamente que somente dados sinteticos serao usados.'
}

if ([string]::IsNullOrWhiteSpace($ProjectRef)) {
  Add-Failure 'O project ref nao secreto esta vazio.'
} elseif ($ProjectRef -cnotmatch '^[a-z0-9]{20}$') {
  Add-Failure 'O project ref nao possui o formato esperado; o valor foi omitido.'
}

$knownProductionRefs = [System.Collections.Generic.List[string]]::new()
foreach ($value in $ProductionProjectRefs) {
  if (-not [string]::IsNullOrWhiteSpace($value)) {
    $knownProductionRefs.Add($value.Trim())
  }
}
if (-not [string]::IsNullOrWhiteSpace($env:CBN_PRODUCTION_PROJECT_REFS)) {
  foreach ($value in ($env:CBN_PRODUCTION_PROJECT_REFS -split '[,;\s]+')) {
    if (-not [string]::IsNullOrWhiteSpace($value)) {
      $knownProductionRefs.Add($value.Trim())
    }
  }
}
if (-not [string]::IsNullOrWhiteSpace($ProjectRef) -and
    $knownProductionRefs.Contains($ProjectRef)) {
  Add-Failure 'O alvo coincide com um project ref explicitamente marcado como producao.'
}

if (-not $RemoteTargetConfirmed) {
  Add-Failure 'O vinculo remoto ainda nao foi confirmado explicitamente pelo usuario.'
}

$requiresReviewedMigration = $Phase -in @('RemoteWrite', 'RemoteValidation', 'StorageRuntime', 'Cleanup')
if ($requiresReviewedMigration -and -not $MigrationDryRunReviewed) {
  Add-Failure 'A migration pendente nao possui dry-run e revisao explicitamente confirmados.'
}

$linkedProjectMarker = Join-Path $repoRoot 'supabase\.temp\project-ref'
if (Test-Path -LiteralPath $linkedProjectMarker -PathType Leaf) {
  $linkedProjectRef = (Get-Content -Raw -LiteralPath $linkedProjectMarker).Trim()
  if (-not [string]::IsNullOrWhiteSpace($ProjectRef) -and
      $linkedProjectRef -cne $ProjectRef) {
    Add-Failure 'O vinculo local existente nao coincide com o alvo confirmado; valores omitidos.'
  }
} elseif ($Phase -ne 'LinkInspection') {
  Add-Failure 'Nenhum vinculo local foi encontrado para a fase solicitada.'
}

$trackedFiles = @(Test-GitCommand -Arguments @('ls-files'))
$trackedEnvFiles = @($trackedFiles | Where-Object {
  $_ -match '(^|/)\.env($|\.)' -and
  $_ -notmatch '(?i)\.(example|sample|template)$'
})
if ($trackedEnvFiles.Count -gt 0) {
  Add-Failure 'Existe arquivo .env versionado; caminhos omitidos.'
}

$secretPatterns = @(
  @{ Name = 'chave privada'; Regex = '(?i)-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----' },
  @{ Name = 'token conhecido'; Regex = '(?i)\b(?:sk-proj|sk-|ghp_|github_pat_|xox[baprs]-|sb_secret_)[A-Za-z0-9_-]{16,}' },
  @{ Name = 'JWT preenchido'; Regex = '(?i)\beyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{16,}\b' },
  @{ Name = 'URL assinada de Storage'; Regex = '(?i)https://[^\s"'']+/storage/v1/object/sign/[^\s"'']+[?&](?:token|signature)=[A-Za-z0-9._~-]{12,}' },
  @{ Name = 'segredo preenchido'; Regex = '(?im)^[A-Z0-9_]*(?:PASSWORD|TOKEN|SECRET|PRIVATE_KEY|API_HASH|SESSION|SERVICE_ROLE_KEY)[A-Z0-9_]*\s*=\s*[^\s<#][^\r\n]*$' },
  @{ Name = 'CPF completo'; Regex = '(?<![0-9])[0-9]{3}\.?[0-9]{3}\.?[0-9]{3}-?[0-9]{2}(?![0-9])' }
)

$textFilePattern = '(?i)(^|/)(?:\.gitignore|[^/]+\.(?:md|txt|ps1|sql|toml|json|ya?ml|py|m?js|ts|example))$'
foreach ($relativePath in $trackedFiles) {
  if ($relativePath -notmatch $textFilePattern) { continue }
  $path = Join-Path $repoRoot $relativePath
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }

  $content = Get-Content -Raw -LiteralPath $path
  foreach ($pattern in $secretPatterns) {
    if ($content -match $pattern.Regex) {
      Add-Failure "$($pattern.Name) detectado no repositorio (valor e caminho omitidos)."
      break
    }
  }
}

$historyPatterns = @(
  '-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----',
  '(sk-proj|sk-|ghp_|github_pat_|xox[baprs]-|sb_secret_)[A-Za-z0-9_-]{16,}',
  'eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{16,}',
  'https://[^[:space:]"'']+/storage/v1/object/sign/[^[:space:]"'']+[?&](token|signature)=[A-Za-z0-9._~-]{12,}',
  '(?<![0-9])[0-9]{3}\.?[0-9]{3}\.?[0-9]{3}-?[0-9]{2}(?![0-9])',
  '^[A-Z0-9_]*(PASSWORD|TOKEN|SECRET|PRIVATE_KEY|API_HASH|SESSION|SERVICE_ROLE_KEY)[A-Z0-9_]*\s*=\s*[^\s<#]'
)
$historyHasSensitivePattern = $false
$commitIds = @(Test-GitCommand -Arguments @('rev-list', '--all'))
foreach ($commitId in $commitIds) {
  $grepArguments = [System.Collections.Generic.List[string]]::new()
  foreach ($argument in @('grep', '-q', '-I', '-P')) { $grepArguments.Add($argument) }
  foreach ($pattern in $historyPatterns) {
    $grepArguments.Add('-e')
    $grepArguments.Add($pattern)
  }
  $grepArguments.Add($commitId)
  $grepArguments.Add('--')

  & git @grepArguments 2>$null
  if ($LASTEXITCODE -eq 0) {
    $historyHasSensitivePattern = $true
    break
  }
  if ($LASTEXITCODE -ne 1) {
    Add-Failure 'A varredura sanitizada do historico Git falhou.'
    break
  }
}
if ($historyHasSensitivePattern) {
  Add-Failure 'Padrao aparente de segredo ou dado pessoal detectado no historico Git; valor e commit omitidos.'
}

$configPath = Join-Path $repoRoot 'supabase\config.toml'
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
  Add-Failure 'supabase/config.toml nao foi encontrado.'
} else {
  $config = Get-Content -Raw -LiteralPath $configPath
  $schemaAssignments = [regex]::Matches($config, '(?im)^\s*(?:extra_)?schemas\s*=\s*\[[^\]]*\]')
  foreach ($assignment in $schemaAssignments) {
    if ($assignment.Value -match '(?i)["''](?:app_private|audit)["'']') {
      Add-Failure 'Schema privado aparece na lista exposta pelo PostgREST.'
    }
  }
}

$gatewayChanges = @(Test-GitCommand -Arguments @(
  'diff', '--name-only', 'origin/main...HEAD', '--', 'telegram-gateway'
))
if ($gatewayChanges.Count -gt 0) {
  Add-Failure 'telegram-gateway/ possui alteracoes nesta branch.'
}

if ($Phase -eq 'StorageRuntime' -and $failures.Count -eq 0) {
  $previousErrorActionPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = 'Continue'
    $migrationOutput = @(& supabase migration list --linked --output-format json 2>$null)
    $migrationExitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }
  if ($migrationExitCode -ne 0) {
    Add-Failure 'Nao foi possivel reconciliar migrations locais e remotas pelo vinculo confirmado.'
  } else {
    try {
      $migrationResult = (($migrationOutput -join "`n") | ConvertFrom-Json -ErrorAction Stop)
      foreach ($migrationVersion in @('20260715', '20260716')) {
        $matchingMigration = @($migrationResult.migrations | Where-Object {
          $_.local -ceq $migrationVersion -and $_.remote -ceq $migrationVersion
        })
        if ($matchingMigration.Count -ne 1) {
          Add-Failure "A migration esperada $migrationVersion nao esta reconciliada entre local e remoto."
        }
      }
      $divergentMigration = @($migrationResult.migrations | Where-Object {
        [string]::IsNullOrWhiteSpace($_.local) -or
        [string]::IsNullOrWhiteSpace($_.remote) -or
        $_.local -cne $_.remote
      })
      if ($divergentMigration.Count -gt 0) {
        Add-Failure 'Existe divergencia entre migrations locais e remotas; detalhes omitidos.'
      }
    } catch {
      Add-Failure 'A resposta sanitizada da conciliacao de migrations nao possui o formato esperado.'
    }
  }

  try {
    $ErrorActionPreference = 'Continue'
    $storageOutput = @(& supabase --experimental storage ls --linked 'ss:///' --output-format json 2>$null)
    $storageExitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }
  if ($storageExitCode -ne 0) {
    Add-Failure 'Nao foi possivel confirmar o bucket temporario pelo vinculo existente.'
  } else {
    try {
      $storageResult = (($storageOutput -join "`n") | ConvertFrom-Json -ErrorAction Stop)
      if (@($storageResult.paths) -cnotcontains 'cbn-temporary-private/') {
        Add-Failure 'O bucket temporario esperado nao foi localizado; identificadores remotos omitidos.'
      }
    } catch {
      Add-Failure 'A resposta sanitizada da listagem de Storage nao possui o formato esperado.'
    }
  }
}

if ($failures.Count -gt 0) {
  foreach ($failure in ($failures | Select-Object -Unique)) {
    Write-Error $failure -ErrorAction Continue
  }
  exit 1
}

Write-Host "BKL-016 remote preflight passed for phase $Phase; target identifiers omitted."
