param()

$ErrorActionPreference = 'Stop'
$clientConfig = Join-Path $PSScriptRoot '..\tunnel\local\frpc.toml'
if (-not (Select-String -LiteralPath $clientConfig -Pattern '^httpUser\s*=' -Quiet)) {
    Write-Output 'senha_extra=desativada_use_o_login_do_CRM'
    exit 0
}
$mountedSource = & wsl.exe -d Ubuntu-CBN -u root -- findmnt -n -o SOURCE --target /srv/cbn-production
if ($LASTEXITCODE -ne 0 -or $mountedSource.Trim() -ne '/dev/mapper/cbn_production') {
    throw 'O cofre CBN precisa estar montado no Toshiba.'
}

$password = & wsl.exe -d Ubuntu-CBN -u root -- cat /srv/cbn-production/secrets/frp/preview_password
if ($LASTEXITCODE -ne 0 -or $password.Trim() -notmatch '^[a-f0-9]{48}$') {
    throw 'Senha de acesso da previa indisponivel.'
}
Set-Clipboard -Value $password.Trim()
Write-Output 'usuario=cbn-preview'
Write-Output 'senha=copiada_para_area_de_transferencia'
Write-Output 'apos_colar=limpe_a_area_de_transferencia'
