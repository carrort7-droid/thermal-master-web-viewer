#!/usr/bin/env python3
"""Generate web/driver/p2max-setup.bat.

The .bat is a tiny bootstrapper for the web page: one download, one double
click, one UAC prompt. It fetches the real installer (install.ps1 + dpscat.exe
+ p2max.inf) from the published site and runs it, so the logic lives in one
place and never drifts out of sync with tools/windows/p2max-driver/.

Why the INF is no longer embedded as base64: the INF alone is not installable.
pnputil refuses a driver package that has no .cat catalog ("third-party INF
does not contain digital signature information"), and the vendor package ships
no catalog. install.ps1 generates one with dpscat.exe, signs it with a local
self-signed certificate, trusts it, and retries. That needs real files.

Keep this file plain ASCII: cmd.exe re-reads batch files byte-by-byte and any
non-ASCII byte or a mid-file chcp breaks line parsing.
"""

import pathlib

ROOT = pathlib.Path(__file__).resolve().parent
BASE = "https://carrort7-droid.github.io/thermal-master-web-viewer/driver"

BAT = f"""@echo off
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

set "DIR=%ProgramData%\\P2MaxDriver\\bin"
set "BASE={BASE}"

echo.
echo  Thermal Master P2 MAX ^(P3 Lite^) - WinUSB driver setup
echo  -----------------------------------------------------
if not exist "%DIR%" mkdir "%DIR%"

echo  Downloading installer files...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol = 3072; $b='%BASE%'; $d='%DIR%'; foreach($f in 'install.ps1','dpscat.exe','p2max.inf'){{ $p = Join-Path $d $f; Invoke-WebRequest -UseBasicParsing -Uri ($b+'/'+$f) -OutFile $p; Unblock-File -LiteralPath $p }}"
if not "%errorlevel%"=="0" (
  echo.
  echo  [FAIL] Could not download the installer. Check your connection.
  goto :done
)

echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%DIR%\\install.ps1"
set "RC=%ERRORLEVEL%"

echo.
if "%RC%"=="0" echo [OK]   Driver ready. Go back to the web page and click "Connect camera".
if "%RC%"=="3" echo [WAIT] Camera not found. Plug the camera in, then run this again.
if "%RC%"=="1" echo [FAIL] Setup failed. See C:\\ProgramData\\P2MaxDriver\\install.log

:done
echo.
echo Press any key to close this window.
pause >nul
"""


def main() -> None:
    out = ROOT / "web" / "driver" / "p2max-setup.bat"
    out.parent.mkdir(parents=True, exist_ok=True)
    text = BAT.replace("\r\n", "\n").replace("\n", "\r\n")
    text.encode("ascii")  # fail loudly if anything non-ASCII sneaks in
    out.write_bytes(text.encode("ascii"))
    print(f"wrote {out} ({len(text)} bytes)")


if __name__ == "__main__":
    main()
