# build-setup.ps1 — 组装 DeepSeek 桌面客户端安装包（DeepSeek-Setup.exe）
# 用法:
#   powershell -NoProfile -ExecutionPolicy Bypass -File build\build-setup.ps1 -TarballDir C:\path\deepseek-harness\dist
# -TarballDir: 含 npm\ 与 npm-vendor\ 两个发布 tarball 目录的父目录（见 README 构建步骤）
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$TarballDir
)
$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent            # 仓库根
$Client = Join-Path $Root 'client'
$Installer = Join-Path $Root 'installer'
$Dl = Join-Path $Root 'build\downloads'
$ProgressPreference = 'SilentlyContinue'

New-Item -ItemType Directory -Force -Path $Dl | Out-Null

function Step([string]$m) { Write-Host "==> $m" -ForegroundColor Cyan }
function Ensure-Download([string]$url, [string]$out) {
    if (-not (Test-Path $out)) {
        Write-Host "  下载 $url"
        Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing -TimeoutSec 600
    } else { Write-Host "  已存在 $out" }
}

# 1) 下载构建工具与运行时
Step '1/6 下载工具与运行时'
Ensure-Download 'https://registry.npmmirror.com/-/binary/node/v24.18.0/node-v24.18.0-win-x64.zip' (Join-Path $Dl 'node.zip')
Ensure-Download 'https://go.microsoft.com/fwlink/p/?LinkId=2124703' (Join-Path $Dl 'WebView2Setup.exe')
Ensure-Download 'https://www.7-zip.org/a/7zr.exe' (Join-Path $Dl '7zr.exe')
Ensure-Download 'https://www.7-zip.org/a/lzma2501.7z' (Join-Path $Dl 'lzma.7z')
$SfxDir = Join-Path $Dl 'sfx'
if (-not (Test-Path (Join-Path $SfxDir '7zS2.sfx'))) {
    New-Item -ItemType Directory -Force -Path $SfxDir | Out-Null
    & (Join-Path $Dl '7zr.exe') e (Join-Path $Dl 'lzma.7z') "-o$SfxDir" 'bin\7zS2.sfx' -y 2>&1 | Out-Null
}

# 2) 客户端源码 -> installer\app
Step '2/6 复制客户端'
if (Test-Path (Join-Path $Installer 'app')) { Remove-Item (Join-Path $Installer 'app') -Recurse -Force }
robocopy $Client (Join-Path $Installer 'app') /E /NFL /NDL /NJH /NJS | Out-Null

# 3) tarball 载荷
Step '3/6 复制 tarball 载荷'
$tb = Join-Path $Installer 'tarballs'
if (Test-Path $tb) { Remove-Item $tb -Recurse -Force }
New-Item -ItemType Directory -Force -Path $tb | Out-Null
foreach ($sub in @('npm', 'npm-vendor')) {
    $src = Join-Path $TarballDir $sub
    if (-not (Test-Path $src)) { throw "缺少 tarball 目录: $src" }
    Copy-Item (Join-Path $src '*.tgz') $tb -Force
}
Write-Host ("  tarball 数量: " + (Get-ChildItem $tb -Filter '*.tgz' | Measure-Object).Count)

# 4) Node 运行时 + WebView2 引导器
Step '4/6 解压 Node 运行时'
$rt = Join-Path $Installer 'runtime'
if (Test-Path $rt) { Remove-Item $rt -Recurse -Force }
New-Item -ItemType Directory -Force -Path $rt | Out-Null
Expand-Archive (Join-Path $Dl 'node.zip') (Join-Path $rt 'tmp') -Force
$nodeDir = Get-ChildItem (Join-Path $rt 'tmp') -Directory | Select-Object -First 1
Move-Item $nodeDir.FullName (Join-Path $rt 'node') -Force
Remove-Item (Join-Path $rt 'tmp') -Recurse -Force
Copy-Item (Join-Path $Dl 'WebView2Setup.exe') (Join-Path $Installer 'WebView2Setup.exe') -Force

# 5) 压缩载荷
Step '5/6 压缩载荷'
$payload = Join-Path $Root 'installer\payload.7z'
Remove-Item $payload -Force -ErrorAction SilentlyContinue
Push-Location $Installer
& (Join-Path $Dl '7zr.exe') a -t7z -mx=7 -bso0 -bsp0 $payload '*' 2>&1 | Out-Null
Pop-Location

# 6) 组装 SFX
Step '6/6 组装 DeepSeek-Setup.exe'
$setup = Join-Path $Root 'DeepSeek-Setup.exe'
$fs = [System.IO.File]::Create($setup)
$bw = New-Object System.IO.BinaryWriter($fs)
$bw.Write([System.IO.File]::ReadAllBytes((Join-Path $SfxDir '7zS2.sfx')))
$bw.Write([System.IO.File]::ReadAllBytes((Join-Path $Installer 'sfx-config.txt')))
$bw.Write([System.IO.File]::ReadAllBytes($payload))
$bw.Flush(); $bw.Close()
Remove-Item $payload -Force -ErrorAction SilentlyContinue
Write-Host ("完成: {0} ({1:N1} MB)" -f $setup, ((Get-Item $setup).Length / 1MB)) -ForegroundColor Green
