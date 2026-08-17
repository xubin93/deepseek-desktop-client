# 由 postinstall 调用：扫描 tarballs 目录，生成 packages\package.json（file: 依赖清单）
$ErrorActionPreference = 'Stop'
$appDir = $PSScriptRoot
$root = Split-Path $appDir -Parent
$tarballDir = Join-Path $root 'tarballs'
$pkgsDir = Join-Path $root 'packages'
New-Item -ItemType Directory -Force -Path $pkgsDir | Out-Null

$deps = [ordered]@{}
$count = 0
foreach ($tgz in (Get-ChildItem $tarballDir -Filter '*.tgz' | Sort-Object Name)) {
    $json = (& "$env:SystemRoot\System32\tar.exe" -xOf $tgz.FullName package/package.json 2>$null) -join "`n"
    if (-not $json) { Write-Host "警告：无法读取 $($tgz.Name)"; continue }
    try {
        $pkg = $json | ConvertFrom-Json
    } catch {
        Write-Host "警告：解析失败 $($tgz.Name)"; continue
    }
    if (-not $pkg.name) { continue }
    $deps[$pkg.name] = 'file:' + ($tgz.FullName -replace '\\', '/')
    $count++
}
$manifest = @{ name = 'dsh-packages'; version = '1.0.0'; private = $true; dependencies = $deps } | ConvertTo-Json -Depth 3
[System.IO.File]::WriteAllText((Join-Path $pkgsDir 'package.json'), $manifest, (New-Object System.Text.UTF8Encoding($false)))
Write-Host ("已生成 packages\package.json，共 {0} 个离线依赖" -f $count)
