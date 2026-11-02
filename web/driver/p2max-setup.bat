@echo off
setlocal
title Thermal Master P2 Max - One-time driver setup

:: --- request administrator (UAC prompt only; no system setting is changed) ---
net session >nul 2>&1
if not "%errorlevel%"=="0" (
  echo.
  echo  This step needs administrator permission to install the camera driver.
  echo  Requesting it now...
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

set "INF=%TEMP%\p2max_winusb.inf"
echo.
echo  Thermal Master P2 Max (P3 Lite) - WinUSB binder
echo  -------------------------------------------------

echo  Preparing driver descriptor...
powershell -NoProfile -Command "[IO.File]::WriteAllText('%INF%', [Text.Encoding]::ASCII.GetString([Convert]::FromBase64String('OyBwMm1heC5pbmYKOyBCaW5kcyB0aGUgaW4tYm94IFdpbmRvd3MgV2luVVNCIGRyaXZlciB0byBUaGVybWFsIE1hc3RlciBQMiBNYXggLyBQMyBMaXRlCjsgKFZJRF8zNDc0ICYgUElEXzQyQjIpIHNvIHRoZSBUaGVybWFsIE1hc3RlciBXZWIgVmlld2VyIGNhbiBvcGVuIGl0IGZyb20gdGhlCjsgYnJvd3NlciB2aWEgV2ViVVNCLiBSZXVzZXMgdGhlIHN5c3RlbSB3aW51c2IuaW5mIC0tIG5vIGV4dGVybmFsIC5kbGwvLmNhdCBzaGlwcGVkLgo7CjsgQm90aCBpbnRlcmZhY2VzIG11c3QgYmUgYm91bmQgdG8gV2luVVNCOgo7ICAgVVNCXFZJRF8zNDc0JlBJRF80MkIyJk1JXzAwICAtPiBjb250cm9sIGludGVyZmFjZSAoY2xhaW1JbnRlcmZhY2UgMCkKOyAgIFVTQlxWSURfMzQ3NCZQSURfNDJCMiZNSV8wMSAgLT4gc3RyZWFtaW5nIGludGVyZmFjZSAoY2xhaW1JbnRlcmZhY2UgMSkKOyBUaGlzIHBhY2thZ2UgbWF0Y2hlcyBPTkxZIHRoaXMgZGV2aWNlOyBpdCBkb2VzIG5vdCB0b3VjaCBhbnkgb3RoZXIgVVNCIGRldmljZS4KCltWZXJzaW9uXQpTaWduYXR1cmUgICA9ICIkV0lORE9XUyBOVCQiCkNsYXNzICAgICAgID0gVVNCRGV2aWNlCkNsYXNzR3VpZCAgID0gezg4QkFFMDMyLTVBODEtNDlmMC1CQzNELUE0RkYxMzgyMTZENn0KUHJvdmlkZXIgICAgPSAlTWFudWZhY3R1cmVyJQpEcml2ZXJWZXIgICA9IDExLzAyLzIwMjYsMS4wLjAuMAoKW01hbnVmYWN0dXJlcl0KJU1hbnVmYWN0dXJlciUgPSBNb2RlbHMsIE5UYW1kNjQKCltNb2RlbHMuTlRhbWQ2NF0KJURldmljZU5hbWUlID0gV2luVVNCSW5zdGFsbCwgVVNCXFZJRF8zNDc0JlBJRF80MkIyJk1JXzAwCiVEZXZpY2VOYW1lJSA9IFdpblVTQkluc3RhbGwsIFVTQlxWSURfMzQ3NCZQSURfNDJCMiZNSV8wMQoKW1dpblVTQkluc3RhbGxdCkluY2x1ZGUgPSB3aW51c2IuaW5mCk5lZWRzICAgPSBXSU5VU0IuTlQKCltXaW5VU0JJbnN0YWxsLkhXXQpJbmNsdWRlID0gd2ludXNiLmluZgpOZWVkcyAgID0gV0lOVVNCLk5ULkhXCgpbV2luVVNCSW5zdGFsbC5TZXJ2aWNlc10KSW5jbHVkZSA9IHdpbnVzYi5pbmYKTmVlZHMgICA9IFdJTlVTQi5OVC5TZXJ2aWNlcwoKW1N0cmluZ3NdCk1hbnVmYWN0dXJlciA9ICJUaGVybWFsIE1hc3RlciIKRGV2aWNlTmFtZSAgID0gIlRoZXJtYWwgTWFzdGVyIFAyIE1heCAoV2luVVNCKSIK')))"

echo.
echo  Installing WinUSB driver for VID_3474^&PID_42B2 (interfaces 0 and 1)...
pnputil /add-driver "%INF%" /install
set "RC=%errorlevel%"

if "%RC%"=="0" (
  echo.
  echo  SUCCESS. The camera is bound to WinUSB.
  echo  Open the Thermal Master Web Viewer in Chrome/Edge and click "Connect camera".
  echo.
  pause
  exit /b 0
)

echo.
echo  FAILED to install the driver (pnputil exit code %RC%).
echo.
echo  On a normal Windows install this usually means Driver Signature
echo  Enforcement blocked an unsigned driver package. That is expected here.
echo.
echo  To proceed, use ONE of these instead:
echo    - Run the official Thermal Master driver / software installer, OR
echo    - Use Zadig (https://zadig.akeo.ie) and bind "WinUSB" to the
echo      "Thermal Master P2 Max" device (VID_3474, PID_42B2).
echo.
echo  This script did NOT change Test Mode, Secure Boot, or any system setting,
echo  and did NOT modify any other USB device.
echo.
pause
exit /b 1
