@echo off







setlocal EnableExtensions EnableDelayedExpansion







chcp 65001 >nul















title n8n Student Kit - Install















set "BASE_DIR=%~dp0"







set "STATE_DIR=%BASE_DIR%state"







set "COMPOSE_DIR=%BASE_DIR%compose"







set "TOOLS_DIR=%BASE_DIR%tools"



set "NGROK_EXE=%TOOLS_DIR%\ngrok.exe"



set "DOCKER_INSTALLER=%TOOLS_DIR%\DockerDesktopInstaller.exe"



if not exist "%DOCKER_INSTALLER%" set "DOCKER_INSTALLER=%TOOLS_DIR%\Docker Desktop Installer.exe"



set "DOCKER_DESKTOP_EXE=C:\Program Files\Docker\Docker\Docker Desktop.exe"



set "N8N_VERSION=2.15.0"



set "N8N_IMAGE=n8nio/n8n:%N8N_VERSION%"



set "N8N_IMAGE_TAR=%TOOLS_DIR%\images\n8n-%N8N_VERSION%.tar"







set "ENV_FILE=%STATE_DIR%\.env"







set "CONFIG_FILE=%STATE_DIR%\install.cfg"



set "LOG_FILE=%STATE_DIR%\install-launch.log"















if not exist "%STATE_DIR%" mkdir "%STATE_DIR%"







set "ELEVATED_ARG=0"



set "AUTO_REUSE=0"



set "RELAUNCH_ARGS=--elevated"



for %%A in (%*) do (



    if /I "%%~A"=="--elevated" set "ELEVATED_ARG=1"



    if /I "%%~A"=="--auto-reuse" set "AUTO_REUSE=1"



)



if "%AUTO_REUSE%"=="1" set "RELAUNCH_ARGS=--auto-reuse --elevated"







fltmc >nul 2>&1



if errorlevel 1 (



    if "%ELEVATED_ARG%"=="1" (



        echo [ERROR] Administrator rights were not granted ^(UAC cancelled or blocked by policy^).



        echo Open CMD as administrator and run:



        echo        "%~f0" --elevated



        call :maybe_pause



        exit /b 1



    )



    >"%LOG_FILE%" echo [INFO] Requested elevation at %date% %time%



    echo [INFO] Administrator rights required. Requesting UAC...



    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -Verb RunAs -FilePath 'cmd.exe' -ArgumentList '/k ""%~f0"" !RELAUNCH_ARGS!'"



    if errorlevel 1 (



        echo [WARN] PowerShell RunAs failed. Trying fallback...



        mshta "javascript:var sh=new ActiveXObject('Shell.Application'); sh.ShellExecute('cmd.exe','/k ""%~f0"" --elevated','','runas',1);close();"



    )



    echo [INFO] If a new admin window did not open, open CMD as administrator and run:



    echo        "%~f0" --elevated



    echo [INFO] Launch log: "%LOG_FILE%"



    call :maybe_pause



    exit /b 1



)















echo ==========================================







echo n8n Student Kit - First Install / Repair







echo ==========================================







echo.















net session >nul 2>&1



if errorlevel 1 (



    echo [WARN] Could not verify rights via net session. Continuing...



)















if exist "%CONFIG_FILE%" (







    echo [1/10] Existing configuration found.



    if "%AUTO_REUSE%"=="1" (



        echo [INFO] --auto-reuse active. Using existing configuration.



        goto load_config



    )







    set /p REUSE_CONFIG=Reuse it? ^(Y/N, default Y^): 







    if /I "%REUSE_CONFIG%"=="N" goto collect_config







    if /I "%REUSE_CONFIG%"=="NO" goto collect_config







    goto load_config







)















:collect_config







echo [1/10] Entering parameters...







set /p INSTALL_DRIVE=Which drive to store n8n data on (e.g. C or D): 







if "%INSTALL_DRIVE%"=="" set "INSTALL_DRIVE=C"















set "N8N_DATA=%INSTALL_DRIVE%:\n8n-data"







