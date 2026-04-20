@echo off
setlocal EnableExtensions EnableDelayedExpansion
set "ROOT=%~dp0"
set "LOG="
if /I "%~1"=="install" set "LOG=%ROOT%state\gui-install.log"
if /I "%~1"=="start" set "LOG=%ROOT%state\gui-start.log"
if /I "%~1"=="startnb" set "LOG=%ROOT%state\gui-start-no-browser.log"
if /I "%~1"=="stop" set "LOG=%ROOT%state\gui-stop.log"
if /I "%~1"=="cleanup" set "LOG=%ROOT%state\gui-cleanup.log"
if not defined LOG (
  echo [gui-run] Unknown subcommand: %~1
  exit /b 1
)
echo [GUI] %date% %time% - subcommand %~1 > "%LOG%" 2>&1
if /I "%~1"=="install" (
  set "SKIP_PAUSE=1"
  call "%ROOT%install.bat" --auto-reuse >> "%LOG%" 2>&1
  set "BAT_EXIT=!errorlevel!"
  goto :finish
)
if /I "%~1"=="start" (
  set "SKIP_PAUSE=1"
  call "%ROOT%start.bat" >> "%LOG%" 2>&1
  set "BAT_EXIT=!errorlevel!"
  goto :finish
)
if /I "%~1"=="startnb" (
  set "SKIP_PAUSE=1"
  call "%ROOT%start.bat" --no-browser >> "%LOG%" 2>&1
  set "BAT_EXIT=!errorlevel!"
  goto :finish
)
if /I "%~1"=="stop" (
  set "SKIP_PAUSE=1"
  call "%ROOT%stop.bat" >> "%LOG%" 2>&1
  set "BAT_EXIT=!errorlevel!"
  goto :finish
)
if /I "%~1"=="cleanup" (
  set "SKIP_PAUSE=1"
  call "%ROOT%uninstall-local.bat" >> "%LOG%" 2>&1
  set "BAT_EXIT=!errorlevel!"
  goto :finish
)
echo [gui-run] internal error >> "%LOG%" 2>&1
endlocal
exit /b 1

:finish
echo [GUI] done, errorlevel !BAT_EXIT! at %date% %time% >> "%LOG%" 2>&1
endlocal & exit /b %BAT_EXIT%
