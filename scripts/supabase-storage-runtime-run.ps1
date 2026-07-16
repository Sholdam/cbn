[CmdletBinding()]
param(
  [string]$ProjectRef = $env:SUPABASE_PROJECT_REF,
  [switch]$RemoteTargetConfirmed,
  [switch]$SyntheticDataConfirmed,
  [switch]$MigrationDryRunReviewed,
  [switch]$PromptForBackendCredential,
  [string[]]$ProductionProjectRefs = @(),
  [string]$ProjectUrlVariable = 'CBN_SUPABASE_URL',
  [string]$BackendKeyVariable = 'CBN_SUPABASE_BACKEND_KEY'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

foreach ($variableName in @($ProjectUrlVariable, $BackendKeyVariable)) {
  if ($variableName -cnotmatch '^[A-Z][A-Z0-9_]{2,80}$') {
    Write-Error 'O nome de uma variavel local do runtime nao e valido.'
    exit 1
  }
}

$env:CBN_ENVIRONMENT = 'development'
$env:CBN_STORAGE_RUNTIME_CONFIRMED = if ($SyntheticDataConfirmed) { 'true' } else { '' }

& (Join-Path $PSScriptRoot 'supabase-remote-preflight.ps1') `
  -ProjectRef $ProjectRef `
  -Phase StorageRuntime `
  -RemoteTargetConfirmed:$RemoteTargetConfirmed `
  -SyntheticDataConfirmed:$SyntheticDataConfirmed `
  -MigrationDryRunReviewed:$MigrationDryRunReviewed `
  -ProductionProjectRefs $ProductionProjectRefs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$projectUrl = [Environment]::GetEnvironmentVariable($ProjectUrlVariable, 'Process')
$existingBackendKey = [Environment]::GetEnvironmentVariable($BackendKeyVariable, 'Process')
if ([string]::IsNullOrWhiteSpace($projectUrl)) {
  Write-Error "Defina a URL do projeto somente na variavel de processo $ProjectUrlVariable; valor omitido."
  exit 1
}
if (-not [string]::IsNullOrWhiteSpace($existingBackendKey) -and $PromptForBackendCredential) {
  Write-Error 'Escolha somente um mecanismo de credencial backend: variavel de processo ou prompt protegido.'
  exit 1
}
if ([string]::IsNullOrWhiteSpace($existingBackendKey) -and -not $PromptForBackendCredential) {
  Write-Error "Gate de credencial ativo: defina $BackendKeyVariable somente no processo ou use -PromptForBackendCredential."
  exit 1
}

$secureBackendKey = $null
$backendKeyPointer = [IntPtr]::Zero
try {
  if ($PromptForBackendCredential) {
    $secureBackendKey = Read-Host 'Digite a credencial backend do cbn-dev (entrada oculta)' -AsSecureString
    $backendKeyPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureBackendKey)
    $backendKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($backendKeyPointer)
    if ([string]::IsNullOrWhiteSpace($backendKey)) {
      Write-Error 'A credencial backend local esta vazia.'
      exit 1
    }
    [Environment]::SetEnvironmentVariable($BackendKeyVariable, $backendKey, 'Process')
    $backendKey = $null
  }

  & node (Join-Path $PSScriptRoot 'supabase-storage-runtime-test.mjs')
  if ($LASTEXITCODE -ne 0) {
    Write-Error 'O runtime de Storage falhou; detalhes sensiveis foram omitidos.'
    exit $LASTEXITCODE
  }
} finally {
  if ($backendKeyPointer -ne [IntPtr]::Zero) {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($backendKeyPointer)
    $backendKeyPointer = [IntPtr]::Zero
  }
  $secureBackendKey = $null
  $existingBackendKey = $null
  [Environment]::SetEnvironmentVariable($BackendKeyVariable, $null, 'Process')
  [Environment]::SetEnvironmentVariable($ProjectUrlVariable, $null, 'Process')
}

& (Join-Path $PSScriptRoot 'supabase-remote-validate.ps1') `
  -ProjectRef $ProjectRef `
  -RemoteTargetConfirmed:$RemoteTargetConfirmed `
  -SyntheticDataConfirmed:$SyntheticDataConfirmed `
  -MigrationDryRunReviewed:$MigrationDryRunReviewed `
  -ProductionProjectRefs $ProductionProjectRefs `
  -PromptForDatabasePassword
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'BKL-016 Storage runtime validation passed'
