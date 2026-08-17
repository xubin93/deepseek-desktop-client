@echo off
rem DeepSeek 服务器启动命令（安装版，路径全部相对本文件）
set "ROOT=%~dp0.."
set "DSH_HOME=%ROOT%\home\.dsh"
set "PATH=%ROOT%\runtime\node;%PATH%"
"%ROOT%\runtime\node\node.exe" "%ROOT%\packages\node_modules\@deepseek-ai\dsh\lib\bin.js" web >> "%ROOT%\app\server.log" 2>&1
