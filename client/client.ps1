# DeepSeek 桌面客户端（安装版，可重定位）— 托盘后台运行 + 关闭行为设置
[CmdletBinding()]
param(
    [switch]$NoOpen,              # 只确保服务器运行，不打开窗口
    [int]$AutoCloseSeconds = 0,   # 测试用：窗口打开 N 秒后自动退出
    [int]$AutoTraySeconds = 0,    # 测试用：N 秒后自动走 托盘->恢复->退出 全流程
    [switch]$TestInstance         # 测试用：独立互斥/信号/浏览器数据目录
)

$ErrorActionPreference = 'Stop'
# ---- 全部路径从脚本位置推导，支持任意安装目录 ----
$AppDir      = $PSScriptRoot
$InstallRoot = Split-Path $AppDir -Parent
$DshHome     = Join-Path $InstallRoot 'home\.dsh'
$NodeExe     = Join-Path $InstallRoot 'runtime\node\node.exe'
$DshCli      = Join-Path $InstallRoot 'packages\node_modules\@deepseek-ai\dsh\lib\bin.js'
$env:DSH_HOME = $DshHome
$PidFile   = Join-Path $AppDir 'server.pid'
$LogFile   = Join-Path $AppDir 'server.log'
$ClientLog = Join-Path $AppDir 'client.log'
$RunCmd    = Join-Path $AppDir 'run-server.cmd'
$Url       = 'http://127.0.0.1:3080'

