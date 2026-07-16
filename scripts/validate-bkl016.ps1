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
    "@('20260715', '20260716')",
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
  foreach ($requiredPackageValue in @(
    '@supabase/supabase-js', '2.110.6', 'node --test',
    'test:kms-envelope', 'kms-envelope/envelope-service.test.mjs'
  )) {
    if ($storagePackage -notmatch [regex]::Escape($requiredPackageValue)) {
      $failures.Add("Configuracao npm do runtime ausente: $requiredPackageValue")
    }
  }
}

$kmsEnvelopeArtifacts = @(
  'scripts\kms-envelope\kms-adapter.mjs',
  'scripts\kms-envelope\local-test-kms-adapter.mjs',
  'scripts\kms-envelope\envelope-service.mjs',
  'scripts\kms-envelope\envelope-service.test.mjs',
  'supabase\migrations\20260717_001_bkl016_envelope_metadata.sql',
  'supabase\rollback\20260717_001_bkl016_envelope_metadata_down.sql',
  'supabase\tests\bkl016_envelope_constraints_test.sql',
  'supabase\tests\bkl016_envelope_rollback_test.sql',
  'docs\BKL-016_KMS_ENVELOPE_RUNBOOK.md',
  'docs\RELATORIO_BKL-016_KMS_ENVELOPE_LOCAL.md'
)
foreach ($artifact in $kmsEnvelopeArtifacts) {
  if (-not (Test-Path -LiteralPath $artifact -PathType Leaf)) {
    $failures.Add("Artefato de envelope KMS ausente: $artifact")
  }
}

if (Test-Path -LiteralPath 'scripts\kms-envelope\kms-adapter.mjs') {
  $kmsContract = Get-Content -Raw -LiteralPath 'scripts\kms-envelope\kms-adapter.mjs'
  foreach ($method in @('wrapKey', 'unwrapKey', 'getKeyReference', 'rewrapDataKey', 'healthCheck')) {
    if ($kmsContract -notmatch [regex]::Escape($method)) {
      $failures.Add("Metodo obrigatorio do contrato KMS ausente: $method")
    }
  }
}

if (Test-Path -LiteralPath 'scripts\kms-envelope\local-test-kms-adapter.mjs') {
  $localKms = Get-Content -Raw -LiteralPath 'scripts\kms-envelope\local-test-kms-adapter.mjs'
  foreach ($control in @(
    "environment !== 'test'", 'allowLocalTestKms !== true',
    'randomBytes(KEY_BYTES)', 'local-test-only', 'destroy()'
  )) {
    if ($localKms -notmatch [regex]::Escape($control)) {
      $failures.Add("Controle obrigatorio do KMS local ausente: $control")
    }
  }
  if ($localKms -match '(?i)@aws-sdk|@google-cloud|@azure|node-vault|fetch\s*\(') {
    $failures.Add('Adaptador local contem SDK ou chamada para provedor externo.')
  }
}

if (Test-Path -LiteralPath 'scripts\kms-envelope\envelope-service.mjs') {
  $envelopeService = Get-Content -Raw -LiteralPath 'scripts\kms-envelope\envelope-service.mjs'
  foreach ($control in @(
    "CONTENT_ALGORITHM = 'AES-256-GCM'", 'randomBytes(KEY_BYTES)',
    'randomBytes(NONCE_BYTES)', 'createCipheriv', 'createDecipheriv',
    'setAAD', 'setAuthTag', 'aadSha256', 'rotateKek', 'rotateDek',
    "fill(0)"
  )) {
    if ($envelopeService -notmatch [regex]::Escape($control)) {
      $failures.Add("Controle criptografico de envelope ausente: $control")
    }
  }
  if ($envelopeService -match '(?i)console\.(?:log|debug|info)|@aws-sdk|@google-cloud|@azure|node-vault') {
    $failures.Add('Servico de envelope contem log direto ou SDK de provedor externo.')
  }
}

if (Test-Path -LiteralPath 'scripts\kms-envelope\envelope-service.test.mjs') {
  $envelopeTests = Get-Content -Raw -LiteralPath 'scripts\kms-envelope\envelope-service.test.mjs'
  foreach ($requiredTest in @(
    'round-trip positivo', 'plaintext vazio', 'DEK, nonce e ciphertext diferentes',
    'cliente, operacao e proposta divergentes', 'bucket e object name',
    'tag, ciphertext, nonce e wrapped DEK adulterados', 'key version incorreta',
    'rotacao de KEK', 'rotacao de DEK', 'falha de rotacao',
    'local falha fechado fora do ambiente de teste',
    'nao expõem plaintext ou material criptografico completo'
  )) {
    if ($envelopeTests -notmatch [regex]::Escape($requiredTest)) {
      $failures.Add("Teste de envelope obrigatorio ausente: $requiredTest")
    }
  }
}

