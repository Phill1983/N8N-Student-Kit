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







    echo [ERROR] Конфіг не знайдено. Спочатку запусти install.bat







    call :gui_pause







    exit /b 1







)















for /f "usebackq tokens=1,* delims==" %%A in ("%CONFIG_FILE%") do (







    set "%%A=%%B"







)















if not exist "%ENV_FILE%" (







    echo [ERROR] Файл state\.env не знайдено. Запусти install.bat







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







    echo [ERROR] Не знайдено tools\ngrok.exe







    echo Додай офіційний ngrok.exe у папку tools або встанови ngrok у PATH.







    call :gui_pause







    exit /b 1







)







echo [INFO] Використовую ngrok: "%NGROK_EXE%"















echo ========================







echo n8n Student Kit - Start







echo ========================







echo.















echo [1/5] Запуск Docker Desktop...







docker desktop status >nul 2>&1







if errorlevel 1 (







    start "" "%DOCKER_DESKTOP_EXE%"







)















echo [2/5] Очікування Docker (до 5 хвилин)...







set /a WAIT_RETRIES=0







:wait_docker







docker info >nul 2>&1







if errorlevel 1 (







    set /a WAIT_RETRIES+=1



    if !WAIT_RETRIES! EQU 5 (



        echo [INFO] Docker daemon ще недоступний. Повторно запускаю Docker Desktop...



        start "" "%DOCKER_DESKTOP_EXE%" >nul 2>&1



    )



    if !WAIT_RETRIES! EQU 30 (



        echo [INFO] Повторна спроба запуску Docker Desktop...



        start "" "%DOCKER_DESKTOP_EXE%" >nul 2>&1



    )







    if !WAIT_RETRIES! GEQ 100 (







        echo [ERROR] Docker не запустився за 5 хвилин.







        echo Відкрий Docker Desktop вручну, дочекайся статусу Running і повтори start.bat.







        call :gui_pause







        exit /b 1







    )







    call :progressbar "Docker daemon" !WAIT_RETRIES! 100 quiet



    timeout /t 3 /nobreak >nul







    goto wait_docker







)



echo [OK] Docker daemon доступний.















echo [3/6] Запуск n8n через docker compose...







set "SKIP_COMPOSE=0"



set "EXISTING_N8N_STATUS="



for /f "usebackq delims=" %%S in (`docker inspect -f "{{.State.Status}}" n8n 2^>nul`) do set "EXISTING_N8N_STATUS=%%S"



if defined EXISTING_N8N_STATUS (



    if /I "!EXISTING_N8N_STATUS!"=="running" (



        echo [INFO] Контейнер "n8n" вже запущений. Пропускаю docker compose up.



        set "SKIP_COMPOSE=1"



    ) else (



        echo [INFO] Знайдено зупинений контейнер "n8n". Видаляю, щоб уникнути конфлікту...



        docker rm n8n >nul 2>&1



    )



)







if "%SKIP_COMPOSE%"=="0" (



    pushd "%COMPOSE_DIR%"







    docker compose --env-file ..\state\.env up -d







    if errorlevel 1 (







        echo [ERROR] Не вдалося підняти n8n







        popd







        call :gui_pause







        exit /b 1







    )







    popd



)







echo [4/6] Очікування локального n8n (до 2 хвилин)...



set /a N8N_RETRIES=0



:wait_n8n



curl -s -o nul --max-time 2 http://127.0.0.1:5678/ >nul 2>&1



if errorlevel 1 (



    set /a N8N_RETRIES+=1



    if !N8N_RETRIES! GEQ 40 (



        echo [ERROR] n8n не відповів на http://127.0.0.1:5678 за 2 хвилини.



        echo Перевір docker logs n8n і повтори start.bat.



        call :gui_pause



        exit /b 1



    )



    call :progressbar "Local n8n" !N8N_RETRIES! 40 quiet



    timeout /t 3 /nobreak >nul



    goto wait_n8n



)



echo [OK] n8n відповідає локально.







echo [5/6] Зупинка старого ngrok...







taskkill /F /FI "WINDOWTITLE eq n8n-kit-ngrok*" >nul 2>&1















echo [6/6] Запуск ngrok...







start "n8n-kit-ngrok" "%NGROK_EXE%" http 5678 --url=%NGROK_DOMAIN%







timeout /t 3 /nobreak >nul



tasklist /FI "IMAGENAME eq ngrok.exe" | find /I "ngrok.exe" >nul 2>&1



if errorlevel 1 (



    echo [ERROR] ngrok процес не запустився.



    echo Перевір токен/domain або запусти вручну: "%NGROK_EXE%" http 5678 --url=%NGROK_DOMAIN%



    call :gui_pause



    exit /b 1



)















set /a NGROK_RETRIES=0







:wait_ngrok







curl -s http://127.0.0.1:4040/api/tunnels | findstr /I "\"url\"" >nul 2>&1







if errorlevel 1 (







    set /a NGROK_RETRIES+=1







    if !NGROK_RETRIES! GEQ 20 (







        echo [WARN] ngrok API на 127.0.0.1:4040 не відповів за 60 секунд.



        echo [WARN] Продовжую запуск n8n. Якщо публічний URL не відкриється - перевір ngrok вручну.



        goto ngrok_ready







    )







    call :progressbar "ngrok API" !NGROK_RETRIES! 20 quiet



    timeout /t 3 /nobreak >nul







    goto wait_ngrok







)







echo [INFO] ngrok tunnel активний.



:ngrok_ready















echo.







echo Local:  http://localhost:5678







echo Public: https://%NGROK_DOMAIN%/







if "%OPEN_BROWSER%"=="1" (



    start "" "https://%NGROK_DOMAIN%/"



) else (



    echo [INFO] --no-browser: автоматичне відкриття браузера пропущено.



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

  echo [INFO] GUI: без натискання клавіші.

  timeout /t 1 /nobreak >nul

  goto :gui_pause_end

)

pause

:gui_pause_end

exit /b 0

