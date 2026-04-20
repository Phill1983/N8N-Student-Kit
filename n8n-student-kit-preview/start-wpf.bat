@echo off
setlocal
set "HERE=%~dp0"
start "" powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%HERE%N8N-Student-Kit-WPF.ps1"
exit /b 0
