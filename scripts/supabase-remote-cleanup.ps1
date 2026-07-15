[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$ManifestPath,
  [string]$ProjectRef = $env:SUPABASE_PROJECT_REF,
  [switch]$RemoteTargetConfirmed,
  [switch]$SyntheticDataConfirmed,
  [switch]$MigrationDryRunReviewed,
  [switch]$CleanupApproved,
  [string[]]$ProductionProjectRefs = @(),
  [string]$DatabaseUrlVariable = 'CBN_REMOTE_DATABASE_URL'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

$preflightPath = Join-Path $PSScriptRoot 'supabase-remote-preflight.ps1'
& $preflightPath `
  -ProjectRef $ProjectRef `
  -Phase Cleanup `
  -RemoteTargetConfirmed:$RemoteTargetConfirmed `
  -SyntheticDataConfirmed:$SyntheticDataConfirmed `
  -MigrationDryRunReviewed:$MigrationDryRunReviewed `
  -ProductionProjectRefs $ProductionProjectRefs
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

if (-not $CleanupApproved) {
  Write-Error 'A limpeza remota exige confirmacao separada por -CleanupApproved.'
  exit 1
}

$manifestFullPath = [IO.Path]::GetFullPath((Join-Path $repoRoot $ManifestPath))
$tempRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot 'supabase\.temp'))
if (-not $manifestFullPath.StartsWith($tempRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
  Write-Error 'O manifesto deve ficar somente em supabase/.temp, que e ignorado pelo Git.'
  exit 1
}
if (-not (Test-Path -LiteralPath $manifestFullPath -PathType Leaf)) {
  Write-Error 'Manifesto de limpeza sintetica nao encontrado.'
  exit 1
}

$manifestRelativePath = $manifestFullPath.Substring($repoRoot.Length).TrimStart('\', '/') -replace '\\', '/'
& git check-ignore --quiet -- $manifestRelativePath
if ($LASTEXITCODE -ne 0) {
  Write-Error 'O manifesto de limpeza nao esta protegido por regra de ignore.'
  exit 1
}

try {
  $manifest = Get-Content -Raw -LiteralPath $manifestFullPath | ConvertFrom-Json
} catch {
  Write-Error 'O manifesto de limpeza nao e JSON valido.'
  exit 1
}

if ($manifest.marker -cne 'BKL016_SYNTHETIC_REMOTE_DEV') {
  Write-Error 'O manifesto nao possui o marcador sintetico obrigatorio.'
  exit 1
}
if (($manifest.projectRef -as [string]) -cne $ProjectRef) {
  Write-Error 'O manifesto nao pertence ao alvo remoto confirmado; valores omitidos.'
  exit 1
}

function Get-ValidatedUuidList {
  param([object]$Value, [string]$Label)
  $result = [System.Collections.Generic.List[string]]::new()
  foreach ($item in @($Value)) {
    $text = $item -as [string]
    if ([string]::IsNullOrWhiteSpace($text)) { continue }
    if ($text -cnotmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$') {
      Write-Error "ID invalido no grupo $Label; valor omitido."
      exit 1
    }
    if (-not $result.Contains($text)) { $result.Add($text) }
  }
  return @($result)
}

function ConvertTo-SqlUuidArray {
  param([string[]]$Values)
  if (@($Values).Count -eq 0) { return 'array[]::uuid[]' }
  return "array['$($Values -join "','")']::uuid[]"
}

$ids = @{
  AuthUsers = Get-ValidatedUuidList $manifest.authUserIds 'authUserIds'
  Clients = Get-ValidatedUuidList $manifest.clientIds 'clientIds'
  Operations = Get-ValidatedUuidList $manifest.operationIds 'operationIds'
  Consultations = Get-ValidatedUuidList $manifest.consultationIds 'consultationIds'
  Offers = Get-ValidatedUuidList $manifest.offerIds 'offerIds'
  Proposals = Get-ValidatedUuidList $manifest.proposalIds 'proposalIds'
  Interactions = Get-ValidatedUuidList $manifest.interactionIds 'interactionIds'
  PendingItems = Get-ValidatedUuidList $manifest.pendingItemIds 'pendingItemIds'
  ProtectedPayloads = Get-ValidatedUuidList $manifest.protectedPayloadIds 'protectedPayloadIds'
  ProtectedFileRefs = Get-ValidatedUuidList $manifest.protectedFileRefIds 'protectedFileRefIds'
}

$allowedBuckets = @(
  'cbn-documents-private', 'cbn-raw-payloads-private',
  'cbn-evidence-private', 'cbn-temporary-private'
)
$storageObjects = [System.Collections.Generic.List[object]]::new()
foreach ($item in @($manifest.storageObjects)) {
  if ($null -eq $item) { continue }
  $bucket = $item.bucketId -as [string]
  $name = $item.objectName -as [string]
  if ($bucket -cnotin $allowedBuckets -or
      $name -cnotmatch '^[a-f0-9-]{16,200}(?:/[a-f0-9-]{16,200})*$' -or
      $name -match '[0-9]{11}') {
    Write-Error 'Objeto de Storage fora do allowlist UUID/hash; valor omitido.'
    exit 1
  }
  $storageObjects.Add([pscustomobject]@{ Bucket = $bucket; Name = $name })
}

$targetCount = $storageObjects.Count
foreach ($group in $ids.Values) { $targetCount += @($group).Count }
if ($targetCount -eq 0) {
  Write-Error 'O manifesto nao contem nenhum alvo sintetico explicito.'
  exit 1
}

if ($DatabaseUrlVariable -cnotmatch '^[A-Z][A-Z0-9_]{2,80}$') {
  Write-Error 'O nome da variavel local de conexao nao e valido.'
  exit 1
}
$databaseUrl = [Environment]::GetEnvironmentVariable($DatabaseUrlVariable, 'Process')
if ([string]::IsNullOrWhiteSpace($databaseUrl)) {
  Write-Error "Defina a conexao remota somente na variavel local $DatabaseUrlVariable."
  exit 1
}

try {
  $uri = [Uri]$databaseUrl
  if ($uri.Scheme -notin @('postgres', 'postgresql')) { throw 'scheme' }
  $separator = $uri.UserInfo.IndexOf(':')
  if ($separator -lt 1 -or [string]::IsNullOrWhiteSpace($uri.Host)) { throw 'userinfo' }
  $pgUser = [Uri]::UnescapeDataString($uri.UserInfo.Substring(0, $separator))
  $pgPassword = [Uri]::UnescapeDataString($uri.UserInfo.Substring($separator + 1))
  $pgDatabase = [Uri]::UnescapeDataString($uri.AbsolutePath.TrimStart('/'))
  if ([string]::IsNullOrWhiteSpace($pgDatabase)) { $pgDatabase = 'postgres' }
  $pgPort = if ($uri.IsDefaultPort) { '5432' } else { $uri.Port.ToString() }
} catch {
  Write-Error 'A URL de conexao local nao possui formato PostgreSQL valido; o valor foi omitido.'
  exit 1
}

$storageDeleteSql = '  null;'
if ($storageObjects.Count -gt 0) {
  $storageValues = @($storageObjects | ForEach-Object { "('$($_.Bucket)', '$($_.Name)')" }) -join ",`n    "
  $storageDeleteSql = @"
  perform set_config('storage.allow_delete_query', 'true', true);
  delete from storage.objects o
  using (values
    $storageValues
  ) as target(bucket_id, object_name)
  where o.bucket_id = target.bucket_id and o.name = target.object_name;
  perform set_config('storage.allow_delete_query', 'false', true);
"@
}

$authUsers = ConvertTo-SqlUuidArray $ids.AuthUsers
$clients = ConvertTo-SqlUuidArray $ids.Clients
$operations = ConvertTo-SqlUuidArray $ids.Operations
$consultations = ConvertTo-SqlUuidArray $ids.Consultations
$offers = ConvertTo-SqlUuidArray $ids.Offers
$proposals = ConvertTo-SqlUuidArray $ids.Proposals
$interactions = ConvertTo-SqlUuidArray $ids.Interactions
$pendingItems = ConvertTo-SqlUuidArray $ids.PendingItems
$protectedPayloads = ConvertTo-SqlUuidArray $ids.ProtectedPayloads
$protectedFileRefs = ConvertTo-SqlUuidArray $ids.ProtectedFileRefs

$cleanupSql = @"
begin;

do `$`$
begin
  if exists (
    select 1 from public.clients
    where id = any($clients)
      and coalesce(display_name, '') not like '[SYNTHETIC REMOTE BKL-016]%'
  ) then raise exception 'Cliente fora do marcador sintetico'; end if;

  if exists (
    select 1 from auth.users
    where id = any($authUsers)
      and (email is null or email !~* '@example\.invalid`$')
  ) then raise exception 'Usuario Auth fora do marcador sintetico'; end if;

  if exists (
    select 1 from public.technical_operations
    where operation_id = any($operations)
      and (coalesce(session_alias, '') not like 'synthetic-bkl016-remote-%'
           or protected_log_ref is not null)
  ) then raise exception 'Operacao fora do marcador sintetico ou com ciclo protegido'; end if;

  if exists (
    select 1 from app_private.protected_payloads
    where id = any($protectedPayloads)
      and (coalesce(encryption_key_ref, '') not like 'synthetic-%' or proposal_id is not null)
  ) then raise exception 'Payload fora do marcador sintetico ou com ciclo de proposta'; end if;

  if exists (
    select 1 from public.consultations
    where id = any($consultations)
      and (coalesce(session_alias, '') not like 'synthetic-bkl016-remote-%'
           or coalesce(status_raw, '') not like 'SYNTHETIC_%')
  ) then raise exception 'Consulta fora do marcador sintetico'; end if;

  if exists (
    select 1 from public.offers
    where id = any($offers)
      and (coalesce(lender_code, '') <> 'SYNTHETIC_BANK'
           or coalesce(lender_name, '') not like '[SYNTHETIC REMOTE BKL-016]%')
  ) then raise exception 'Oferta fora do marcador sintetico'; end if;

  if exists (
    select 1 from public.proposals
    where id = any($proposals)
      and coalesce(status_raw, '') not like 'SYNTHETIC_%'
  ) then raise exception 'Proposta fora do marcador sintetico'; end if;

  if exists (
    select 1 from public.interactions
    where id = any($interactions)
      and (coalesce(channel, '') <> 'INTERNAL_TEST'
           or coalesce(event_type, '') not like 'SYNTHETIC_%')
  ) then raise exception 'Interacao fora do marcador sintetico'; end if;

  if exists (
    select 1 from public.pending_items
    where id = any($pendingItems)
      and coalesce(pending_type, '') not like 'SYNTHETIC_%'
  ) then raise exception 'Pendencia fora do marcador sintetico'; end if;

  if exists (
    select 1 from app_private.protected_file_refs
    where id = any($protectedFileRefs)
      and coalesce(encryption_key_ref, '') not like 'synthetic-%'
  ) then raise exception 'Referencia de arquivo fora do marcador sintetico'; end if;
end
`$`$;

do `$`$
begin
$storageDeleteSql
end
`$`$;

delete from app_private.protected_file_refs where id = any($protectedFileRefs);
delete from app_private.proposal_sensitive_data where proposal_id = any($proposals);
delete from public.pending_items where id = any($pendingItems);
delete from public.interactions where id = any($interactions);
delete from public.proposals where id = any($proposals);
delete from public.offers where id = any($offers);
delete from public.consultations where id = any($consultations);
delete from app_private.protected_payloads where id = any($protectedPayloads);
delete from public.technical_operations where operation_id = any($operations);
delete from app_private.client_sensitive_data where client_id = any($clients);
delete from public.clients where id = any($clients);
delete from public.user_profiles where user_id = any($authUsers);
delete from auth.users where id = any($authUsers);

commit;
select 'BKL-016 synthetic remote cleanup passed' as result;
"@

$generatedSqlPath = Join-Path $tempRoot 'bkl016-remote-cleanup.generated.sql'
$savedPgEnvironment = @{}
foreach ($name in @('PGHOST', 'PGPORT', 'PGDATABASE', 'PGUSER', 'PGPASSWORD', 'PGSSLMODE')) {
  $savedPgEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}

try {
  if (-not (Test-Path -LiteralPath $tempRoot -PathType Container)) {
    New-Item -ItemType Directory -Path $tempRoot | Out-Null
  }
  [IO.File]::WriteAllText($generatedSqlPath, $cleanupSql, [Text.UTF8Encoding]::new($false))

  [Environment]::SetEnvironmentVariable('PGHOST', $uri.Host, 'Process')
  [Environment]::SetEnvironmentVariable('PGPORT', $pgPort, 'Process')
  [Environment]::SetEnvironmentVariable('PGDATABASE', $pgDatabase, 'Process')
  [Environment]::SetEnvironmentVariable('PGUSER', $pgUser, 'Process')
  [Environment]::SetEnvironmentVariable('PGPASSWORD', $pgPassword, 'Process')
  [Environment]::SetEnvironmentVariable('PGSSLMODE', 'require', 'Process')

  $output = (& psql -X -v ON_ERROR_STOP=1 -f $generatedSqlPath 2>&1 | Out-String)
  if ($LASTEXITCODE -ne 0 -or
      $output -notmatch 'BKL-016 synthetic remote cleanup passed') {
    Write-Error 'A limpeza sintetica falhou; a saida detalhada foi omitida.'
    exit 1
  }
} finally {
  if (Test-Path -LiteralPath $generatedSqlPath -PathType Leaf) {
    Remove-Item -LiteralPath $generatedSqlPath -Force
  }
  foreach ($name in $savedPgEnvironment.Keys) {
    [Environment]::SetEnvironmentVariable($name, $savedPgEnvironment[$name], 'Process')
  }
  $cleanupSql = $null
  $databaseUrl = $null
  $pgPassword = $null
}

Write-Host 'BKL-016 synthetic remote cleanup passed; identifiers omitted.'
Write-Host 'Execute novamente scripts/supabase-remote-validate.ps1 para comprovar o estado final.'
