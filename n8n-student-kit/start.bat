@echo off







setlocal EnableExtensions EnableDelayedExpansion







chcp 65001 >nul















title n8n Student Kit - Start















set "BASE_DIR=%~dp0"







set "STATE_DIR=%BASE_DIR%state"







set "COMPOSE_DIR=%BASE_DIR%compose"







set "CONFIG_FILE=%STATE_DIR%\install.cfg"







set "ENV_FILE=%STATE_DIR%\.env"







set "NGROK_EXE=%BASE_DIR%tools\ngrok.exe"



set "DOCKER_DESKTOP_EXE=C:\Program Files\Docker\Docker\Docker Desktop.exe"



set "OPEN_BROWSER=1"



if /I "%~1"=="--no-browser" set "OPEN_BROWSER=0"















if not exist "%CONFIG_FILE%" (







    echo [ERROR] Config not found. Run install.bat first.







    call :gui_pause







    exit /b 1







)















for /f "usebackq tokens=1,* delims==" %%A in ("%CONFIG_FILE%") do (







    set "%%A=%%B"







)















if not exist "%ENV_FILE%" (







    echo [ERROR] File state\.env not found. Run install.bat.







    call :gui_pause







    exit /b 1







)















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







    call :gui_pause







    exit /b 1







)







echo [INFO] Using ngrok: "%NGROK_EXE%"















echo ========================







echo n8n Student Kit - Start







echo ========================







echo.















echo [1/5] Starting Docker Desktop...







docker desktop status >nul 2>&1







if errorlevel 1 (







    start "" "%DOCKER_DESKTOP_EXE%"







)















echo [2/5] Waiting for Docker (up to 5 minutes)...







set /a WAIT_RETRIES=0







:wait_docker







docker info >nul 2>&1







if errorlevel 1 (







    set /a WAIT_RETRIES+=1



    if !WAIT_RETRIES! EQU 5 (



        echo [INFO] Docker daemon still unavailable. Restarting Docker Desktop...



        start "" "%DOCKER_DESKTOP_EXE%" >nul 2>&1



    )



    if !WAIT_RETRIES! EQU 30 (



        echo [INFO] Retrying Docker Desktop launch...



        start "" "%DOCKER_DESKTOP_EXE%" >nul 2>&1



    )







    if !WAIT_RETRIES! GEQ 100 (







        echo [ERROR] Docker did not start within 5 minutes.







        echo Open Docker Desktop manually, wait for Running status and re-run start.bat.







        call :gui_pause







        exit /b 1







    )







    call :progressbar "Docker daemon" !WAIT_RETRIES! 100 quiet



    timeout /t 3 /nobreak >nul







    goto wait_docker







)



echo [OK] Docker daemon available.















echo [3/6] Starting n8n via docker compose...







set "SKIP_COMPOSE=0"



set "EXISTING_N8N_STATUS="



for /f "usebackq delims=" %%S in (`docker inspect -f "{{.State.Status}}" n8n 2^>nul`) do set "EXISTING_N8N_STATUS=%%S"



if defined EXISTING_N8N_STATUS (



    if /I "!EXISTING_N8N_STATUS!"=="running" (



        echo [INFO] Container "n8n" already running. Skipping docker compose up.



        set "SKIP_COMPOSE=1"



    ) else (



        echo [INFO] Found stopped container "n8n". Removing it to avoid conflict...



        docker rm n8n >nul 2>&1



    )



)







if "%SKIP_COMPOSE%"=="0" (



    pushd "%COMPOSE_DIR%"







    docker compose --env-file ..\state\.env up -d







    if errorlevel 1 (







        echo [ERROR] Failed to bring up n8n.







        popd







        call :gui_pause







        exit /b 1







    )







    popd



)







echo [4/6] Waiting for local n8n (up to 2 minutes)...



set /a N8N_RETRIES=0



:wait_n8n



curl -s -o nul --max-time 2 http://127.0.0.1:5678/ >nul 2>&1



if errorlevel 1 (



    set /a N8N_RETRIES+=1



    if !N8N_RETRIES! GEQ 40 (



        echo [ERROR] n8n did not respond on http://127.0.0.1:5678 within 2 minutes.



        echo Check docker logs n8n and re-run start.bat.



        call :gui_pause



        exit /b 1



    )



    call :progressbar "Local n8n" !N8N_RETRIES! 40 quiet



    timeout /t 3 /nobreak >nul



    goto wait_n8n



)



echo [OK] n8n responds locally.







echo [5/6] Stopping previous ngrok...







taskkill /F /FI "WINDOWTITLE eq n8n-kit-ngrok*" >nul 2>&1















echo [6/6] Starting ngrok...







start "n8n-kit-ngrok" "%NGROK_EXE%" http 5678 --url=%NGROK_DOMAIN%







timeout /t 3 /nobreak >nul



tasklist /FI "IMAGENAME eq ngrok.exe" | find /I "ngrok.exe" >nul 2>&1



if errorlevel 1 (



    echo [ERROR] ngrok process did not start.



    echo Check the token/domain or run manually: "%NGROK_EXE%" http 5678 --url=%NGROK_DOMAIN%



    call :gui_pause



    exit /b 1



)















set /a NGROK_RETRIES=0







:wait_ngrok







curl -s http://127.0.0.1:4040/api/tunnels | findstr /I "\"url\"" >nul 2>&1







if errorlevel 1 (







    set /a NGROK_RETRIES+=1







    if !NGROK_RETRIES! GEQ 20 (







        echo [WARN] ngrok API on 127.0.0.1:4040 did not respond within 60 seconds.



        echo [WARN] Continuing n8n launch. If the public URL does not open - check ngrok manually.



        goto ngrok_ready







    )







    call :progressbar "ngrok API" !NGROK_RETRIES! 20 quiet



    timeout /t 3 /nobreak >nul







    goto wait_ngrok







)







echo [INFO] ngrok tunnel active.



:ngrok_ready















echo.







echo Local:  http://localhost:5678







echo Public: https://%NGROK_DOMAIN%/







if "%OPEN_BROWSER%"=="1" (



    start "" "https://%NGROK_DOMAIN%/"



) else (



    echo [INFO] --no-browser: auto-opening the browser skipped.



)







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











:gui_pause

if "%SKIP_PAUSE%"=="1" (

  echo [INFO] GUI: no keypress required.

  timeout /t 1 /nobreak >nul

  goto :gui_pause_end

)

pause

:gui_pause_end

exit /b 0

