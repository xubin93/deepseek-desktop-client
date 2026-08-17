@echo off
title DeepSeek Setup
setlocal
set "ROOT=%~dp0"
set "NODE=%ROOT%runtime\node\node.exe"
set "NPM=%ROOT%runtime\node\node_modules\npm\bin\npm-cli.js"
echo [1/5] Generating dependency manifest...
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%app\gen-package-json.ps1"
if errorlevel 1 goto fail
echo [2/5] Installing DeepSeek Harness (offline packages + small external deps, needs internet, 2-5 min)...
"%NODE%" "%NPM%" install --no-audit --no-fund --package-lock=false --ignore-scripts --prefix "%ROOT%packages"
if errorlevel 1 goto fail
echo [3/5] Installing profile plugin (dsh-market)...
"%NODE%" "%NPM%" install --no-audit --no-fund --package-lock=false --ignore-scripts --prefix "%ROOT%home\.dsh\profiles\web"
if errorlevel 1 goto fail
echo [4/5] Ensuring WebView2 runtime (skips if already installed)...
"%ROOT%WebView2Setup.exe" /silent /install
echo [5/5] Creating shortcuts...
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%app\create-shortcut.ps1"
echo.
echo Setup complete! Double-click the DeepSeek icon on your desktop.
echo On first launch, open Settings - Models and enter your API key.
ping -n 8 127.0.0.1 >nul
exit /b 0
:fail
echo.
echo Setup failed. Check your network connection and run the installer again
echo (external dependencies require internet access).
pause
exit /b 1

