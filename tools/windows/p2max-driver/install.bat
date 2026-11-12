@echo off
REM ---------------------------------------------------------------------------
REM  P2 MAX / P3 Lite  WinUSB driver setup  (one time, ~15 seconds)
REM
REM  1. Plug the camera in.
REM  2. Double-click this file.
REM  3. Click "Yes" on the UAC prompt.
REM  4. Go back to the web viewer and click "Connect camera".
REM
REM  No reboot, no Test Mode, no Zadig.
REM ---------------------------------------------------------------------------
setlocal
cd /d "%~dp0"

if not exist "%~dp0install.ps1" (
  echo [FAIL] install.ps1 not found next to this file.
  echo        Please unzip the whole folder and run this again.
  goto :done
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
set RC=%ERRORLEVEL%

echo.
if "%RC%"=="0" echo [OK]   Driver ready. Go back to the web page and click "Connect camera".
if "%RC%"=="3" echo [WAIT] Camera not found. Plug the camera in, then run this again.
if "%RC%"=="1" echo [FAIL] Setup failed. See C:\ProgramData\P2MaxDriver\install.log

:done
echo.
echo Press any key to close this window.
pause >nul
