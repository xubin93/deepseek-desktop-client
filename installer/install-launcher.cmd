@echo off
setlocal
set "SRC=%~dp0"
set "DST=%LOCALAPPDATA%\Programs\DeepSeek"
echo DeepSeek Desktop Client Setup
echo Copying files to %DST% ...
robocopy "%SRC%" "%DST%" /E /NFL /NDL /NJH /NJS /NP
if errorlevel 8 (
  echo Copy failed. Check disk space and retry.
  pause
  exit /b 1
)
cd /d "%DST%"
call postinstall.cmd
