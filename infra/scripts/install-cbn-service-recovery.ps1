param()
$ErrorActionPreference = 'Stop'
$taskName = 'CBN-Service-Recovery'
$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$shellPath = (Get-Process -Id $PID).Path
$scriptPath = Join-Path $PSScriptRoot 'recover-cbn-services.ps1'
$arguments = '-NoProfile -NonInteractive -WindowStyle Hidden -File "' + $scriptPath + '"'
$action = New-ScheduledTaskAction -Execute $shellPath -Argument $arguments
$principal = New-ScheduledTaskPrincipal -UserId $identity -LogonType Interactive -RunLevel Limited
$logon = New-ScheduledTaskTrigger -AtLogOn -User $identity
$repeat = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 1)
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 8) -MultipleInstances IgnoreNew -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
$existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existing -and ($existing.Actions.Count -ne 1 -or $existing.Actions[0].Arguments -ne $arguments)) {
    throw 'A tarefa CBN existente tem uma acao inesperada.'
}
Register-ScheduledTask -TaskName $taskName -Action $action -Principal $principal -Trigger @($logon, $repeat) -Settings $settings -Description 'Confere CRM/WAHA/tunel por minuto e recupera somente com o Toshiba correto. Respeita maintenance.flag.' -Force | Out-Null
& (Join-Path $PSScriptRoot 'ensure-cbn-keepalive.ps1') | Out-Null
Start-ScheduledTask -TaskName $taskName
Write-Output 'recuperacao=ativa_por_minuto_e_ao_entrar_no_windows'
