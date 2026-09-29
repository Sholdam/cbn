param(
    [Parameter(Mandatory = $true)][string]$ProjectId,
    [Parameter(Mandatory = $true)][string]$Environment,
    [Parameter(Mandatory = $true)][string]$Service,
    [Parameter(Mandatory = $true)][string]$IdentityFile,
    [Parameter(Mandatory = $true)][string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $IdentityFile -PathType Leaf)) {
    throw 'Chave SSH local ausente.'
}
if (-not (Test-Path -LiteralPath $OutputDirectory -PathType Container)) {
    throw 'Diretorio de destino ausente.'
}

$railwayBinary = Join-Path $env:APPDATA 'npm\node_modules\@railway\cli\bin\railway.exe'
if (-not (Test-Path -LiteralPath $railwayBinary -PathType Leaf)) {
    throw 'Railway CLI ausente.'
}

$outputPath = Join-Path $OutputDirectory ("pgvector-{0}.dump.dpapi" -f [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ'))
if (Test-Path -LiteralPath $outputPath) {
    throw 'O arquivo de destino ja existe.'
}

$arguments = @(
    'ssh', '--project', $ProjectId, '--environment', $Environment,
    '--service', $Service, '--identity-file', $IdentityFile, '--',
    'pg_dump', '-h', '127.0.0.1', '-p', '5432', '-Fc', '-Z', '9',
    '--no-owner', '--no-acl'
)

$start = [System.Diagnostics.ProcessStartInfo]::new()
$start.FileName = $railwayBinary
$start.UseShellExecute = $false
$start.RedirectStandardOutput = $true
$start.RedirectStandardError = $true
foreach ($argument in $arguments) {
    [void]$start.ArgumentList.Add($argument)
}

$process = [System.Diagnostics.Process]::new()
$process.StartInfo = $start
$plainStream = [System.IO.MemoryStream]::new()
$plainBytes = $null
$cipherBytes = $null
try {
    if (-not $process.Start()) {
        throw 'Nao foi possivel iniciar o pg_dump remoto.'
    }
    $errorTask = $process.StandardError.ReadToEndAsync()
    $process.StandardOutput.BaseStream.CopyTo($plainStream)
    $process.WaitForExit()
    [void]$errorTask.GetAwaiter().GetResult()
    if ($process.ExitCode -ne 0) {
        throw "pg_dump remoto falhou (codigo $($process.ExitCode))."
    }

    $plainBytes = $plainStream.ToArray()
    if ($plainBytes.Length -lt 5 -or [Text.Encoding]::ASCII.GetString($plainBytes, 0, 5) -ne 'PGDMP') {
        throw 'O fluxo recebido nao e um dump PostgreSQL custom valido.'
    }

    $cipherBytes = [System.Security.Cryptography.ProtectedData]::Protect(
        $plainBytes,
        $null,
        [System.Security.Cryptography.DataProtectionScope]::CurrentUser
    )
    $file = [System.IO.File]::Open($outputPath, [System.IO.FileMode]::CreateNew)
    try {
        $file.Write($cipherBytes, 0, $cipherBytes.Length)
    }
    finally {
        $file.Dispose()
    }

    $readback = [System.IO.File]::ReadAllBytes($outputPath)
    $verified = [System.Security.Cryptography.ProtectedData]::Unprotect(
        $readback,
        $null,
        [System.Security.Cryptography.DataProtectionScope]::CurrentUser
    )
    try {
        if ($verified.Length -ne $plainBytes.Length -or
            [Text.Encoding]::ASCII.GetString($verified, 0, 5) -ne 'PGDMP') {
            throw 'Verificacao local da copia criptografada falhou.'
        }
    }
    finally {
        [Array]::Clear($verified, 0, $verified.Length)
    }

    Write-Output ([pscustomobject]@{
        File = $outputPath
        PlainBytes = $plainBytes.Length
        EncryptedBytes = $cipherBytes.Length
        Protection = 'Windows DPAPI CurrentUser'
    })
}
finally {
    if ($plainBytes) { [Array]::Clear($plainBytes, 0, $plainBytes.Length) }
    if ($cipherBytes) { [Array]::Clear($cipherBytes, 0, $cipherBytes.Length) }
    $plainStream.Dispose()
    $process.Dispose()
}
