param()
$ErrorActionPreference = 'Stop'
$taskName = 'CBN-WSL-Keepalive'
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if (-not $task) {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $action = New-ScheduledTaskAction -Execute "$env:WINDIR\System32\wsl.exe" -Argument '-d Ubuntu-CBN -u root -- /bin/sleep infinity'
    $principal = New-ScheduledTaskPrincipal -UserId $identity -LogonType Interactive -RunLevel Limited
    $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    Register-ScheduledTask -TaskName $taskName -Action $action -Principal $principal -Settings $settings -Description 'Mantem somente o WSL CBN ativo; a parada segura encerra esta tarefa.' | Out-Null
} elseif ($task.Actions.Count -ne 1 -or $task.Actions[0].Arguments -ne '-d Ubuntu-CBN -u root -- /bin/sleep infinity') {
    throw 'A tarefa CBN de keepalive existente tem uma acao inesperada.'
}
if ((Get-ScheduledTask -TaskName $taskName).State -ne 'Running') {
    Start-ScheduledTask -TaskName $taskName
}
Write-Output 'keepalive=agendador_windows'
