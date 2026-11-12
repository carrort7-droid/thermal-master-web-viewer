@echo off
setlocal
title Thermal Master P2 MAX - one-time driver setup

net session >nul 2>&1
if not "%errorlevel%"=="0" (
  echo.
  echo  Administrator permission is needed to install the camera driver.
  echo  Requesting it now...
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

set "DIR=%TEMP%\p2max-driver"
set "BASE=https://carrort7-droid.github.io/thermal-master-web-viewer/driver"

echo.
echo  Thermal Master P2 MAX ^(P3 Lite^) - WinUSB driver setup
echo  -----------------------------------------------------
if not exist "%DIR%" mkdir "%DIR%"

echo  Downloading installer files...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $b='%BASE%'; $d='%DIR%'; foreach($f in 'install.ps1','dpscat.exe','p2max.inf'){ Invoke-WebRequest -UseBasicParsing -Uri ($b+'/'+$f) -OutFile (Join-Path $d $f) }"
if not "%errorlevel%"=="0" (
  echo.
  echo  [FAIL] Could not download the installer. Check your connection.
  goto :done
)

echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%DIR%\install.ps1"
set "RC=%ERRORLEVEL%"

echo.
if "%RC%"=="0" echo [OK]   Driver ready. Go back to the web page and click "Connect camera".
if "%RC%"=="3" echo [WAIT] Camera not found. Plug the camera in, then run this again.
if "%RC%"=="1" echo [FAIL] Setup failed. See C:\ProgramData\P2MaxDriver\install.log

:done
echo.
echo Press any key to close this window.
pause >nul
