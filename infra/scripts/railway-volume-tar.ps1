param(
    [Parameter(Mandatory = $true)][string]$ProjectId,
    [Parameter(Mandatory = $true)][string]$Environment,
    [Parameter(Mandatory = $true)][string]$Service,
    [Parameter(Mandatory = $true)][string]$IdentityFile,
    [Parameter(Mandatory = $true)][string]$RemoteDirectory,
    [Parameter(Mandatory = $true)][string]$ArchiveName
)

$ErrorActionPreference = 'Stop'
if ($ArchiveName -notmatch '^[a-z0-9][a-z0-9-]*\.tar\.gz$') {
    throw 'Nome de arquivo invalido.'
}
if ($RemoteDirectory -notin @('/home/node/.n8n', '/app/storage', '/data')) {
    throw 'Diretorio remoto fora da lista de volumes CBN.'
}
$source = & wsl.exe -d Ubuntu-CBN -u root -- findmnt -n -o SOURCE --target /srv/cbn-production
if ($LASTEXITCODE -ne 0 -or $source.Trim() -ne '/dev/mapper/cbn_production') {
    throw 'Cofre LUKS CBN nao esta montado.'
}
if (-not (Test-Path -LiteralPath $IdentityFile -PathType Leaf)) {
    throw 'Chave SSH local ausente.'
}
$linuxDestination = "/srv/cbn-production/backups/$ArchiveName"
$windowsDestination = "\\wsl.localhost\Ubuntu-CBN\srv\cbn-production\backups\$ArchiveName"
if ([System.IO.File]::Exists($windowsDestination)) {
    throw 'Arquivo ja existe; nao sera substituido.'
}

$railwayBinary = Join-Path $env:APPDATA 'npm\node_modules\@railway\cli\bin\railway.exe'
$arguments = @(
    'ssh', '--project', $ProjectId, '--environment', $Environment,
    '--service', $Service, '--identity-file', $IdentityFile, '--',
    'tar', '-czf', '-', '-C', $RemoteDirectory, '.'
)
$start = [System.Diagnostics.ProcessStartInfo]::new()
$start.FileName = $railwayBinary
$start.UseShellExecute = $false
$start.RedirectStandardOutput = $true
$start.RedirectStandardError = $true
foreach ($argument in $arguments) { [void]$start.ArgumentList.Add($argument) }

$process = [System.Diagnostics.Process]::new()
$process.StartInfo = $start
$file = [System.IO.File]::Open($windowsDestination, [System.IO.FileMode]::CreateNew)
try {
    if (-not $process.Start()) { throw 'Nao foi possivel iniciar o tar remoto.' }
    $errorTask = $process.StandardError.ReadToEndAsync()
    $process.StandardOutput.BaseStream.CopyTo($file)
    $process.WaitForExit()
    [void]$errorTask.GetAwaiter().GetResult()
    $file.Flush($true)
    if ($process.ExitCode -ne 0 -or $file.Length -lt 32) {
        throw "Arquivo de volume incompleto (codigo $($process.ExitCode))."
    }
    & wsl.exe -d Ubuntu-CBN -u root -- chmod 640 $linuxDestination
    if ($LASTEXITCODE -ne 0) { throw 'Nao foi possivel restringir o backup.' }
    Write-Output ([pscustomobject]@{
        Service = $Service
        Destination = $linuxDestination
        Bytes = $file.Length
        AtRest = 'LUKS2'
    })
}
finally {
    $file.Dispose()
    $process.Dispose()
}
