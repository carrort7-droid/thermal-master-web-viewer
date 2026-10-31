#!/usr/bin/env python3
"""Generate a self-contained p2max-setup.bat that embeds the WinUSB INF
inline (base64) so the user downloads ONE file, double-clicks it, and Windows
auto-prompts for administrator (UAC) to bind WinUSB to VID_3474&PID_42B2."""
import base64, pathlib

ROOT = pathlib.Path(__file__).resolve().parent
inf = (ROOT / "tools/windows/p2max-driver/p2max.inf").read_text(encoding="ascii")
b64 = base64.b64encode(inf.encode("ascii")).decode("ascii")

bat = f'''@echo off
setlocal
title Thermal Master P2 Max - One-time driver setup

:: --- auto-elevate to administrator (triggers the Windows UAC prompt) ---
net session >nul 2>&1
if not "%errorlevel%"=="0" (
  echo.
  echo  Requesting administrator permission to set up the camera driver...
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

set "INF=%TEMP%\\p2max_winusb.inf"
echo.
echo  Thermal Master P2 Max (P3 Lite) - WinUSB binder
echo  -------------------------------------------------

echo  Preparing driver descriptor...
powershell -NoProfile -Command "[IO.File]::WriteAllText('%INF%', [Text.Encoding]::ASCII.GetString([Convert]::FromBase64String('{b64}')))"

echo  Installing WinUSB driver for VID_3474^&PID_42B2 ...
pnputil /add-driver "%INF%" /install
if not "%errorlevel%"=="0" (
  echo.
  echo  Windows blocked the driver because "Test Mode" is off. Test Mode lets
  echo  third-party-signed drivers load (it is already what lets your P3 work).
  echo  Turning it on now -- this is a one-time change.
  bcdedit /set testsigning on >nul 2>&1
  echo.
  echo  Test Mode is ON. Please RESTART Windows, then run this file once more
  echo  to finish. After that the camera is plug-and-play forever.
  echo.
  pause
  exit /b 1
)

echo.
echo  SUCCESS. The camera is ready.
echo  Open the Thermal Master Web Viewer in Chrome/Edge and click "Connect camera".
echo.
pause
'''

out = ROOT / "web/driver/p2max-setup.bat"
out.write_text(bat, encoding="utf-8")
print("written", out, out.stat().st_size, "bytes")
