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



        echo [ERROR] Права адміністратора не отримано ^(UAC скасовано або заблоковано політикою^).



        echo Відкрий CMD як адміністратор і запусти:



        echo        "%~f0" --elevated



        call :maybe_pause



        exit /b 1



    )



    >"%LOG_FILE%" echo [INFO] Requested elevation at %date% %time%



    echo [INFO] Потрібні права адміністратора. Запитую UAC...



    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -Verb RunAs -FilePath 'cmd.exe' -ArgumentList '/k ""%~f0"" !RELAUNCH_ARGS!'"



    if errorlevel 1 (



        echo [WARN] PowerShell RunAs не спрацював. Пробую fallback...



        mshta "javascript:var sh=new ActiveXObject('Shell.Application'); sh.ShellExecute('cmd.exe','/k ""%~f0"" --elevated','','runas',1);close();"



    )



    echo [INFO] Якщо нове адмін-вікно не відкрилось, відкрий CMD як адміністратор і запусти:



    echo        "%~f0" --elevated



    echo [INFO] Лог запуску: "%LOG_FILE%"



    call :maybe_pause



    exit /b 1



)















echo ==========================================







echo n8n Student Kit - First Install / Repair







echo ==========================================







echo.















net session >nul 2>&1



if errorlevel 1 (



    echo [WARN] Не вдалося перевірити права через net session. Продовжую...



)















if exist "%CONFIG_FILE%" (







    echo [1/10] Знайдено існуючу конфігурацію.



    if "%AUTO_REUSE%"=="1" (



        echo [INFO] --auto-reuse активний. Використовую існуючу конфігурацію.



        goto load_config



    )







    set /p REUSE_CONFIG=Використати її? ^(Y/N, за замовчуванням Y^): 







    if /I "%REUSE_CONFIG%"=="N" goto collect_config







    if /I "%REUSE_CONFIG%"=="NO" goto collect_config







    goto load_config







)















:collect_config







echo [1/10] Введення параметрів...







set /p INSTALL_DRIVE=На який диск зберігати дані n8n? (наприклад C або D): 







if "%INSTALL_DRIVE%"=="" set "INSTALL_DRIVE=C"















set "N8N_DATA=%INSTALL_DRIVE%:\n8n-data"







if not exist "%N8N_DATA%" mkdir "%N8N_DATA%"















set /p NGROK_DOMAIN=Введи ваш постійний ngrok domain: 







if "%NGROK_DOMAIN%"=="" (







    echo [ERROR] NGROK_DOMAIN не може бути пустим.







    call :maybe_pause







    exit /b 1







)















set /p NGROK_AUTHTOKEN=Введи ngrok authtoken: 







if "%NGROK_AUTHTOKEN%"=="" (







    echo [ERROR] NGROK_AUTHTOKEN не може бути пустим.







    call :maybe_pause







    exit /b 1







)















set /p N8N_BASIC_AUTH_USER=Введи логін для n8n basic auth: 







if "%N8N_BASIC_AUTH_USER%"=="" (







    echo [ERROR] Логін не може бути пустим.







    call :maybe_pause







    exit /b 1







)















set /p N8N_BASIC_AUTH_PASSWORD=Введи пароль для n8n basic auth: 







