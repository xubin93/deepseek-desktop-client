# 由 postinstall 调用：创建桌面与开始菜单快捷方式
$ErrorActionPreference = 'Continue'
$appDir = $PSScriptRoot
$root = Split-Path $appDir -Parent
$ws = New-Object -ComObject WScript.Shell
$desktop = [Environment]::GetFolderPath('Desktop')
$sm = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\DeepSeek'
New-Item -ItemType Directory -Force -Path $sm | Out-Null
foreach ($dir in @($desktop, $sm)) {
    $lnk = Join-Path $dir 'DeepSeek.lnk'
    $s = $ws.CreateShortcut($lnk)
    $s.TargetPath = Join-Path $appDir 'launch.vbs'
    $s.WorkingDirectory = $appDir
    $s.IconLocation = (Join-Path $appDir 'DeepSeek.ico') + ',0'
    $s.Description = 'DeepSeek 桌面客户端'
    $s.Save()
}
$un = Join-Path $sm '卸载 DeepSeek.lnk'
$s2 = $ws.CreateShortcut($un)
$s2.TargetPath = Join-Path $root 'uninstall.cmd'
$s2.WorkingDirectory = $root
$s2.Save()
Write-Host '快捷方式已创建（桌面 + 开始菜单）'
