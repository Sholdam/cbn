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
  @{ Name = 'token conhecido'; Regex = '(?i)\b(?:sk-proj|sk-|ghp_|github_pat_|xox[baprs]-|sb_secret_)[A-Za-z0-9_-]{16,}' },
  @{ Name = 'JWT preenchido'; Regex = '(?i)\beyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{16,}\b' },
  @{ Name = 'URL assinada de Storage'; Regex = '(?i)https://[^\s"'']+/storage/v1/object/sign/[^\s"'']+[?&](?:token|signature)=[A-Za-z0-9._~-]{12,}' },
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
if ($seed -match '(?i)insert\s+into\s+auth\.users') {
  $failures.Add('O seed nao deve criar usuario Auth.')
}
$privateSeedTargets = [regex]::Matches(
  $seed, '(?i)insert\s+into\s+app_private\.([a-z_]+)'
) | ForEach-Object { $_.Groups[1].Value.ToLowerInvariant() } | Sort-Object -Unique
foreach ($target in $privateSeedTargets) {
  if ($target -ne 'protected_payloads') {
    $failures.Add("Seed privado fora do escopo sintetico permitido: $target")
  }
}
if ($seed -notmatch '(?is)insert\s+into\s+app_private\.protected_payloads.*?FINAL_AUTHORIZATION_EVIDENCE' -or
    $seed -notmatch '(?is)insert\s+into\s+public\.proposals.*?final_authorization_evidence_payload_ref') {
  $failures.Add('Seed nao comprova evidencia sintetica criada antes da proposta.')
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
if ($migration -notmatch '(?is)constraint\s+technical_operations_owner_product_uk\s+unique\s*\(\s*operation_id\s*,\s*client_id\s*,\s*product\s*\)') {
  $failures.Add('Operacao tecnica nao possui chave candidata de cliente/produto.')
}
if ($migration -notmatch '(?is)constraint\s+consultations_operation_owner_product_fk\s+foreign key\s*\(\s*operation_id\s*,\s*client_id\s*,\s*product\s*\)\s*references\s+public\.technical_operations\s*\(\s*operation_id\s*,\s*client_id\s*,\s*product\s*\)\s*on delete restrict') {
  $failures.Add('Consulta nao possui FK composta para o contexto da operacao.')
}
if ($migration -notmatch '(?is)constraint\s+proposals_operation_owner_product_fk\s+foreign key\s*\(\s*operation_id\s*,\s*client_id\s*,\s*product\s*\)\s*references\s+public\.technical_operations\s*\(\s*operation_id\s*,\s*client_id\s*,\s*product\s*\)\s*on delete restrict') {
  $failures.Add('Proposta nao possui FK composta para o contexto da operacao.')
}
if ($migration -notmatch '(?i)final_authorization_evidence_payload_ref\s+uuid\s+not\s+null') {
  $failures.Add('Referencia obrigatoria da evidencia final protegida nao foi encontrada.')
}
if ($migration -notmatch '(?is)constraint\s+protected_payloads_evidence_ownership_uk\s+unique\s*\(\s*id\s*,\s*client_id\s*,\s*operation_id\s*,\s*payload_type\s*\)') {
  $failures.Add('Payload protegido nao possui chave unica composta de propriedade.')
}
if ($migration -notmatch '(?is)foreign key\s*\(\s*final_authorization_evidence_payload_ref\s*,\s*client_id\s*,\s*operation_id\s*,\s*final_authorization_evidence_type\s*\).*?references\s+app_private\.protected_payloads\s*\(\s*id\s*,\s*client_id\s*,\s*operation_id\s*,\s*payload_type\s*\)\s+on delete restrict') {
  $failures.Add('Evidencia final nao possui FK composta de payload, cliente, operacao e tipo.')
}
if ($migration -notmatch '(?is)protected_payloads_final_authorization_owner_ck\s+check\s*\(.*?FINAL_AUTHORIZATION_EVIDENCE.*?client_id\s+is\s+not\s+null.*?operation_id\s+is\s+not\s+null') {
  $failures.Add('Evidencia final pode nascer sem cliente ou operacao.')
}
if ($migration -match '(?im)^\s*grant\s+execute\b.*\bto\s+anon\b') {
  $failures.Add('anon recebeu EXECUTE explicito desnecessario.')
}
if ($migration -notmatch '(?is)revoke\s+all\s+on\s+public\.user_profiles.*?public\.pending_items\s+from\s+public\s*,\s*anon\s*;') {
  $failures.Add('Migration-base nao revoga grants operacionais de PUBLIC e anon.')
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
  'Consulta com operacao do mesmo dono/produto nao foi criada',
  'Consulta aceitou operation_id de outro cliente',
  'Consulta aceitou operation_id de outro produto',
  'Proposta aceitou operation_id de outro cliente',
  'Proposta aceitou operation_id de outro produto',
  'Proposta com evidencia do mesmo dono nao foi criada',
  'Evidencia de outro cliente foi aceita',
  'Evidencia de outra operacao foi aceita',
  'Evidencia de tipo incorreto foi aceita',
  'Proposta sem evidencia protegida valida foi aceita',
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
if ($rollback -notmatch "(?is)set_config\('storage\.allow_delete_query',\s*'true',\s*true\).*?delete\s+from\s+storage\.buckets.*?not\s+exists\s*\(\s*select\s+1\s+from\s+storage\.objects") {
  $failures.Add('Rollback nao libera/remover buckets vazios de forma protegida.')
}

$remoteArtifacts = @(
  'docs\BKL-016_REMOTE_DEV_RUNBOOK.md',
  'scripts\supabase-remote-preflight.ps1',
  'scripts\supabase-remote-validate.ps1',
  'scripts\supabase-remote-cleanup.ps1',
  'supabase\tests\bkl016_remote_validation.sql'
)
foreach ($artifact in $remoteArtifacts) {
  if (-not (Test-Path -LiteralPath $artifact -PathType Leaf)) {
    $failures.Add("Artefato de preparacao remota ausente: $artifact")
  }
}

$storageRuntimeArtifacts = @(
  'scripts\package.json',
  'scripts\package-lock.json',
  'scripts\supabase-storage-runtime-test.mjs',
  'scripts\supabase-storage-runtime-test.test.mjs',
  'scripts\supabase-storage-runtime-run.ps1'
)
foreach ($artifact in $storageRuntimeArtifacts) {
  if (-not (Test-Path -LiteralPath $artifact -PathType Leaf)) {
    $failures.Add("Artefato do runtime de Storage ausente: $artifact")
  }
}

if (Test-Path -LiteralPath 'scripts\supabase-remote-preflight.ps1') {
  $remotePreflight = Get-Content -Raw -LiteralPath 'scripts\supabase-remote-preflight.ps1'
  foreach ($requiredGate in @(
    'codex/bkl-016-remote-dev',
    'codex/bkl-016-storage-runtime',
    'StorageRuntime',
    'CBN_ENVIRONMENT',
    'RemoteTargetConfirmed',
    'SyntheticDataConfirmed',
    'MigrationDryRunReviewed',
    'CBN_PRODUCTION_PROJECT_REFS',
    '20260715_001_bkl016_secure_storage.sql',
    '20260716_001_bkl016_revoke_anon_operational_grants.sql',
    'cbn-temporary-private',
    'app_private',
    'audit'
  )) {
    if ($remotePreflight -notmatch [regex]::Escape($requiredGate)) {
      $failures.Add("Gate remoto obrigatorio ausente: $requiredGate")
    }
  }
}


if (Test-Path -LiteralPath 'scripts\package.json') {
  $storagePackage = Get-Content -Raw -LiteralPath 'scripts\package.json'
  foreach ($requiredPackageValue in @('@supabase/supabase-js', '2.110.6', 'node --test')) {
    if ($storagePackage -notmatch [regex]::Escape($requiredPackageValue)) {
      $failures.Add("Configuracao npm do runtime ausente: $requiredPackageValue")
    }
  }
}

if (Test-Path -LiteralPath 'scripts\supabase-storage-runtime-test.mjs') {
  $storageRuntime = Get-Content -Raw -LiteralPath 'scripts\supabase-storage-runtime-test.mjs'
  foreach ($requiredRuntimeValue in @(
    "from '@supabase/supabase-js'",
    'codex/bkl-016-storage-runtime',
    'cbn-temporary-private',
    'upsert: false',
    'createSignedUrl',
    'getPublicUrl',
    'finally',
    'remove([objectName])',
    'BKL-016 Storage backend preflight passed',
    'BKL-016 Storage upload passed',
    'BKL-016 anonymous access denied',
    'BKL-016 signed URL pre-expiry download passed',
    'BKL-016 signed URL expiration passed',
    'BKL-016 Storage local leak scan passed',
    'BKL-016 Storage cleanup passed'
  )) {
    if ($storageRuntime -notmatch [regex]::Escape($requiredRuntimeValue)) {
      $failures.Add("Controle obrigatorio do runtime de Storage ausente: $requiredRuntimeValue")
    }
  }
  if ($storageRuntime -match '(?i)service[_ -]?role' -or $storageRuntime -match '(?i)window\.|localStorage') {
    $failures.Add('Runtime de Storage contem uso proibido de service_role nominal ou contexto de navegador.')
  }
}

if (Test-Path -LiteralPath 'scripts\supabase-storage-runtime-test.test.mjs') {
  $storageRuntimeTests = Get-Content -Raw -LiteralPath 'scripts\supabase-storage-runtime-test.test.mjs'
  foreach ($negativeCategory in @(
    'bucket_rejected',
    'object_name_rejected',
    'overwrite_rejected',
    'project_url_target_mismatch',
    'branch_rejected',
    'synthetic_confirmation_missing',
    'backend_credential_missing',
    'unsafe_output_rejected'
  )) {
    if ($storageRuntimeTests -notmatch [regex]::Escape($negativeCategory)) {
      $failures.Add("Teste negativo do runtime ausente: $negativeCategory")
    }
  }
}

if (Test-Path -LiteralPath 'scripts\supabase-storage-runtime-run.ps1') {
  $storageWrapper = Get-Content -Raw -LiteralPath 'scripts\supabase-storage-runtime-run.ps1'
  foreach ($requiredWrapperValue in @(
    'PromptForBackendCredential',
    'Read-Host',
    'ZeroFreeBSTR',
    'CBN_SUPABASE_BACKEND_KEY',
    'CBN_STORAGE_RUNTIME_CONFIRMED',
    'BKL-016 Storage runtime validation passed'
  )) {
    if ($storageWrapper -notmatch [regex]::Escape($requiredWrapperValue)) {
      $failures.Add("Gate do wrapper de Storage ausente: $requiredWrapperValue")
    }
  }
}

if (Test-Path -LiteralPath 'supabase\tests\bkl016_remote_validation.sql') {
  $remoteDatabaseTests = Get-Content -Raw -LiteralPath 'supabase\tests\bkl016_remote_validation.sql'
  foreach ($requiredRemoteCheck in @(
    'supabase_migrations.schema_migrations',
    'relrowsecurity',
    'search_path=""',
    'storage.buckets',
    'storage.objects',
    'consultations_operation_owner_product_fk',
    'proposals_operation_owner_product_fk',
    'proposals_final_authorization_evidence_payload_ref_fk',
    'offers_protect_snapshot',
    'audit_events_append_only',
    'BKL-016 remote structural checks passed'
  )) {
    if ($remoteDatabaseTests -notmatch [regex]::Escape($requiredRemoteCheck)) {
      $failures.Add("Teste remoto obrigatorio ausente: $requiredRemoteCheck")
    }
  }
}

if (Test-Path -LiteralPath 'scripts\supabase-remote-validate.ps1') {
  $remoteValidator = Get-Content -Raw -LiteralPath 'scripts\supabase-remote-validate.ps1'
  if ($remoteValidator -notmatch [regex]::Escape('PromptForDatabasePassword')) {
    $failures.Add('Validador remoto nao oferece prompt local protegido para a senha.')
  }
  if ($remoteValidator -notmatch [regex]::Escape('ZeroFreeBSTR')) {
    $failures.Add('Validador remoto nao limpa a senha convertida da memoria nativa.')
  }
}

$grantHardeningPath = 'supabase\migrations\20260716_001_bkl016_revoke_anon_operational_grants.sql'
if (-not (Test-Path -LiteralPath $grantHardeningPath -PathType Leaf)) {
  $failures.Add('Migration corretiva de grants remotos ausente.')
} else {
  $grantHardening = Get-Content -Raw -LiteralPath $grantHardeningPath
  if ($grantHardening -notmatch '(?is)revoke\s+all\s+on\s+public\.user_profiles.*?public\.pending_items\s+from\s+public\s*,\s*anon\s*;') {
    $failures.Add('Migration corretiva nao revoga tabelas operacionais de PUBLIC e anon.')
  }
  if ($grantHardening -notmatch '(?is)revoke\s+all\s+on\s+public\.audit_event_summaries\s+from\s+public\s*,\s*anon\s*;') {
    $failures.Add('Migration corretiva nao protege a view de auditoria contra anon.')
  }
  if ($grantHardening -match '(?i)insert\s+into|update\s+public\.|delete\s+from') {
    $failures.Add('Migration corretiva de grants contem mutacao de dados inesperada.')
  }
}

if ($failures.Count -gt 0) {
  $failures | ForEach-Object { Write-Error $_ }
  exit 1
}

Write-Host 'BKL-016 static checks passed: estrutura, seed sintetico e varredura de segredos/CPF.'
