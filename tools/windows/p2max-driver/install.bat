@echo off
REM ---------------------------------------------------------------------------
REM  P2 Max driver installer  (one-time, ~10 seconds)
REM
REM  1. Plug the P2 Max / P3 Lite camera in.
REM  2. Right-click this file -> "Run as administrator".
REM  3. Done. Open the web viewer and click "Connect camera".
REM
REM  After this, Windows binds WinUSB to the camera automatically on every
REM  plug-in. No further steps, no extra software.
REM ---------------------------------------------------------------------------

REM Relaunch elevated if not already running as admin.
net session >nul 2>&1 || (
    echo Requesting administrator rights...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

setlocal
set "INF=%~dp0p2max.inf"

echo.
echo  Thermal Master P2 Max - WinUSB binder
echo  -------------------------------------
if not exist "%INF%" (
    echo  ERROR: p2max.inf not found next to this script.
    goto :fail
)

echo  Installing WinUSB driver for VID_3474^&PID_42B2 ...
pnputil /add-driver "%INF%" /install
set "RC=%errorlevel%"

echo.
if "%RC%"=="0" (
    echo  SUCCESS. The camera is now ready.
    echo  Open the web viewer in Chrome/Edge and click "Connect camera".
) else (
    echo  pnputil returned code %RC%.
    echo.
    echo  If you saw a "driver not signed" / publisher warning, your machine is
    echo  not in Test Mode. Two easy fixes:
    echo.
    echo   A) Run  enable-testmode.bat  once (admin), reboot, then run this again.
    echo      (Test Mode is what already lets your P3 camera work driver-less.)
    echo.
    echo   B) Or just use Zadig: open it, select "P2 Max", choose WinUSB,
    echo      click Install/Replace. One minute, no reboot.
    echo.
)
echo  Press any key to close.
pause >nul
exit /b %RC%

:fail
echo  Press any key to close.
pause >nul
exit /b 1