if not exist "%N8N_DATA%" mkdir "%N8N_DATA%"















set /p NGROK_DOMAIN=Enter your permanent ngrok domain: 







if "%NGROK_DOMAIN%"=="" (







    echo [ERROR] NGROK_DOMAIN cannot be empty.







    call :maybe_pause







    exit /b 1







)















set /p NGROK_AUTHTOKEN=Enter ngrok authtoken: 







if "%NGROK_AUTHTOKEN%"=="" (







    echo [ERROR] NGROK_AUTHTOKEN cannot be empty.







    call :maybe_pause







    exit /b 1







)















set /p N8N_BASIC_AUTH_USER=Enter login for n8n basic auth: 







if "%N8N_BASIC_AUTH_USER%"=="" (







    echo [ERROR] Login cannot be empty.







    call :maybe_pause







    exit /b 1







)















set /p N8N_BASIC_AUTH_PASSWORD=Enter password for n8n basic auth: 







if "%N8N_BASIC_AUTH_PASSWORD%"=="" (







    echo [ERROR] Password cannot be empty.







    call :maybe_pause







    exit /b 1







)















(







    echo INSTALL_DRIVE=%INSTALL_DRIVE%







    echo N8N_DATA=%N8N_DATA%







    echo NGROK_DOMAIN=%NGROK_DOMAIN%







    echo NGROK_AUTHTOKEN=%NGROK_AUTHTOKEN%







    echo N8N_BASIC_AUTH_USER=%N8N_BASIC_AUTH_USER%







    echo N8N_BASIC_AUTH_PASSWORD=%N8N_BASIC_AUTH_PASSWORD%







)>"%CONFIG_FILE%"















goto after_load















:load_config







echo [1/10] Loading existing configuration...







for /f "usebackq tokens=1,* delims==" %%A in ("%CONFIG_FILE%") do (







    set "%%A=%%B"







)















if "%N8N_BASIC_AUTH_USER%"=="" (







    set /p N8N_BASIC_AUTH_USER=Enter login for n8n basic auth: 







)







if "%N8N_BASIC_AUTH_PASSWORD%"=="" (







    set /p N8N_BASIC_AUTH_PASSWORD=Enter password for n8n basic auth: 







)















:after_load

echo [1b/10] Checking local tools (Docker installer, ngrok)...
call :ensure_tools
set "ET_RC=%ERRORLEVEL%"
if "%ET_RC%"=="2" (
    call :maybe_pause
    exit /b 0
)
if "%ET_RC%"=="1" (
    call :maybe_pause
    exit /b 1
)

echo [2/10] Checking WSL...







wsl --version >nul 2>&1







if errorlevel 1 (







    echo [WARN] WSL not found or unavailable.







    echo Trying to enable the required Windows features...







    dism /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart







    dism /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart







    echo.







    echo [ACTION REQUIRED] Windows reboot required.







    call :maybe_pause







    exit /b 0







)















echo [3/10] Checking Docker Desktop...







docker --version >nul 2>&1







if not errorlevel 1 (







    echo [INFO] Docker CLI already in PATH - not running the installer from tools\.





    echo [INFO] In Task Manager look for Docker Desktop.exe or com.docker.backend, not Docker Desktop Installer.exe.





    echo [INFO] The last line is normal: the installer from tools/ is only needed if docker is not yet installed.





)