$syntheticPlaintextMarker = 'BKL016_SYNTHETIC_ENVELOPE_PAYLOAD'
foreach ($relativePath in $files) {
  if ($relativePath -in @(
    'scripts/kms-envelope/envelope-service.test.mjs',
    'scripts/validate-bkl016.ps1'
  )) { continue }
  $path = Join-Path $repoRoot $relativePath
  if ((Test-Path -LiteralPath $path -PathType Leaf) -and
      (Get-Content -Raw -LiteralPath $path) -match [regex]::Escape($syntheticPlaintextMarker)) {
    $failures.Add("Plaintext sintetico escapou do teste controlado: $relativePath")
  }
}

$envelopeMigrationPath = 'supabase\migrations\20260717_001_bkl016_envelope_metadata.sql'
if (Test-Path -LiteralPath $envelopeMigrationPath) {
  $envelopeMigration = Get-Content -Raw -LiteralPath $envelopeMigrationPath
  foreach ($requiredMetadata in @(
    'envelope_algorithm', 'envelope_version', 'wrapped_dek', 'content_nonce',
    'authentication_tag', 'aad_version', 'aad_sha256',
    "envelope_algorithm = 'AES-256-GCM'", 'octet_length(content_nonce) = 12',
    'octet_length(authentication_tag) = 16',
    'num_nonnulls(',
    'protected_payloads_envelope_coherence_ck',
    'protected_file_refs_envelope_coherence_ck'
  )) {
    if ($envelopeMigration -notmatch [regex]::Escape($requiredMetadata)) {
      $failures.Add("Metadado/constraint de envelope ausente: $requiredMetadata")
    }
  }
}

$envelopeRollbackPath = 'supabase\rollback\20260717_001_bkl016_envelope_metadata_down.sql'
if (Test-Path -LiteralPath $envelopeRollbackPath) {
  $envelopeRollback = Get-Content -Raw -LiteralPath $envelopeRollbackPath
  foreach ($rollbackControl in @(
    'Rollback de envelope recusado: existem envelopes novos',
    'where envelope_version is not null', 'drop column if exists wrapped_dek'
  )) {
    if ($envelopeRollback -notmatch [regex]::Escape($rollbackControl)) {
      $failures.Add("Controle de rollback do envelope ausente: $rollbackControl")
    }
  }
}

if (Test-Path -LiteralPath 'supabase\tests\bkl016_envelope_constraints_test.sql') {
  $envelopeDatabaseTests = Get-Content -Raw -LiteralPath 'supabase\tests\bkl016_envelope_constraints_test.sql'
  foreach ($databaseControl in @(
    'SYNTHETIC_LEGACY', 'SYNTHETIC_ENVELOPE', 'AES-128-CBC',
    'SYNTHETIC_NULL_ALGORITHM',
    "repeat('bb', 11)", "repeat('cc', 15)", 'SYNTHETIC_PARTIAL',
    'referencia de chave vazia foi aceita',
    'BKL-016 envelope database constraints passed', 'rollback;'
  )) {
    if ($envelopeDatabaseTests -notmatch [regex]::Escape($databaseControl)) {
      $failures.Add("Teste SQL de envelope ausente: $databaseControl")
    }
  }
}