if "%N8N_BASIC_AUTH_PASSWORD%"=="" (







    echo [ERROR] Пароль не може бути пустим.







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







echo [1/10] Завантажую існуючу конфігурацію...







for /f "usebackq tokens=1,* delims==" %%A in ("%CONFIG_FILE%") do (







    set "%%A=%%B"







)















if "%N8N_BASIC_AUTH_USER%"=="" (







    set /p N8N_BASIC_AUTH_USER=Введи логін для n8n basic auth: 







)







if "%N8N_BASIC_AUTH_PASSWORD%"=="" (







    set /p N8N_BASIC_AUTH_PASSWORD=Введи пароль для n8n basic auth: 







)















:after_load

echo [1b/10] Перевірка локальних тулів (Docker installer, ngrok)...
call :ensure_tools
if errorlevel 1 (
    call :maybe_pause
    exit /b 1
)

echo [2/10] Перевірка WSL...







wsl --version >nul 2>&1







if errorlevel 1 (







    echo [WARN] WSL не знайдено або недоступний.







    echo Спробую увімкнути необхідні компоненти Windows...







    dism /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart







    dism /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart







    echo.







    echo [ACTION REQUIRED] Потрібне перезавантаження Windows.







    call :maybe_pause







    exit /b 0







)















echo [3/10] Перевірка Docker Desktop...







docker --version >nul 2>&1







if not errorlevel 1 (







    echo [INFO] Docker CLI вже є в PATH — інсталятор з tools\ не запускаю.





    echo [INFO] У диспетчері шукай Docker Desktop.exe або com.docker.backend, не Docker Desktop Installer.exe.





    echo [INFO] Останній рядок — норма: інсталятор з папки tools потрібен лише якщо docker ще не встановлений.





)







if errorlevel 1 (







    if not exist "%DOCKER_INSTALLER%" (







        echo [ERROR] Не знайдено Docker installer у папці tools.







        echo Підтримувані назви: DockerDesktopInstaller.exe або Docker Desktop Installer.exe







        call :maybe_pause







        exit /b 1







    )















    echo Встановлюю Docker Desktop...







    echo [INFO] Запуск: "%DOCKER_INSTALLER%" install --quiet --accept-license







    echo [INFO] Без --accept-license тиха інсталяція часто "висне" на умовах ліцензії.







    echo [INFO] Тиха інсталяція зазвичай 2-5 хв; консоль при цьому не оновлюється - це нормально.







    echo [INFO] Процеси Docker до запуску інсталятора ^(якщо порожньо — ще не стартував^):







    tasklist 2>nul | findstr /I /C:"Docker Desktop" /C:"com.docker" /C:"DockerDesktop"







    echo [INFO] Запускаю: має з’явитись Docker Desktop Installer.exe ^(інколи лише на 1–2 хв^).







    echo [WAIT] Далі пауза без нових рядків - нормально. Наступний рядок у лозі тільки після виходу інсталятора ^(зазвичай кілька хвилин^).







    start /wait "" "%DOCKER_INSTALLER%" install --quiet --accept-license







    echo [INFO] Інсталятор завершився, код: !ERRORLEVEL!







    echo [INFO] Процеси Docker після інсталятора:







    tasklist 2>nul | findstr /I /C:"Docker Desktop" /C:"com.docker" /C:"DockerDesktop"





















    echo.







    echo [ACTION REQUIRED] Docker Desktop встановлено.







    echo Якщо система попросить перезавантаження - перезавантаж ПК і знову запусти install.bat



    echo [NEXT] Після цього знову запусти Install [Admin] або install.bat --auto-reuse - тоді підуть ngrok, .env і n8n. Кнопку Start натискай лише коли вже є state\.env [після повного install].








    call :maybe_pause







    exit /b 0







)







for /f "tokens=1,* delims=:" %%A in ('docker --version 2^>nul') do set "DOCKER_VERSION_LINE=%%A:%%B"



if defined DOCKER_VERSION_LINE echo [INFO] Знайдено Docker CLI: !DOCKER_VERSION_LINE!







docker info >nul 2>&1



if errorlevel 1 (



    echo [INFO] Docker daemon поки не доступний. Це нормально після встановлення.



    echo [INFO] Спробую запустити Docker Desktop і дочекатися ready стану.



) else (



    echo [INFO] Docker daemon уже доступний.



)















echo [4/10] Перевірка ngrok...



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







    call :maybe_pause







    exit /b 1







)







echo [INFO] Використовую ngrok: "%NGROK_EXE%"















echo [5/10] Налаштування ngrok...







"%NGROK_EXE%" config add-authtoken %NGROK_AUTHTOKEN%







if errorlevel 1 (







    echo [ERROR] Не вдалося додати ngrok authtoken.







    call :maybe_pause







    exit /b 1







)















echo [6/10] Створення .env...







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















echo [7/10] Тестовий запуск Docker Desktop...







set "DOCKER_DESKTOP_RUNNING=1"



docker desktop status >nul 2>&1



if errorlevel 1 set "DOCKER_DESKTOP_RUNNING=0"







