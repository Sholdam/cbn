param(
    [Parameter(Mandatory = $true)][string]$ProjectId,
    [Parameter(Mandatory = $true)][string]$Environment,
    [Parameter(Mandatory = $true)][string]$Service,
    [Parameter(Mandatory = $true)][string]$IdentityFile
)

$ErrorActionPreference = 'Stop'
$destination = '\\wsl.localhost\Ubuntu-CBN\srv\cbn-production\backups\pgvector-physical.tar'
$linuxDestination = '/srv/cbn-production/backups/pgvector-physical.tar'
$source = & wsl.exe -d Ubuntu-CBN -u root -- findmnt -n -o SOURCE --target /srv/cbn-production
if ($LASTEXITCODE -ne 0 -or $source.Trim() -ne '/dev/mapper/cbn_production') {
    throw 'Cofre LUKS CBN nao esta montado.'
}
if (-not (Test-Path -LiteralPath $IdentityFile -PathType Leaf)) {
    throw 'Chave SSH local ausente.'
}
if ([System.IO.File]::Exists($destination)) {
    throw 'Copia fisica ja existe; nao sera substituida.'
}

$railwayBinary = Join-Path $env:APPDATA 'npm\node_modules\@railway\cli\bin\railway.exe'
$arguments = @(
    'ssh', '--project', $ProjectId, '--environment', $Environment,
    '--service', $Service, '--identity-file', $IdentityFile, '--',
    'pg_basebackup', '-D', '-', '-Ft', '-X', 'fetch', '-c', 'fast',
    '-h', '127.0.0.1', '-p', '5432', '-U', 'postgres', '-w'
)
$start = [System.Diagnostics.ProcessStartInfo]::new()
$start.FileName = $railwayBinary
$start.UseShellExecute = $false
$start.RedirectStandardOutput = $true
$start.RedirectStandardError = $true
foreach ($argument in $arguments) { [void]$start.ArgumentList.Add($argument) }

$process = [System.Diagnostics.Process]::new()
$process.StartInfo = $start
$file = [System.IO.File]::Open($destination, [System.IO.FileMode]::CreateNew)
try {
    if (-not $process.Start()) { throw 'Nao foi possivel iniciar o pg_basebackup remoto.' }
    $errorTask = $process.StandardError.ReadToEndAsync()
    $process.StandardOutput.BaseStream.CopyTo($file)
    $process.WaitForExit()
    [void]$errorTask.GetAwaiter().GetResult()
    $file.Flush($true)
    if ($process.ExitCode -ne 0 -or $file.Length -lt 1048576) {
        throw "Copia fisica incompleta (codigo $($process.ExitCode))."
    }
    & wsl.exe -d Ubuntu-CBN -u root -- chmod 640 $linuxDestination
    if ($LASTEXITCODE -ne 0) { throw 'Nao foi possivel restringir o backup fisico.' }
    Write-Output ([pscustomobject]@{
        Destination = $linuxDestination
        Bytes = $file.Length
        Transport = 'Railway SSH'
        AtRest = 'LUKS2'
    })
}
finally {
    $file.Dispose()
    $process.Dispose()
}