function Write-Log([string]$m) {
    Add-Content -Path $ClientLog -Value ("{0}  {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m) -Encoding UTF8
}
function Show-Error([string]$m) {
    Write-Log "ERROR: $m"
    try {
        (New-Object -ComObject WScript.Shell).Popup("DeepSeek 客户端`r`n`r`n$m`r`n`r`n详细日志：$ClientLog", 0, 'DeepSeek', 16) | Out-Null
    } catch {}
}
function Test-ServerUp {
    $listener = Get-NetTCPConnection -LocalPort 3080 -State Listen -ErrorAction SilentlyContinue
    return [bool]$listener
}
function Stop-Tree([int]$ProcId) {
    $ErrorActionPreference = 'Continue'
    cmd /c "taskkill /F /T /PID $ProcId" 2>$null | Out-Null
}
function Stop-DshServer {
    Write-Log '正在停止后台服务器...'
    if (Test-Path $PidFile) {
        $sp = Get-Content $PidFile -ErrorAction SilentlyContinue
        if ($sp -match '^\d+$') { Stop-Tree ([int]$sp) }
        Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
    }
    # 覆盖源码运行与安装版运行两种命令行形态
    Get-CimInstance Win32_Process -Filter "Name='node.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match 'apps/cli/src/bin\.ts.*web|lib\\bin\.js.*web' } |
        ForEach-Object { Stop-Tree ([int]$_.ProcessId) }
    Write-Log '后台服务器已停止'
}

# 单实例保护 + 跨进程唤醒
$script:RealExit = $false
$mutexName = 'DeepSeek.DesktopClient.Singleton' + $(if ($TestInstance) { '.Test' } else { '' })
$eventName = 'DeepSeek.DesktopClient.RestoreEvent' + $(if ($TestInstance) { '.Test' } else { '' })
$mutex = New-Object System.Threading.Mutex($true, $mutexName)
if (-not $mutex.WaitOne(0)) {
    try {
        $evt = [System.Threading.EventWaitHandle]::OpenExisting($eventName)
        $null = $evt.Set()
        $evt.Dispose()
        Write-Log '客户端已在运行，已发送恢复窗口信号'
    } catch {
        Write-Log '客户端已在运行，本次启动被忽略'
    }
    exit 0
}
$restoreEvent = New-Object System.Threading.EventWaitHandle($false, [System.Threading.EventResetMode]::AutoReset, $eventName)

# 0) 关闭行为持久化设置
$SettingsFile = Join-Path $AppDir 'client-settings.json'
function Read-CloseBehavior {
    try {
        $j = Get-Content $SettingsFile -Raw -ErrorAction Stop | ConvertFrom-Json
        if ($j.closeBehavior -in @('ask', 'tray', 'exit')) { return $j.closeBehavior }
    } catch {}
    return 'ask'
}
function Write-CloseBehavior([string]$v) {
    try {
        (@{ closeBehavior = $v } | ConvertTo-Json) | Set-Content -Path $SettingsFile -Encoding UTF8
    } catch {
        Write-Log "设置保存失败：$($_.Exception.Message)"
    }
}
$script:CloseBehavior = Read-CloseBehavior
Write-Log "关闭行为设置：$($script:CloseBehavior)"

# 1) 确保服务器运行（已运行则直接复用）
if (-not (Test-ServerUp)) {
    Write-Log '服务器未运行，正在启动...'
    if (-not (Test-Path $DshCli)) {
        Show-Error "找不到 DeepSeek Harness 安装（$DshCli）。请重新运行安装程序。"
        exit 1
    }
    if (Test-Path $PidFile) {
        $old = Get-Content $PidFile -ErrorAction SilentlyContinue
        if ($old -match '^\d+$' -and (Get-Process -Id ([int]$old) -ErrorAction SilentlyContinue)) {
            Write-Log "发现残留进程 $old，正在结束..."
            Stop-Tree ([int]$old)
            Start-Sleep -Seconds 1
        }
        Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
    }
    Set-Content -Path $LogFile -Value "--- DeepSeek server log $(Get-Date) ---" -Encoding UTF8
    $proc = Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', "`"$RunCmd`"" -WindowStyle Hidden -PassThru
    Set-Content -Path $PidFile -Value $proc.Id -Encoding Ascii

    $deadline = (Get-Date).AddSeconds(90)
    $ok = $false
    while ((Get-Date) -lt $deadline) {
        if (Test-ServerUp) { $ok = $true; break }
        if ($proc.HasExited) { break }
        Start-Sleep -Seconds 1
    }
    if (-not $ok) {
        Show-Error '服务器启动失败（90 秒超时）。请检查 server.log。'
        exit 1
    }
    Write-Log '服务器已就绪'
}

if ($NoOpen) {
    Write-Log '服务器已就绪（NoOpen 模式，不打开窗口）'
    exit 0
}

# 2) 打开客户端窗口：优先 WebView2 原生窗口，失败则回退 Edge 应用模式
$opened = $false

$wv2Dir = Join-Path $AppDir 'WebView2'

if (Test-Path (Join-Path $wv2Dir 'Microsoft.Web.WebView2.Core.dll')) {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        Add-Type -Path (Join-Path $wv2Dir 'Microsoft.Web.WebView2.Core.dll')
        Add-Type -Path (Join-Path $wv2Dir 'Microsoft.Web.WebView2.WinForms.dll')
        Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public static class NativeWin { [DllImport("shell32.dll", CharSet=CharSet.Unicode)] public static extern int SetCurrentProcessExplicitAppUserModelID(string appId); [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam); }'
        $null = [NativeWin]::SetCurrentProcessExplicitAppUserModelID('DeepSeek.DesktopClient')

        $form = New-Object System.Windows.Forms.Form
        $form.Text = 'DeepSeek'
        $form.Size = New-Object System.Drawing.Size(1440, 900)
        $form.StartPosition = 'CenterScreen'

        function Get-IconFromSize([System.Drawing.Image]$src, [int]$size) {
            $b = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
            $g = [System.Drawing.Graphics]::FromImage($b)
            $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $g.DrawImage($src, 0, 0, $size, $size)
            $g.Dispose()
            $ic = [System.Drawing.Icon]::FromHandle($b.GetHicon())
            $b.Dispose()
            return $ic
        }
        $formIcon = $null
        $trayIcon = $null
        $iconSrc = Join-Path $AppDir 'icon-256.png'
        if (Test-Path $iconSrc) {
            try {
                $srcImg = [System.Drawing.Image]::FromFile($iconSrc)
                $formIcon = Get-IconFromSize $srcImg 256
                $trayIcon = Get-IconFromSize $srcImg 32
                $srcImg.Dispose()
                $form.Icon = $formIcon
                Write-Log '窗口图标已应用（256px 鲸鱼）'
            } catch {
                Write-Log "图标生成失败：$($_.Exception.Message)"
            }
        }
        if ($formIcon -eq $null) {
            $icoPath = Join-Path $AppDir 'DeepSeek.ico'
            if (Test-Path $icoPath) {
                try {
                    $formIcon = New-Object System.Drawing.Icon($icoPath)
                    $form.Icon = $formIcon
                } catch {
                    Write-Log "ico 回退加载失败：$($_.Exception.Message)"
                }
            }
        }

        $wv = New-Object Microsoft.Web.WebView2.WinForms.WebView2
        $wv.Dock = 'Fill'
        $form.Controls.Add($wv)
        $null = $form.Handle
        if ($formIcon) {
            $smallIcon = if ($trayIcon) { $trayIcon } else { $formIcon }
            $null = [NativeWin]::SendMessage($form.Handle, 0x80, [IntPtr]1, $formIcon.Handle)
            $null = [NativeWin]::SendMessage($form.Handle, 0x80, [IntPtr]0, $smallIcon.Handle)
        }

        # --- 托盘图标（常驻） ---
        $tray = New-Object System.Windows.Forms.NotifyIcon
        $tray.Text = 'DeepSeek'
        if ($trayIcon) { $tray.Icon = $trayIcon }
        $tray.Visible = $true
        $trayMenu = New-Object System.Windows.Forms.ContextMenuStrip
        $miShow = $trayMenu.Items.Add('显示 DeepSeek')
        $miCloseMenu = New-Object System.Windows.Forms.ToolStripMenuItem('关闭窗口行为')
        $miAsk  = New-Object System.Windows.Forms.ToolStripMenuItem('每次询问')
        $miTray = New-Object System.Windows.Forms.ToolStripMenuItem('后台运行（托盘）')
        $miExitMode = New-Object System.Windows.Forms.ToolStripMenuItem('退出并停止服务器')
        foreach ($m in @($miAsk, $miTray, $miExitMode)) {
            $m.CheckOnClick = $true
            $miCloseMenu.DropDownItems.Add($m) | Out-Null
        }
        $null = $trayMenu.Items.Add($miCloseMenu)
        $miExit = $trayMenu.Items.Add('退出（停止服务器）')
        $tray.ContextMenuStrip = $trayMenu

        function Set-CloseBehavior([string]$v) {
            $script:CloseBehavior = $v
            Write-CloseBehavior $v
            $miAsk.Checked = ($v -eq 'ask')
            $miTray.Checked = ($v -eq 'tray')
            $miExitMode.Checked = ($v -eq 'exit')
            Write-Log "关闭行为已设置为：$v"
        }
        $miAsk.Add_Click({ Set-CloseBehavior 'ask' })
        $miTray.Add_Click({ Set-CloseBehavior 'tray' })
        $miExitMode.Add_Click({ Set-CloseBehavior 'exit' })
        $miAsk.Checked = ($script:CloseBehavior -eq 'ask')
        $miTray.Checked = ($script:CloseBehavior -eq 'tray')
        $miExitMode.Checked = ($script:CloseBehavior -eq 'exit')

        function Restore-ClientWindow {
            $form.ShowInTaskbar = $true
            $form.WindowState = 'Normal'
            $form.Show()
            $form.Activate()
            Write-Log '客户端窗口已从托盘恢复'
        }

        $miShow.Add_Click({ Restore-ClientWindow })
        $miExit.Add_Click({ $script:RealExit = $true; $form.Close() })
        $tray.Add_DoubleClick({ Restore-ClientWindow })

        $wakeTimer = New-Object System.Windows.Forms.Timer
        $wakeTimer.Interval = 1000
        $wakeTimer.Add_Tick({
            if ($restoreEvent.WaitOne(0)) { Restore-ClientWindow }
        })
        $wakeTimer.Start()

        $form.Add_FormClosing({
            param($sender, $e)
            if ($script:RealExit) { return }
            if ($e.CloseReason -ne [System.Windows.Forms.CloseReason]::UserClosing) { return }
            switch ($script:CloseBehavior) {
                'ask' {
                    $e.Cancel = $true
                    $answer = [System.Windows.Forms.MessageBox]::Show(
                        $form,
                        "是 = 最小化到托盘，服务器继续后台运行`n否 = 退出并停止服务器`n取消 = 留在窗口",
                        'DeepSeek',
                        [System.Windows.Forms.MessageBoxButtons]::YesNoCancel,
                        [System.Windows.Forms.MessageBoxIcon]::Question)
                    if ($answer -eq 'Yes') {
                        $form.ShowInTaskbar = $false
                        $form.Hide()
                        Write-Log '已最小化到托盘（服务器继续后台运行）'
                    } elseif ($answer -eq 'No') {
                        $script:RealExit = $true
                        $e.Cancel = $false
                    }
                }
                'tray' {
                    $e.Cancel = $true
                    $form.ShowInTaskbar = $false
                    $form.Hide()
                    Write-Log '已最小化到托盘（服务器继续后台运行）'
                }
                'exit' {
                    $script:RealExit = $true
                }
            }
        })

        $profileDir = Join-Path $AppDir $(if ($TestInstance) { 'WebView2Profile-Test' } else { 'WebView2Profile' })
        $rtDir = Get-ChildItem 'C:\Program Files (x86)\Microsoft\EdgeWebView\Application' -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^\d+\.\d+\.\d+\.\d+$' } |
            Sort-Object { [version]$_.Name } -Descending |
            Select-Object -First 1 -ExpandProperty FullName
        if ($rtDir) {
            $envTask = [Microsoft.Web.WebView2.Core.CoreWebView2Environment]::CreateAsync($rtDir, $profileDir, $null)
        } else {
            $envTask = [Microsoft.Web.WebView2.Core.CoreWebView2Environment]::CreateAsync($null, $profileDir, $null)
        }
        while (-not $envTask.IsCompleted) {
            Start-Sleep -Milliseconds 30
            [System.Windows.Forms.Application]::DoEvents()
        }
        $webEnv = $envTask.Result

        $initTask = $wv.EnsureCoreWebView2Async($webEnv)
        while (-not $initTask.IsCompleted) {
            Start-Sleep -Milliseconds 30
            [System.Windows.Forms.Application]::DoEvents()
        }
        $null = $initTask.Result
        $wv.CoreWebView2.Navigate($Url)

        if ($AutoCloseSeconds -gt 0) {
            $autoClose = New-Object System.Windows.Forms.Timer
            $autoClose.Interval = $AutoCloseSeconds * 1000
            $autoClose.Add_Tick({ $script:RealExit = $true; $form.Close() })
            $autoClose.Start()
        }
        if ($AutoTraySeconds -gt 0) {
            $t1 = New-Object System.Windows.Forms.Timer
            $t1.Interval = $AutoTraySeconds * 1000
            $t2 = New-Object System.Windows.Forms.Timer
            $t2.Interval = 2000
            $t3 = New-Object System.Windows.Forms.Timer
            $t3.Interval = 2000
            $t1.Add_Tick({
                $form.ShowInTaskbar = $false
                $form.Hide()
                Write-Log '测试：已最小化到托盘'
                $t1.Stop()
                $t2.Start()
            })
            $t2.Add_Tick({
                Restore-ClientWindow
                Write-Log '测试：已从托盘恢复'
                $t2.Stop()
                $t3.Start()
            })
            $t3.Add_Tick({
                $script:RealExit = $true
                $form.Close()
                $t3.Stop()
            })
            $t1.Start()
        }

        Write-Log 'WebView2 客户端窗口已打开'
        [System.Windows.Forms.Application]::Run($form) | Out-Null
        Write-Log '客户端窗口已关闭'
        $wakeTimer.Stop()
        $wakeTimer.Dispose()
        $tray.Visible = $false
        $tray.Dispose()
        $restoreEvent.Dispose()
        if ($AutoCloseSeconds -eq 0 -and $AutoTraySeconds -eq 0) {
            Stop-DshServer
        } else {
            Write-Log '测试模式：跳过停止服务器'
        }
        $opened = $true
    } catch {
        Write-Log "WebView2 加载失败：$($_.Exception.Message)"
    }
}