if errorlevel 1 (







    if not exist "%DOCKER_INSTALLER%" (







        echo [ERROR] Docker installer not found in the tools folder.







        echo Supported names: DockerDesktopInstaller.exe or Docker Desktop Installer.exe







        call :maybe_pause







        exit /b 1







    )















    echo Installing Docker Desktop...







    echo [INFO] Running: "%DOCKER_INSTALLER%" install --quiet --accept-license







    echo [INFO] Without --accept-license the silent install often hangs on the license screen.







    echo [INFO] Silent install usually takes 2-5 min; the console will not update during that - this is normal.







    echo [INFO] Docker processes before the installer starts ^(empty means not started yet^):







    tasklist 2>nul | findstr /I /C:"Docker Desktop" /C:"com.docker" /C:"DockerDesktop"







    echo [INFO] Launching: Docker Desktop Installer.exe should appear ^(sometimes only for 1-2 min^).







    echo [WAIT] A pause with no new lines is normal. The next log line appears only after the installer exits ^(usually a few minutes^).







    start /wait "" "%DOCKER_INSTALLER%" install --quiet --accept-license







    echo [INFO] Installer finished, code: !ERRORLEVEL!







    echo [INFO] Docker processes after the installer:







    tasklist 2>nul | findstr /I /C:"Docker Desktop" /C:"com.docker" /C:"DockerDesktop"





















    echo.







    echo [ACTION REQUIRED] Docker Desktop installed.







    echo If the system asks for a reboot - reboot the PC and run install.bat again.



    echo [NEXT] Then run Install [Admin] or install.bat --auto-reuse again - ngrok, .env and n8n will follow. Click Start only once state\.env exists [after full install].








    call :maybe_pause







    exit /b 0







)







for /f "tokens=1,* delims=:" %%A in ('docker --version 2^>nul') do set "DOCKER_VERSION_LINE=%%A:%%B"



if defined DOCKER_VERSION_LINE echo [INFO] Found Docker CLI: !DOCKER_VERSION_LINE!







docker info >nul 2>&1



if errorlevel 1 (



    echo [INFO] Docker daemon is not yet available. This is normal after installation.



    echo [INFO] Will try to start Docker Desktop and wait until it is ready.



) else (



    echo [INFO] Docker daemon is already available.



)















echo [4/10] Checking ngrok...



if not exist "%NGROK_EXE%" (



    for /f "delims=" %%I in ('where ngrok.exe 2^>nul') do (



        set "NGROK_EXE=%%~fI"



        goto ngrok_found



    )



)



:ngrok_found



if not exist "%NGROK_EXE%" (







    echo [ERROR] tools\ngrok.exe not found.







    echo Put the official ngrok.exe into the tools folder or install ngrok into PATH.







    call :maybe_pause







    exit /b 1







)







echo [INFO] Using ngrok: "%NGROK_EXE%"















echo [5/10] Configuring ngrok...







"%NGROK_EXE%" config add-authtoken %NGROK_AUTHTOKEN%







if errorlevel 1 (







    echo [ERROR] Failed to add ngrok authtoken.







    call :maybe_pause







    exit /b 1







)















echo [6/10] Creating .env...







(







    echo NGROK_DOMAIN=%NGROK_DOMAIN%







    echo NGROK_AUTHTOKEN=%NGROK_AUTHTOKEN%







    echo N8N_DATA=%N8N_DATA%







    echo WEBHOOK_URL=https://%NGROK_DOMAIN%/







    echo N8N_HOST=%NGROK_DOMAIN%







    echo N8N_PROTOCOL=https







    echo N8N_PORT=5678







    echo N8N_VERSION=%N8N_VERSION%







    echo N8N_PROXY_HOPS=1







    echo N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true







    echo N8N_BASIC_AUTH_ACTIVE=true







    echo N8N_BASIC_AUTH_USER=%N8N_BASIC_AUTH_USER%







    echo N8N_BASIC_AUTH_PASSWORD=%N8N_BASIC_AUTH_PASSWORD%







    echo TZ=Europe/Warsaw







    echo GENERIC_TIMEZONE=Europe/Warsaw







)>"%ENV_FILE%"















echo [7/10] Test-starting Docker Desktop...







set "DOCKER_DESKTOP_RUNNING=1"



docker desktop status >nul 2>&1



if errorlevel 1 set "DOCKER_DESKTOP_RUNNING=0"







