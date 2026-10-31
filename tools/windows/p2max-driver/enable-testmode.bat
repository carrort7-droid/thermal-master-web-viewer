@echo off
REM ---------------------------------------------------------------------------
REM  Enable Windows Test Mode (one-time, requires a reboot).
REM
REM  Your machine already runs self-signed libwdi drivers for the P3 camera,
REM  which means Test Mode is very likely already on. This script is only needed
REM  if install.bat reported a signature error.
REM
REM  Test Mode lets Windows load the P2 Max WinUSB binding without a paid
REM  WHQL signature. Run once, reboot, then run install.bat again.
REM ---------------------------------------------------------------------------
net session >nul 2>&1 || (
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
bcdedit /set testsigning on
echo.
echo  Test Mode enabled. Reboot your PC, then run install.bat again.
echo  (You can turn it off later with: bcdedit /set testsigning off)
pause
