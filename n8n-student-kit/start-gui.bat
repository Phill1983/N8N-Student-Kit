@echo off
setlocal
set "BASE_DIR=%~dp0"
start "" powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%BASE_DIR%N8N-Student-Kit-GUI.ps1"
endlocal
exit /b 0