if "%DOCKER_DESKTOP_RUNNING%"=="0" (







    echo [INFO] Starting Docker Desktop...



    start "" "%DOCKER_DESKTOP_EXE%"







    timeout /t 2 /nobreak >nul



    tasklist /FI "IMAGENAME eq Docker Desktop.exe" | find /I "Docker Desktop.exe" >nul 2>&1



    if errorlevel 1 (



        echo [WARN] Docker Desktop.exe process not seen. If Docker does not start - open Docker Desktop manually.



    ) else (



        echo [INFO] Docker Desktop.exe process started.



    )







    tasklist /FI "IMAGENAME eq com.docker.backend.exe" | find /I "com.docker.backend.exe" >nul 2>&1



    if errorlevel 1 (



        echo [INFO] Docker backend is still starting.



    ) else (



        echo [INFO] Docker backend process detected.



    )



)







if "%DOCKER_DESKTOP_RUNNING%"=="1" (



    echo [INFO] Docker Desktop is already running.



)















echo [8/10] Waiting for Docker to start (up to 5 minutes)...







set /a WAIT_RETRIES=0







:wait_docker







docker info >nul 2>&1







if errorlevel 1 (







    set /a WAIT_RETRIES+=1



    if !WAIT_RETRIES! EQU 1 echo [INFO] Waiting for Docker daemon...



    if !WAIT_RETRIES! EQU 5 (



        echo [INFO] Docker daemon still unavailable. Restarting Docker Desktop...



        start "" "%DOCKER_DESKTOP_EXE%" >nul 2>&1



    )



    if !WAIT_RETRIES! EQU 30 (



        echo [INFO] Retrying Docker Desktop launch...



        start "" "%DOCKER_DESKTOP_EXE%" >nul 2>&1



    )



    if !WAIT_RETRIES! EQU 20 echo [INFO] Docker is still starting... about 1 minute.



    if !WAIT_RETRIES! EQU 40 echo [INFO] Docker is still starting... about 2 minutes.



    if !WAIT_RETRIES! EQU 60 echo [INFO] Docker is still starting... about 3 minutes.



    if !WAIT_RETRIES! EQU 80 echo [INFO] Docker is still starting... about 4 minutes.







    if !WAIT_RETRIES! GEQ 100 (







        echo [ERROR] Docker did not start within 5 minutes.







        echo Open Docker Desktop manually, wait for Running status and re-run install.bat.







        call :maybe_pause







        exit /b 1







    )







    call :progressbar "Docker daemon" !WAIT_RETRIES! 100 quiet



    timeout /t 3 /nobreak >nul







    goto wait_docker







)







echo [OK] Docker daemon available.















echo [9/10] Preparing n8n Docker image...



docker image inspect "%N8N_IMAGE%" >nul 2>&1



if errorlevel 1 (



    if exist "%N8N_IMAGE_TAR%" (



        echo [INFO] Local image found: "%N8N_IMAGE_TAR%"



        echo [INFO] Loading via docker load...



        docker load -i "%N8N_IMAGE_TAR%"



        if errorlevel 1 (



            echo [ERROR] Failed to load the local tar image.



            call :maybe_pause



            exit /b 1



        )



    ) else (



        echo [INFO] Local tar image not found.



        echo [INFO] Pulling "%N8N_IMAGE%" from Docker Hub...



        docker pull "%N8N_IMAGE%"



        if errorlevel 1 (



            echo [ERROR] Failed to pull n8n image from Docker Hub.



            call :maybe_pause



            exit /b 1



        )



    )



) else (



    echo [INFO] Image "%N8N_IMAGE%" already present locally.



)







echo [10/10] Starting n8n...







call "%BASE_DIR%start.bat"



if errorlevel 1 (



    echo.



    echo [FAIL] start.bat exited with an error. Check the messages above.



    call :maybe_pause



    exit /b 1



)















echo.







echo [PASS] Install and start finished successfully.







call :maybe_pause







exit /b 0









:maybe_pause

if "%AUTO_REUSE%"=="1" (

  echo [INFO] --auto-reuse: no keypress required ^(GUI^).

  timeout /t 1 /nobreak >nul

  goto :maybe_pause_end

)

if "%SKIP_PAUSE%"=="1" (

  echo [INFO] GUI runner: no keypress required.

  timeout /t 1 /nobreak >nul

  goto :maybe_pause_end

)