if "%DOCKER_DESKTOP_RUNNING%"=="0" (







    echo [INFO] Запускаю Docker Desktop...



    start "" "%DOCKER_DESKTOP_EXE%"







    timeout /t 2 /nobreak >nul



    tasklist /FI "IMAGENAME eq Docker Desktop.exe" | find /I "Docker Desktop.exe" >nul 2>&1



    if errorlevel 1 (



        echo [WARN] Не бачу процесу Docker Desktop.exe. Якщо Docker не підніметься - відкрий Docker Desktop вручну.



    ) else (



        echo [INFO] Процес Docker Desktop.exe запущено.



    )







    tasklist /FI "IMAGENAME eq com.docker.backend.exe" | find /I "com.docker.backend.exe" >nul 2>&1



    if errorlevel 1 (



        echo [INFO] Backend Docker ще стартує.



    ) else (



        echo [INFO] Backend Docker процес виявлено.



    )



)







if "%DOCKER_DESKTOP_RUNNING%"=="1" (



    echo [INFO] Docker Desktop уже запущений.



)















echo [8/10] Очікую запуск Docker (до 5 хвилин)...







set /a WAIT_RETRIES=0







:wait_docker







docker info >nul 2>&1







if errorlevel 1 (







    set /a WAIT_RETRIES+=1



    if !WAIT_RETRIES! EQU 1 echo [INFO] Очікую Docker daemon...



    if !WAIT_RETRIES! EQU 5 (



        echo [INFO] Docker daemon ще недоступний. Повторно запускаю Docker Desktop...



        start "" "%DOCKER_DESKTOP_EXE%" >nul 2>&1



    )



    if !WAIT_RETRIES! EQU 30 (



        echo [INFO] Повторна спроба запуску Docker Desktop...



        start "" "%DOCKER_DESKTOP_EXE%" >nul 2>&1



    )



    if !WAIT_RETRIES! EQU 20 echo [INFO] Docker ще стартує... приблизно 1 хвилина.



    if !WAIT_RETRIES! EQU 40 echo [INFO] Docker ще стартує... приблизно 2 хвилини.



    if !WAIT_RETRIES! EQU 60 echo [INFO] Docker ще стартує... приблизно 3 хвилини.



    if !WAIT_RETRIES! EQU 80 echo [INFO] Docker ще стартує... приблизно 4 хвилини.







    if !WAIT_RETRIES! GEQ 100 (







        echo [ERROR] Docker не запустився за 5 хвилин.







        echo Відкрий Docker Desktop вручну, дочекайся статусу Running і повтори install.bat.







        call :maybe_pause







        exit /b 1







    )







    call :progressbar "Docker daemon" !WAIT_RETRIES! 100 quiet



    timeout /t 3 /nobreak >nul







    goto wait_docker







)







echo [OK] Docker daemon доступний.















echo [9/10] Підготовка Docker image n8n...



docker image inspect "%N8N_IMAGE%" >nul 2>&1



if errorlevel 1 (



    if exist "%N8N_IMAGE_TAR%" (



        echo [INFO] Знайдено локальний образ: "%N8N_IMAGE_TAR%"



        echo [INFO] Завантажую через docker load...



        docker load -i "%N8N_IMAGE_TAR%"



        if errorlevel 1 (



            echo [ERROR] Не вдалося завантажити локальний tar образ.



            call :maybe_pause



            exit /b 1



        )



    ) else (



        echo [INFO] Локальний tar образ не знайдено.



        echo [INFO] Завантажую "%N8N_IMAGE%" з Docker Hub...



        docker pull "%N8N_IMAGE%"



        if errorlevel 1 (



            echo [ERROR] Не вдалося завантажити n8n image з Docker Hub.



            call :maybe_pause



            exit /b 1



        )



    )



) else (



    echo [INFO] Образ "%N8N_IMAGE%" вже є локально.



)







echo [10/10] Запуск n8n...







call "%BASE_DIR%start.bat"



if errorlevel 1 (



    echo.



    echo [FAIL] start.bat завершився з помилкою. Перевір повідомлення вище.



    call :maybe_pause



    exit /b 1



)















echo.







echo [PASS] Встановлення і запуск завершено успішно.







call :maybe_pause







exit /b 0









:maybe_pause

if "%AUTO_REUSE%"=="1" (

  echo [INFO] --auto-reuse: без натискання клавіші (GUI).

  timeout /t 1 /nobreak >nul

  goto :maybe_pause_end

)

