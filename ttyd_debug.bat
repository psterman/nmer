@echo on
setlocal EnableExtensions EnableDelayedExpansion

rem 1) Elevate to admin if needed
:checkPrivileges
net session >nul 2>&1
if %errorlevel%==0 goto gotPrivileges

echo [INFO] Requesting administrator privileges...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -Verb RunAs -FilePath '%~f0' -WorkingDirectory '%~dp0'"
exit /b

:gotPrivileges
cd /d "%~dp0"

rem 2) Config
set "TTYD_EXE=%~dp0ttyd.exe"
set "PORT=7681"

echo ========================================
echo          ttyd launcher (Admin)
echo ========================================

rem 3) Check port usage
set "PID="
set "PNAME="
for /f %%P in ('powershell -NoProfile -Command "$p=(Get-NetTCPConnection -State Listen -LocalPort %PORT% -ErrorAction SilentlyContinue ^| Select-Object -First 1 -ExpandProperty OwningProcess); if($p){Write-Output $p}"') do set "PID=%%P"

if defined PID (
    for /f %%N in ('powershell -NoProfile -Command "try{(Get-Process -Id %PID% -ErrorAction Stop).ProcessName}catch{}"') do set "PNAME=%%N"

    if /I "!PNAME!"=="ttyd" (
        echo [INFO] ttyd is already running on 127.0.0.1:%PORT%
        echo [URL ] http://127.0.0.1:%PORT%
        pause
        exit /b 0
    )

    echo [WARN] Port %PORT% is occupied by process !PNAME! ^(PID: %PID%^).
    echo [WARN] Please free the port and try again.
    pause
    exit /b 1
)

rem 4) Check file exists
if not exist "%TTYD_EXE%" (
    echo [ERROR] Missing ttyd executable: %TTYD_EXE%
    pause
    exit /b 1
)

rem 5) Start ttyd
echo [OK  ] Starting ttyd...
echo [URL ] http://127.0.0.1:%PORT%
echo [INFO] Press Ctrl+C to stop
echo ----------------------------------------

"%TTYD_EXE%" -p %PORT% -i 127.0.0.1 -W -t fontSize=14 -w "%cd%" cmd.exe

pause
