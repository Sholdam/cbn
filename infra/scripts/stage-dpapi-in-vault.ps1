param(
    [Parameter(Mandatory = $true)][string]$InputPath,
    [Parameter(Mandatory = $true)][string]$LinuxDestination
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $InputPath -PathType Leaf)) {
    throw 'Arquivo DPAPI de entrada ausente.'
}
if (-not $LinuxDestination.StartsWith('/srv/cbn-production/', [StringComparison]::Ordinal)) {
    throw 'Destino fora do cofre CBN.'
}

$source = & wsl.exe -d Ubuntu-CBN -u root -- findmnt -n -o SOURCE --target /srv/cbn-production
if ($LASTEXITCODE -ne 0 -or $source.Trim() -ne '/dev/mapper/cbn_production') {
    throw 'Cofre LUKS CBN nao esta montado no WSL.'
}

$windowsDestination = '\\wsl.localhost\Ubuntu-CBN' + $LinuxDestination.Replace('/', '\')
$directory = [System.IO.Path]::GetDirectoryName($windowsDestination)
[void][System.IO.Directory]::CreateDirectory($directory)
if ([System.IO.File]::Exists($windowsDestination)) {
    throw 'Arquivo ja existe no cofre; nao sera sobrescrito.'
}

$cipherBytes = [System.IO.File]::ReadAllBytes($InputPath)
$plainBytes = [System.Security.Cryptography.ProtectedData]::Unprotect(
    $cipherBytes, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser
)
try {
    $file = [System.IO.File]::Open($windowsDestination, [System.IO.FileMode]::CreateNew)
    try { $file.Write($plainBytes, 0, $plainBytes.Length) }
    finally { $file.Dispose() }
    $readback = [System.IO.File]::ReadAllBytes($windowsDestination)
    try {
        $sourceHash = [System.Security.Cryptography.SHA256]::HashData($plainBytes)
        $readbackHash = [System.Security.Cryptography.SHA256]::HashData($readback)
        if (-not [System.Security.Cryptography.CryptographicOperations]::FixedTimeEquals($sourceHash, $readbackHash)) {
            throw 'Hash da copia no cofre diverge.'
        }
    }
    finally { [Array]::Clear($readback, 0, $readback.Length) }
    & wsl.exe -d Ubuntu-CBN -u root -- chmod 600 $LinuxDestination
    if ($LASTEXITCODE -ne 0) { throw 'Nao foi possivel restringir o arquivo no cofre.' }
    Write-Output ([pscustomobject]@{
        Destination = $LinuxDestination
        Bytes = $plainBytes.Length
        Verified = $true
    })
}
finally {
    [Array]::Clear($plainBytes, 0, $plainBytes.Length)
    [Array]::Clear($cipherBytes, 0, $cipherBytes.Length)
}
