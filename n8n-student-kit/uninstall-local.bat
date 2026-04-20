@echo off



setlocal EnableExtensions



chcp 65001 >nul







set "BASE_DIR=%~dp0"



set "STATE_DIR=%BASE_DIR%state"







echo ==================================



echo n8n Student Kit - Local Cleanup



echo ==================================



echo.







call "%BASE_DIR%stop.bat"







if exist "%STATE_DIR%\install.cfg" del /q "%STATE_DIR%\install.cfg"



if exist "%STATE_DIR%\.env" del /q "%STATE_DIR%\.env"







echo Локальні конфіги очищено.



call :gui_pause



exit /b 0





:gui_pause
if "%SKIP_PAUSE%"=="1" (
  echo [INFO] GUI: без натискання клавіші.
  timeout /t 1 /nobreak >nul
  goto :gui_pause_end
)
pause
:gui_pause_end
exit /b 0