pause

:maybe_pause_end

exit /b 0





:progressbar



set "PB_LABEL=%~1"



set /a PB_CUR=%~2



set /a PB_MAX=%~3



if %PB_MAX% LEQ 0 set /a PB_MAX=1



set /a PB_PCT=(PB_CUR*100)/PB_MAX



if %PB_PCT% GTR 100 set /a PB_PCT=100

if /I "%~4"=="quiet" (
  set /a PB_STEP=!PB_MAX!/4
  if !PB_STEP! LSS 1 set /a PB_STEP=1
  if not !PB_CUR! EQU 1 (
    set /a PB_MOD=!PB_CUR! %% !PB_STEP!
    if not !PB_MOD! EQU 0 exit /b 0
  )
)

set /a PB_FILLED=(PB_PCT*20)/100



set "PB_BAR="



for /L %%I in (1,1,20) do (



    if %%I LEQ !PB_FILLED! (



        set "PB_BAR=!PB_BAR!#"



    ) else (



        set "PB_BAR=!PB_BAR!."



    )



)



echo [WAIT] !PB_LABEL! [!PB_BAR!] !PB_PCT!%%



exit /b 0




REM =========================================================================
REM   :ensure_tools  - download Docker installer + ngrok if missing
REM =========================================================================
:ensure_tools
if not exist "%TOOLS_DIR%" mkdir "%TOOLS_DIR%"

REM --- Docker Desktop ------------------------------------------------------
set "DOCKER_FOUND="
if exist "%TOOLS_DIR%\DockerDesktopInstaller.exe"    set "DOCKER_FOUND=%TOOLS_DIR%\DockerDesktopInstaller.exe"
if exist "%TOOLS_DIR%\Docker Desktop Installer.exe"  set "DOCKER_FOUND=%TOOLS_DIR%\Docker Desktop Installer.exe"
docker --version >nul 2>&1
if not errorlevel 1 set "DOCKER_FOUND=already-installed"

REM Also treat Docker as "installed" if Program Files has it (PATH may not yet be updated)
if not defined DOCKER_FOUND if exist "%ProgramFiles%\Docker\Docker\Docker Desktop.exe" set "DOCKER_FOUND=program-files"

if not defined DOCKER_FOUND (
    echo [INFO] Docker Desktop not found.
    REM --- try winget first: official Microsoft channel, bypasses CDN/proxy issues ---
    where winget >nul 2>&1
    if not errorlevel 1 (
        echo [INFO] Installing Docker Desktop via winget ^(official Microsoft channel^)...
        echo [INFO] About 600 MB, will take a few minutes. Progress appears below.
        winget install --id Docker.DockerDesktop -e --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
        if not errorlevel 1 (
            echo [OK] Docker Desktop installed via winget.
            echo.
            echo [ACTION REQUIRED] Docker Desktop installed.
            echo If Windows asks for a reboot - reboot and run Install again.
            echo [NEXT] After restarting Install [Admin] - ngrok, .env and n8n will follow.
            exit /b 2
        )
        echo [WARN] winget could not install Docker. Trying direct download...
    )
    REM --- fallback: manual download of Docker Desktop Installer ---
    set "DL_DOCKER=Y"
    if not "%AUTO_REUSE%"=="1" if not "%SKIP_PAUSE%"=="1" (
        set /p DL_DOCKER=Download Docker Desktop Installer from docker.com ^(~600 MB^)? Y/N [Y]: 
        if "!DL_DOCKER!"=="" set "DL_DOCKER=Y"
    )
    if /I "!DL_DOCKER!"=="Y" (
        set "DOCKER_URL=https://desktop.docker.com/win/main/amd64/Docker%%20Desktop%%20Installer.exe"
        set "DOCKER_OUT=%TOOLS_DIR%\Docker Desktop Installer.exe"
        echo [INFO] Downloading Docker Desktop Installer...
        echo [INFO] URL: !DOCKER_URL!
        call :download_file "!DOCKER_URL!" "!DOCKER_OUT!"
        if errorlevel 1 (
            echo [ERROR] Failed to download the Docker installer.
            echo         Check your internet connection or download manually:
            echo         https://www.docker.com/products/docker-desktop/
            echo         and put the file into: %TOOLS_DIR%
            exit /b 1
        )
        set "DOCKER_INSTALLER=!DOCKER_OUT!"
        echo [OK] Docker installer ready.
    ) else (
        echo [ERROR] Docker Desktop Installer.exe is required in %TOOLS_DIR%\
        exit /b 1
    )
)

