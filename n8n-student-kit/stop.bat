@echo off







setlocal EnableExtensions







chcp 65001 >nul















set "BASE_DIR=%~dp0"







set "COMPOSE_DIR=%BASE_DIR%compose"







set "ENV_FILE=%BASE_DIR%state\.env"















echo =======================







echo n8n Student Kit - Stop







echo =======================







echo.















echo [1/2] Stopping n8n...







pushd "%COMPOSE_DIR%"







docker compose --env-file ..\state\.env down >nul 2>&1







popd















echo [2/2] Stopping ngrok...







taskkill /F /FI "WINDOWTITLE eq n8n-kit-ngrok*" >nul 2>&1















echo Done.







call :gui_pause







exit /b 0











:gui_pause

if "%SKIP_PAUSE%"=="1" (

  echo [INFO] GUI: no keypress required.

  timeout /t 1 /nobreak >nul

  exit /b 0

)

pause

exit /b 0

