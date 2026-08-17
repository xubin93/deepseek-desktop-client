@echo off
title DeepSeek Uninstall
setlocal
set "ROOT=%~dp0"
echo Stopping DeepSeek...
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%app\stop.ps1"
echo Removing shortcuts...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$d=[Environment]::GetFolderPath('Desktop'); $s=Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\DeepSeek'; Remove-Item (Join-Path $d 'DeepSeek.lnk') -Force -ErrorAction SilentlyContinue; Remove-Item $s -Recurse -Force -ErrorAction SilentlyContinue"
echo.
set /p ans=Delete the whole install folder %ROOT% now? (Y/N):
if /i "%ans%"=="Y" (
  cd /d "%USERPROFILE%"
  rmdir /s /q "%ROOT%"
  echo Install folder deleted. Leftover locked files can be removed manually later.
) else (
  echo Install folder kept at: %ROOT%
)
echo Uninstall finished.
pause
