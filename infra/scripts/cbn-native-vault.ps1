param(
    [ValidateSet('init', 'mount')][string]$Mode = 'mount'
)

$ErrorActionPreference = 'Stop'
$keyDirectory = Join-Path $env:USERPROFILE '.cbn'
$protectedKeyPath = Join-Path $keyDirectory 'vault-native.key.dpapi'

if ($Mode -eq 'init') {
    if (Test-Path -LiteralPath $protectedKeyPath) {
        throw 'A chave nativa do cofre CBN ja existe; init recusado.'
    }
    [void][System.IO.Directory]::CreateDirectory($keyDirectory)
    $keyBytes = [byte[]]::new(64)
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($keyBytes)
    $protectedBytes = [System.Security.Cryptography.ProtectedData]::Protect(
        $keyBytes, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser
    )
    [System.IO.File]::WriteAllBytes($protectedKeyPath, $protectedBytes)
    [Array]::Clear($protectedBytes, 0, $protectedBytes.Length)
} else {
    if (-not (Test-Path -LiteralPath $protectedKeyPath -PathType Leaf)) {
        throw 'Chave nativa protegida do cofre CBN ausente.'
    }
    $protectedBytes = [System.IO.File]::ReadAllBytes($protectedKeyPath)
    $keyBytes = [System.Security.Cryptography.ProtectedData]::Unprotect(
        $protectedBytes, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser
    )
    [Array]::Clear($protectedBytes, 0, $protectedBytes.Length)
}

$scriptPath = '/mnt/c/Users/GUILHERME/OneDrive/Documentos/ChatGPT/CBN/cbn-infrastructure-migration/infra/scripts/cbn-native-vault.sh'
$start = [System.Diagnostics.ProcessStartInfo]::new()
$start.FileName = 'wsl.exe'
$start.UseShellExecute = $false
$start.RedirectStandardInput = $true
$start.RedirectStandardOutput = $true
$start.RedirectStandardError = $true
foreach ($argument in @('-d', 'Ubuntu-CBN', '-u', 'root', '--', 'bash', $scriptPath, $Mode)) {
    [void]$start.ArgumentList.Add($argument)
}

$process = [System.Diagnostics.Process]::new()
$process.StartInfo = $start
try {
    if (-not $process.Start()) { throw 'Nao foi possivel iniciar o WSL.' }
    $process.StandardInput.BaseStream.Write($keyBytes, 0, $keyBytes.Length)
    $process.StandardInput.Close()
    $output = $process.StandardOutput.ReadToEnd()
    $errorOutput = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) {
        throw "Falha ao preparar o cofre nativo CBN: $errorOutput"
    }
    Write-Output $output.Trim()
} finally {
    [Array]::Clear($keyBytes, 0, $keyBytes.Length)
    $process.Dispose()
}