if (-not $opened) {
    $edge = 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
    if (Test-Path $edge) {
        Write-Log '回退：使用 Edge 应用模式窗口'
        $profileDir = Join-Path $env:LOCALAPPDATA 'DeepSeek-Desktop\EdgeProfile'
        Start-Process $edge -ArgumentList "--app=$Url", "--user-data-dir=$profileDir", '--no-first-run', '--window-size=1440,900'
        Write-Log 'Edge 应用窗口已打开'
        if ($AutoCloseSeconds -gt 0) {
            Start-Sleep -Seconds $AutoCloseSeconds
            Get-CimInstance Win32_Process -Filter "Name='msedge.exe'" -ErrorAction SilentlyContinue |
                Where-Object { $_.CommandLine -match 'DeepSeek-Desktop\\EdgeProfile' } |
                ForEach-Object { Stop-Tree ([int]$_.ProcessId) }
            Write-Log 'Edge 应用窗口已关闭（测试模式）'
        } else {
            while (Get-CimInstance Win32_Process -Filter "Name='msedge.exe'" -ErrorAction SilentlyContinue |
                Where-Object { $_.CommandLine -match 'DeepSeek-Desktop\\EdgeProfile' }) {
                Start-Sleep -Seconds 2
            }
            Write-Log 'Edge 应用窗口已关闭'
            Stop-DshServer
        }
        $opened = $true
    }
}

if (-not $opened) {
    Show-Error '无法打开客户端窗口（WebView2 与 Edge 均不可用）。'
    exit 1
}
exit 0