if (Test-Path -LiteralPath 'supabase\tests\bkl016_envelope_rollback_test.sql') {
  $envelopeRollbackTests = Get-Content -Raw -LiteralPath 'supabase\tests\bkl016_envelope_rollback_test.sql'
  if ($envelopeRollbackTests -notmatch [regex]::Escape('BKL-016 envelope rollback checks passed')) {
    $failures.Add('Marcador do teste SQL de rollback do envelope ausente.')
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

$backupRuntimePath = 'scripts\backup-restore\backup-restore-runtime.mjs'
$backupRecoveryPath = 'scripts\backup-restore\backup-recovery.mjs'
$backupRecoveryTestsPath = 'scripts\backup-restore\backup-recovery.test.mjs'

foreach ($backupPath in @($backupRuntimePath, $backupRecoveryPath, $backupRecoveryTestsPath)) {
  if (-not (Test-Path -LiteralPath $backupPath -PathType Leaf)) {
    $failures.Add("Artefato de backup/restauracao ausente: $backupPath")
  }
}

if (Test-Path -LiteralPath $backupRuntimePath) {
  $backupRuntime = Get-Content -Raw -LiteralPath $backupRuntimePath
  foreach ($requiredBackupControl in @(
    'codex/bkl-016-backup-restore',
    'synthetic-local-only',
    'supabase_admin',
    "'stop', '--no-backup'",
    'BKL-016 synthetic schema backup passed',
    'BKL-016 synthetic data restore passed',
    'BKL-016 synthetic Storage restore passed',
    'BKL-016 envelope recovery passed',
    'BKL-016 missing KEK version failed closed',
    'BKL-016 tamper detection passed',
    'BKL-016 safe rollback refusal passed',
    'BKL-016 backup and restore runtime passed'
  )) {
    if ($backupRuntime -notmatch [regex]::Escape($requiredBackupControl)) {
      $failures.Add("Controle de backup/restauracao ausente: $requiredBackupControl")
    }
  }
  if ($backupRuntime -match '(?i)--linked|supabase\s+link|db\s+push') {
    $failures.Add('Runtime de backup/restauracao contem comando remoto proibido.')
  }
}

if (Test-Path -LiteralPath $backupRecoveryTestsPath) {
  $backupRecoveryTests = Get-Content -Raw -LiteralPath $backupRecoveryTestsPath
  foreach ($requiredRecoveryTest in @(
    'key_version_unavailable',
    'envelope_authentication_failed',
    'backup_artifact_sensitive_content',
    'artefato temporario e removido integralmente'
  )) {
    if ($backupRecoveryTests -notmatch [regex]::Escape($requiredRecoveryTest)) {
      $failures.Add("Teste de recuperacao ausente: $requiredRecoveryTest")
    }
  }
}

$retentionArtifacts = @(
  'docs\PROMPT_CODEX_BKL-016_RETENTION_LEGAL_HOLD.md',
  'docs\BKL-016_RETENTION_LEGAL_HOLD_RUNBOOK.md',
  'docs\RELATORIO_BKL-016_RETENTION_LEGAL_HOLD_LOCAL.md',
  'scripts\retention\retention-runtime.mjs',
  'scripts\retention\retention-runtime.test.mjs',
  'supabase\migrations\20260718_001_bkl016_retention_legal_hold.sql',
  'supabase\rollback\20260718_001_bkl016_retention_legal_hold_down.sql',
  'supabase\tests\bkl016_retention_legal_hold_test.sql',
  'supabase\tests\bkl016_retention_rollback_test.sql'
)
foreach ($artifact in $retentionArtifacts) {
  if (-not (Test-Path -LiteralPath $artifact -PathType Leaf)) {
    $failures.Add("Artefato de retencao/legal hold ausente: $artifact")
  }
}

$retentionMigrationPath = 'supabase\migrations\20260718_001_bkl016_retention_legal_hold.sql'
if (Test-Path -LiteralPath $retentionMigrationPath) {
  $retentionMigration = Get-Content -Raw -LiteralPath $retentionMigrationPath
  foreach ($control in @(
    'app_private.retention_policies', 'app_private.retention_controls',
    'legal_hold_active', 'deletion_eligible_at', 'anonymized_at', 'deleted_at',
    'evaluate_retention_action', 'anonymize_clients', 'prepare_retention_deletion',
    'complete_retention_deletion', 'synthetic-local-explicit-ids',
    'LEGAL_HOLD_APPLIED', 'ANONYMIZATION_COMPLETED',
    'STORAGE_DELETION_COMPLETED', 'security definer', "set search_path = ''",
    'revoke all on app_private.retention_policies'
  )) {
    if ($retentionMigration -notmatch [regex]::Escape($control)) {
      $failures.Add("Controle de retencao/legal hold ausente: $control")
    }
  }
  if ($retentionMigration -match '(?i)retention_period\s+interval\s+not\s+null\s+default|interval\s+''(?:5|10|20)\s+years''') {
    $failures.Add('Migration de retencao contem prazo juridico definitivo hardcoded.')
  }
  if ($retentionMigration -match '(?im)^\s*grant\s+.*app_private\.retention_.*\bto\s+(?:anon|authenticated)\b') {
    $failures.Add('Estrutura privada de retencao foi concedida ao frontend.')
  }
}

$retentionRollbackPath = 'supabase\rollback\20260718_001_bkl016_retention_legal_hold_down.sql'
if (Test-Path -LiteralPath $retentionRollbackPath) {
  $retentionRollback = Get-Content -Raw -LiteralPath $retentionRollbackPath
  foreach ($control in @(
    'Rollback de retencao recusado: existe estado indispensavel',
    'app_private.retention_policies', 'app_private.retention_controls',
    'LEGAL_HOLD_APPLIED', 'DELETION_COMPLETED'
  )) {
    if ($retentionRollback -notmatch [regex]::Escape($control)) {
      $failures.Add("Controle fail-closed do rollback de retencao ausente: $control")
    }
  }
}

if (Test-Path -LiteralPath 'scripts\retention\retention-runtime.mjs') {
  $retentionRuntime = Get-Content -Raw -LiteralPath 'scripts\retention\retention-runtime.mjs'
  foreach ($control in @(
    'codex/bkl-016-retention-legal-hold',
    'CBN_RETENTION_DELETE_CONFIRMED',
    'synthetic-local-explicit-ids', 'preexisting_local_stack_rejected',
    'protected_path_modified', 'non_local_target_rejected',
    'post_anonymization_restore_revived_data',
    'legal_hold_did_not_block_storage_deletion',
    'storage_failure_marked_complete', 'storage_absence_not_proven',
    "'stop', '--no-backup'"
  )) {
    if ($retentionRuntime -notmatch [regex]::Escape($control)) {
      $failures.Add("Gate do runtime de retencao ausente: $control")
    }
  }
  if ($retentionRuntime -match '(?i)supabase\s+link|db\s+push|\.supabase\.co') {
    $failures.Add('Runtime de retencao contem alvo ou comando remoto proibido.')
  }
}

if ($failures.Count -gt 0) {
  $failures | ForEach-Object { Write-Error $_ }
  exit 1
}

Write-Host 'BKL-016 static checks passed: estrutura, seed sintetico e varredura de segredos/CPF.'
