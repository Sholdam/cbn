[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

$failures = [System.Collections.Generic.List[string]]::new()
$files = git ls-files --cached --others --exclude-standard

$realEnvFiles = Get-ChildItem -LiteralPath $repoRoot -Recurse -Force -File -Filter '.env' |
  Where-Object { $_.FullName -notmatch '[\\/](?:\.git|node_modules)[\\/]' }
foreach ($envFile in $realEnvFiles) {
  $relativeEnv = [System.IO.Path]::GetRelativePath($repoRoot, $envFile.FullName)
  $failures.Add("Arquivo .env real encontrado: $relativeEnv")
}

$patterns = @(
  @{ Name = 'chave privada'; Regex = '(?i)-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----' },
  @{ Name = 'token conhecido'; Regex = '(?i)\b(?:sk-proj|sk-|ghp_|github_pat_|xox[baprs]-)[A-Za-z0-9_-]{16,}' },
  @{ Name = 'JWT preenchido'; Regex = '(?i)\beyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{16,}\b' },
  @{ Name = 'CPF completo'; Regex = '(?<![0-9])[0-9]{3}\.?[0-9]{3}\.?[0-9]{3}-?[0-9]{2}(?![0-9])' },
  @{ Name = 'secret preenchido'; Regex = '(?im)^[A-Z0-9_]*(?:PASSWORD|TOKEN|SECRET|PRIVATE_KEY|API_HASH|SESSION|SERVICE_ROLE_KEY)[A-Z0-9_]*=[^\s#].+$' }
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

if ($migration -match '(?i)pending_items_action_code_ck') {
  $failures.Add('Constraint incorreta pending_items_action_code_ck ainda existe.')
}
if ($migration -notmatch '(?i)constraint\s+interactions_event_type_ck\s+check\s*\(\s*event_type') {
  $failures.Add('Constraint interactions_event_type_ck ausente ou ligada a coluna errada.')
}
if ($migration -notmatch "(?i)position\('\*'\s+in\s+phone_masked\)\s*>\s*0") {
  $failures.Add('phone_masked nao exige asterisco de mascaramento.')
}
if ($migration -notmatch "(?i)position\('\*'\s+in\s+cpf_masked\)\s*>\s*0") {
  $failures.Add('cpf_masked nao exige asterisco de mascaramento.')
}
if ($migration -notmatch '(?i)regexp_replace\(phone_masked.+\)\s*!~\s*''\^\[0-9\]\{10,13\}\$''') {
  $failures.Add('phone_masked nao bloqueia telefone completo de 10 a 13 digitos.')
}
if ($migration -notmatch '(?i)regexp_replace\(cpf_masked.+\)\s*!~\s*''\^\[0-9\]\{11\}\$''') {
  $failures.Add('cpf_masked nao bloqueia CPF completo com formatacao.')
}
if ($migration -notmatch '(?i)final_authorization_evidence_payload_ref\s+uuid\s+not\s+null') {
  $failures.Add('Referencia obrigatoria da evidencia final protegida nao foi encontrada.')
}
if ($migration -notmatch '(?is)foreign key\s*\(\s*final_authorization_evidence_payload_ref\s*,\s*final_authorization_evidence_type\s*\).*?references\s+app_private\.protected_payloads\(id,\s*payload_type\)\s+on delete restrict') {
  $failures.Add('Evidencia final nao possui FK conservadora para protected_payloads.')
}
if ($migration -match '(?im)^\s*grant\s+execute\b.*\bto\s+anon\b') {
  $failures.Add('anon recebeu EXECUTE explicito desnecessario.')
}

$migrationLines = $migration -split "`r?`n"
for ($index = 0; $index -lt $migrationLines.Count; $index++) {
  if ($migrationLines[$index] -match '(?i)^\s*security\s+definer\s*$') {
    $lastIndex = [Math]::Min($index + 4, $migrationLines.Count - 1)
    $window = ($migrationLines[($index + 1)..$lastIndex] -join "`n")
    if ($window -notmatch "(?i)set\s+search_path\s*=\s*''") {
      $failures.Add("SECURITY DEFINER sem search_path vazio perto da linha $($index + 1).")
    }
  }
}

$databaseTests = Get-Content -Raw -LiteralPath 'supabase\tests\bkl016_secure_storage_test.sql'
foreach ($fixture in @('admin', 'operations', 'support', 'auditor', 'no-profile')) {
  if ($databaseTests -notmatch [regex]::Escape("$fixture.bkl016@example.invalid")) {
    $failures.Add("Fixture Auth sintetica ausente: $fixture")
  }
}
foreach ($requiredCheck in @(
  'set local role anon',
  'set local role authenticated',
  'get_client_sensitive_summary',
  'Snapshot de oferta e imutavel',
  'final_authorization_evidence_payload_ref',
  'rollback;'
)) {
  if ($databaseTests -notmatch [regex]::Escape($requiredCheck)) {
    $failures.Add("Teste de banco obrigatorio ausente: $requiredCheck")
  }
}

$rollback = Get-Content -Raw -LiteralPath 'supabase\rollback\20260715_001_bkl016_secure_storage_down.sql'
$privateSchemaDrop = $rollback.IndexOf('drop schema if exists app_private cascade;')
$proposalDrop = $rollback.IndexOf('drop table if exists public.proposals;')
if ($privateSchemaDrop -lt 0 -or $proposalDrop -lt 0 -or $privateSchemaDrop -gt $proposalDrop) {
  $failures.Add('Rollback nao remove app_private antes das tabelas publicas dependentes.')
}

if ($failures.Count -gt 0) {
  $failures | ForEach-Object { Write-Error $_ }
  exit 1
}

Write-Host 'BKL-016 static checks passed: estrutura, seed sintetico e varredura de segredos/CPF.'
