[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$cbnLocalHome = Join-Path $env:LOCALAPPDATA 'CBN\crm-plugin'
if (-not (Test-Path -LiteralPath (Join-Path $cbnLocalHome 'config.json'))) { throw 'Execute install-local.ps1 primeiro.' }
$cbnSecureToken = Read-Host 'Token pessoal da API do CRM (entrada oculta)' -AsSecureString
$cbnPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($cbnSecureToken)
try {
    $cbnTokenValue = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($cbnPointer)
    if ([string]::IsNullOrWhiteSpace($cbnTokenValue)) { throw 'Token vazio.' }
    [IO.File]::WriteAllText((Join-Path $cbnLocalHome 'crm.token'), $cbnTokenValue.Trim(), [Text.UTF8Encoding]::new($false))
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($cbnPointer)
    $cbnTokenValue = $null
}
Write-Output 'Credencial salva na pasta privada local; nenhum token exibido.'
