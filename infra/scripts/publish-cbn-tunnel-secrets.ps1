param(
    [Parameter(Mandatory)][string]$ProjectId,
    [Parameter(Mandatory)][string]$EnvironmentId,
    [Parameter(Mandatory)][string]$ServiceId
)

$ErrorActionPreference = 'Stop'
$mountedSource = & wsl.exe -d Ubuntu-CBN -u root -- findmnt -n -o SOURCE --target /srv/cbn-production
if ($LASTEXITCODE -ne 0 -or $mountedSource.Trim() -ne '/dev/mapper/cbn_production') {
    throw 'O cofre CBN nao esta montado no dispositivo LUKS esperado.'
}

function Read-WslSecret([string]$FileName) {
    $path = "/srv/cbn-production/secrets/frp/$FileName"
    $start = [System.Diagnostics.ProcessStartInfo]::new()
    $start.FileName = 'wsl.exe'
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in @('-d', 'Ubuntu-CBN', '-u', 'root', '--', 'cat', $path)) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        if (-not $process.Start()) { throw 'WSL nao iniciou.' }
        $buffer = [System.IO.MemoryStream]::new()
        try {
            $process.StandardOutput.BaseStream.CopyTo($buffer)
            $process.WaitForExit()
            if ($process.ExitCode -ne 0) { throw "Segredo local ausente: $FileName" }
            return ,($buffer.ToArray())
        } finally { $buffer.Dispose() }
    } finally { $process.Dispose() }
}

function Set-RailwaySecret([string]$Name, [byte[]]$Value) {
    $railwayExe = Join-Path $env:APPDATA 'npm\node_modules\@railway\cli\bin\railway.exe'
    if (-not (Test-Path -LiteralPath $railwayExe -PathType Leaf)) {
        throw 'Executavel do Railway CLI nao encontrado.'
    }
    $start = [System.Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $railwayExe
    $start.UseShellExecute = $false
    $start.RedirectStandardInput = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in @(
        'variable', 'set', $Name, '--stdin', '--skip-deploys',
        '--project', $ProjectId, '--environment', $EnvironmentId, '--service', $ServiceId
    )) { [void]$start.ArgumentList.Add($argument) }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        if (-not $process.Start()) { throw 'Railway CLI nao iniciou.' }
        $process.StandardInput.BaseStream.Write($Value, 0, $Value.Length)
        $process.StandardInput.Close()
        [void]$process.StandardOutput.ReadToEnd()
        [void]$process.StandardError.ReadToEnd()
        $process.WaitForExit()
        if ($process.ExitCode -ne 0) { throw "Railway recusou a variavel $Name." }
        Write-Output "$Name=registrada"
    } finally { $process.Dispose() }
}

$files = @(
    @{ Name = 'FRP_TOKEN'; File = 'token'; Base64 = $false },
    @{ Name = 'FRP_SERVER_CERT_B64'; File = 'server.crt'; Base64 = $true },
    @{ Name = 'FRP_SERVER_KEY_B64'; File = 'server.key'; Base64 = $true }
)
foreach ($entry in $files) {
    $bytes = Read-WslSecret $entry.File
    try {
        if ($entry.Base64) {
            $encoded = [System.Text.Encoding]::ASCII.GetBytes([Convert]::ToBase64String($bytes))
            try { Set-RailwaySecret $entry.Name $encoded }
            finally { [Array]::Clear($encoded, 0, $encoded.Length) }
        } else {
            Set-RailwaySecret $entry.Name $bytes
        }
    } finally { [Array]::Clear($bytes, 0, $bytes.Length) }
}
