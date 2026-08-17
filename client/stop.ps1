# DeepSeek 客户端 停止（安装版）
$ErrorActionPreference = 'Continue'
$AppDir = $PSScriptRoot
$PidFile = Join-Path $AppDir 'server.pid'
$killed = $false

if (Test-Path $PidFile) {
    $p = Get-Content $PidFile -ErrorAction SilentlyContinue
    if ($p -match '^\d+$') {
        cmd /c "taskkill /F /T /PID $p" 2>$null | Out-Null
        $killed = $true
        Start-Sleep -Seconds 1
    }
    Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
}

# 覆盖源码运行与安装版运行两种命令行形态
Get-CimInstance Win32_Process -Filter "Name='node.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match 'apps/cli/src/bin\.ts.*web|lib\\bin\.js.*web' } |
    ForEach-Object {
        cmd /c "taskkill /F /T /PID $($_.ProcessId)" 2>$null | Out-Null
        $killed = $true
    }

Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object {
        ($_.Name -eq 'powershell.exe' -and $_.CommandLine -match 'DeepSeek[\\/]app[\\/]client\.ps1') -or
        ($_.Name -eq 'msedge.exe' -and $_.CommandLine -match 'DeepSeek-Desktop\\EdgeProfile')
    } |
    ForEach-Object {
        cmd /c "taskkill /F /T /PID $($_.ProcessId)" 2>$null | Out-Null
        $killed = $true
    }

Start-Sleep -Seconds 2
if ($killed) { Write-Host '[DeepSeek] 服务器与客户端窗口已停止。' }
else { Write-Host '[DeepSeek] 没有发现正在运行的客户端。' }
exit 0