REM --- ngrok ---------------------------------------------------------------
set "NGROK_FOUND="
if exist "%NGROK_EXE%" set "NGROK_FOUND=%NGROK_EXE%"
if not defined NGROK_FOUND (
    for /f "delims=" %%I in ('where ngrok.exe 2^>nul') do (
        set "NGROK_FOUND=%%~fI"
        goto :ngrok_found_in_path
    )
)
:ngrok_found_in_path

if not defined NGROK_FOUND (
    echo [INFO] ngrok.exe not found in tools\ or PATH.
    set "DL_NGROK=Y"
    if not "%AUTO_REUSE%"=="1" if not "%SKIP_PAUSE%"=="1" (
        set /p DL_NGROK=Download ngrok v3 ^(~15 MB^)? Y/N [Y]: 
        if "!DL_NGROK!"=="" set "DL_NGROK=Y"
    )
    if /I not "!DL_NGROK!"=="Y" (
        echo [ERROR] ngrok.exe required in %TOOLS_DIR%\ or in PATH.
        echo         Download manually: https://ngrok.com/download
        exit /b 1
    )
    set "NGROK_URL=https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-windows-amd64.zip"
    set "NGROK_ZIP=%TOOLS_DIR%\ngrok.zip"
    echo [INFO] Downloading ngrok...
    call :download_file "!NGROK_URL!" "!NGROK_ZIP!"
    if errorlevel 1 (
        echo [ERROR] Failed to download ngrok.
        exit /b 1
    )
    echo [INFO] Unpacking ngrok...
    powershell -NoProfile -Command "Expand-Archive -Force -LiteralPath '!NGROK_ZIP!' -DestinationPath '%TOOLS_DIR%'"
    del /f /q "!NGROK_ZIP!" >nul 2>&1
    if not exist "%TOOLS_DIR%\ngrok.exe" (
        echo [ERROR] ngrok.exe not found after unpacking.
        exit /b 1
    )
    set "NGROK_EXE=%TOOLS_DIR%\ngrok.exe"
    echo [OK] ngrok ready.
)
exit /b 0


REM =========================================================================
REM   :download_file %1=URL  %2=output-path
REM   tries curl first, falls back to PowerShell Invoke-WebRequest
REM =========================================================================
:download_file
set "DL_URL=%~1"
set "DL_OUT=%~2"
set "DL_UA=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"
where curl.exe >nul 2>&1
if not errorlevel 1 (
    curl.exe -L --fail --retry 3 --connect-timeout 20 --noproxy "*" --progress-bar -A "%DL_UA%" -o "%DL_OUT%" "%DL_URL%"
    if not errorlevel 1 exit /b 0
    echo [WARN] curl failed, trying PowerShell Invoke-WebRequest...
)
powershell -NoProfile -Command "$ProgressPreference='SilentlyContinue'; [System.Net.WebRequest]::DefaultWebProxy = $null; try { Invoke-WebRequest -Uri $env:DL_URL -OutFile $env:DL_OUT -UserAgent $env:DL_UA -UseBasicParsing -ErrorAction Stop; exit 0 } catch { Write-Host $_.Exception.Message }; try { Start-BitsTransfer -Source $env:DL_URL -Destination $env:DL_OUT -ErrorAction Stop; exit 0 } catch { Write-Host ('BITS: ' + $_.Exception.Message); exit 1 }"
exit /b %ERRORLEVEL%