if "%SKIP_PAUSE%"=="1" (

  echo [INFO] GUI runner: без натискання клавіші.

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

REM --- Docker Desktop Installer --------------------------------------------
set "DOCKER_FOUND="
if exist "%TOOLS_DIR%\DockerDesktopInstaller.exe"    set "DOCKER_FOUND=%TOOLS_DIR%\DockerDesktopInstaller.exe"
if exist "%TOOLS_DIR%\Docker Desktop Installer.exe"  set "DOCKER_FOUND=%TOOLS_DIR%\Docker Desktop Installer.exe"
docker --version >nul 2>&1
if not errorlevel 1 set "DOCKER_FOUND=already-installed"

if not defined DOCKER_FOUND (
    echo [INFO] Docker Desktop Installer не знайдено в tools\.
    set "DL_DOCKER=Y"
    if not "%AUTO_REUSE%"=="1" if not "%SKIP_PAUSE%"=="1" (
        set /p DL_DOCKER=Скачати його з docker.com ^(~600 MB^)? Y/N [Y]: 
        if "!DL_DOCKER!"=="" set "DL_DOCKER=Y"
    )
    if /I "!DL_DOCKER!"=="Y" (
        set "DOCKER_URL=https://desktop.docker.com/win/main/amd64/Docker%%20Desktop%%20Installer.exe"
        set "DOCKER_OUT=%TOOLS_DIR%\Docker Desktop Installer.exe"
        echo [INFO] Завантажую Docker Desktop Installer...
        echo [INFO] URL: !DOCKER_URL!
        call :download_file "!DOCKER_URL!" "!DOCKER_OUT!"
        if errorlevel 1 (
            echo [ERROR] Не вдалося завантажити Docker installer.
            echo         Перевір інтернет-зʼєднання або завантаж вручну:
            echo         https://www.docker.com/products/docker-desktop/
            echo         і поклади файл у: %TOOLS_DIR%
            exit /b 1
        )
        set "DOCKER_INSTALLER=!DOCKER_OUT!"
        echo [OK] Docker installer готовий.
    ) else (
        echo [ERROR] Потрібен Docker Desktop Installer.exe у %TOOLS_DIR%\
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
    echo [INFO] ngrok.exe не знайдено ані в tools\, ані в PATH.
    set "DL_NGROK=Y"
    if not "%AUTO_REUSE%"=="1" if not "%SKIP_PAUSE%"=="1" (
        set /p DL_NGROK=Скачати ngrok v3 ^(~15 MB^)? Y/N [Y]: 
        if "!DL_NGROK!"=="" set "DL_NGROK=Y"
    )
    if /I not "!DL_NGROK!"=="Y" (
        echo [ERROR] Потрібен ngrok.exe у %TOOLS_DIR%\ або в PATH.
        echo         Завантаж вручну: https://ngrok.com/download
        exit /b 1
    )
    set "NGROK_URL=https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-windows-amd64.zip"
    set "NGROK_ZIP=%TOOLS_DIR%\ngrok.zip"
    echo [INFO] Завантажую ngrok...
    call :download_file "!NGROK_URL!" "!NGROK_ZIP!"
    if errorlevel 1 (
        echo [ERROR] Не вдалося завантажити ngrok.
        exit /b 1
    )
    echo [INFO] Розпаковую ngrok...
    powershell -NoProfile -Command "Expand-Archive -Force -LiteralPath '!NGROK_ZIP!' -DestinationPath '%TOOLS_DIR%'"
    del /f /q "!NGROK_ZIP!" >nul 2>&1
    if not exist "%TOOLS_DIR%\ngrok.exe" (
        echo [ERROR] Після розпакування ngrok.exe не знайдено.
        exit /b 1
    )
    set "NGROK_EXE=%TOOLS_DIR%\ngrok.exe"
    echo [OK] ngrok готовий.
)
exit /b 0


REM =========================================================================
REM   :download_file %1=URL  %2=output-path
REM   tries curl first, falls back to PowerShell Invoke-WebRequest
REM =========================================================================
:download_file
set "DL_URL=%~1"
set "DL_OUT=%~2"
where curl.exe >nul 2>&1
if not errorlevel 1 (
    curl.exe -L --fail --retry 3 --connect-timeout 20 --progress-bar -o "%DL_OUT%" "%DL_URL%"
    if not errorlevel 1 exit /b 0
    echo [WARN] curl failed, trying PowerShell...
)
powershell -NoProfile -Command "$ProgressPreference='SilentlyContinue'; try { Invoke-WebRequest -Uri $env:DL_URL -OutFile $env:DL_OUT -UseBasicParsing -ErrorAction Stop } catch { Write-Host $_.Exception.Message; exit 1 }"
exit /b %ERRORLEVEL%



