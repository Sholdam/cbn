[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

$failures = [System.Collections.Generic.List[string]]::new()
$files = git ls-files --cached --others --exclude-standard

if (Test-Path -LiteralPath '.env') {
  $failures.Add('Arquivo .env real encontrado na raiz.')
}
if (Test-Path -LiteralPath 'telegram-gateway\.env') {
  $failures.Add('Arquivo telegram-gateway/.env real encontrado.')
}

$patterns = @(
  @{ Name = 'chave privada'; Regex = '(?i)-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----' },
  @{ Name = 'token conhecido'; Regex = '(?i)\b(?:sk-proj|sk-|ghp_|github_pat_|xox[baprs]-)[A-Za-z0-9_-]{16,}' },
  @{ Name = 'CPF completo'; Regex = '(?<![0-9])[0-9]{3}\.?[0-9]{3}\.?[0-9]{3}-?[0-9]{2}(?![0-9])' },
  @{ Name = 'secret preenchido'; Regex = '(?m)^(?:SUPABASE_SERVICE_ROLE_KEY|TELEGRAM_API_HASH|TELEGRAM_SESSION)=[^\s#].+$' }
)

foreach ($relativePath in $files) {
  if ($relativePath -eq 'scripts/validate-bkl016.ps1') { continue }
  $path = Join-Path $repoRoot $relativePath
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }

  $content = Get-Content -Raw -LiteralPath $path -ErrorAction Stop
  foreach ($pattern in $patterns) {
    if ($content -match $pattern.Regex) {
      $failures.Add("$($pattern.Name) detectado em $relativePath (valor omitido).")
    }
  }
}

$seed = Get-Content -Raw -LiteralPath 'supabase\seed.sql'
if ($seed -notmatch '(?i)synthetic') {
  $failures.Add('O seed nao esta claramente identificado como sintetico.')
}
if ($seed -match '(?i)insert\s+into\s+(?:auth\.users|app_private\.)') {
  $failures.Add('O seed nao deve criar usuario Auth nem dado privado.')
}

$migration = Get-Content -Raw -LiteralPath 'supabase\migrations\20260715_001_bkl016_secure_storage.sql'
$requiredTables = @(
  'clients', 'consultations', 'offers', 'proposals', 'interactions',
  'pending_items', 'technical_operations', 'client_sensitive_data',
  'proposal_sensitive_data', 'protected_payloads', 'protected_file_refs',
  'user_profiles'
)
foreach ($table in $requiredTables) {
  if ($migration -notmatch "(?i)create table if not exists [a-z_]+\.$table") {
    $failures.Add("Tabela esperada nao localizada na migration: $table")
  }
}

if ($failures.Count -gt 0) {
  $failures | ForEach-Object { Write-Error $_ }
  exit 1
}

Write-Host 'BKL-016 static checks passed: estrutura, seed sintetico e varredura de segredos/CPF.'
