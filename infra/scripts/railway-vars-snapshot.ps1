param(
    [Parameter(Mandatory = $true)][string]$ProjectId,
    [Parameter(Mandatory = $true)][string]$Environment,
    [Parameter(Mandatory = $true)][string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
$railwayBinary = Join-Path $env:APPDATA 'npm\node_modules\@railway\cli\bin\railway.exe'
if (-not (Test-Path -LiteralPath $railwayBinary -PathType Leaf)) {
    throw 'Railway CLI ausente.'
}
if (-not (Test-Path -LiteralPath $OutputDirectory -PathType Container)) {
    throw 'Diretorio de destino ausente.'
}

$services = @(
    'PgVector', 'Redis', 'Chatwoot', 'SideKiq',
    'Chatwoot-CBN-v2', 'SideKiq-CBN-v2', 'n8n-cbn-bot',
    'telegram-gateway-clt', 'cbn'
)
$snapshot = [ordered]@{
    capturedAtUtc = [DateTime]::UtcNow.ToString('o')
    projectId = $ProjectId
    environment = $Environment
    services = [ordered]@{}
}
$summary = @()

foreach ($service in $services) {
    $start = [System.Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $railwayBinary
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in @(
        'variable', 'list', '--project', $ProjectId,
        '--environment', $Environment, '--service', $service, '--json'
    )) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        if (-not $process.Start()) { throw "Falha ao ler variaveis de $service." }
        $errorTask = $process.StandardError.ReadToEndAsync()
        $json = $process.StandardOutput.ReadToEnd()
        $process.WaitForExit()
        [void]$errorTask.GetAwaiter().GetResult()
        if ($process.ExitCode -ne 0) { throw "Falha ao ler variaveis de $service." }
        $variables = ConvertFrom-Json -InputObject $json -AsHashtable
        if ($variables -isnot [System.Collections.IDictionary]) {
            throw "Formato inesperado de variaveis em $service."
        }
        $snapshot.services[$service] = $variables
        $summary += [pscustomobject]@{
            Service = $service
            Variables = $variables.Count
            Sealed = @($variables.Values | Where-Object { $null -eq $_ }).Count
        }
    }
    finally {
        $process.Dispose()
    }
}

$outputPath = Join-Path $OutputDirectory ("railway-vars-{0}.json.dpapi" -f [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ'))
$plainBytes = [Text.Encoding]::UTF8.GetBytes(($snapshot | ConvertTo-Json -Depth 8 -Compress))
$cipherBytes = $null
try {
    $cipherBytes = [System.Security.Cryptography.ProtectedData]::Protect(
        $plainBytes, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser
    )
    $file = [System.IO.File]::Open($outputPath, [System.IO.FileMode]::CreateNew)
    try { $file.Write($cipherBytes, 0, $cipherBytes.Length) }
    finally { $file.Dispose() }
    $readback = [System.IO.File]::ReadAllBytes($outputPath)
    $verified = [System.Security.Cryptography.ProtectedData]::Unprotect(
        $readback, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser
    )
    try {
        if ($verified.Length -ne $plainBytes.Length) {
            throw 'Verificacao da copia criptografada falhou.'
        }
    }
    finally { [Array]::Clear($verified, 0, $verified.Length) }
}
finally {
    [Array]::Clear($plainBytes, 0, $plainBytes.Length)
    if ($cipherBytes) { [Array]::Clear($cipherBytes, 0, $cipherBytes.Length) }
}

Write-Output $summary
Write-Output ([pscustomobject]@{
    File = $outputPath
    Protection = 'Windows DPAPI CurrentUser'
})
