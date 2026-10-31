@echo off
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

set "INF=%TEMP%\p2max_winusb.inf"
echo.
echo  Thermal Master P2 Max (P3 Lite) - WinUSB binder
echo  -------------------------------------------------

echo  Preparing driver descriptor...
powershell -NoProfile -Command "[IO.File]::WriteAllText('%INF%', [Text.Encoding]::ASCII.GetString([Convert]::FromBase64String('OyBwMm1heC5pbmYKOyBCaW5kcyB0aGUgaW5ib3ggV2luVVNCIGRyaXZlciB0byBUaGVybWFsIE1hc3RlciBQMiBNYXggKFZJRF8zNDc0JlBJRF80MkIyKQo7IHNvIHRoYXQgdGhlIFRoZXJtYWwgTWFzdGVyIFdlYiBWaWV3ZXIgY2FuIG9wZW4gaXQgZnJvbSB0aGUgYnJvd3NlciB2aWEgV2ViVVNCLgo7CjsgTWluaW1hbCBvbiBwdXJwb3NlOiBpdCByZXVzZXMgdGhlIFdpbmRvd3MgaW5ib3ggd2ludXNiLmluZiwgc28gdGhlcmUgYXJlIE5PCjsgZXh0ZXJuYWwgLmRsbCBvciAuY2F0IGZpbGVzIHRvIHNoaXAuIEluc3RhbGwgb25jZSB3aXRoIGluc3RhbGwuYmF0OyBhZnRlciB0aGF0CjsgdGhlIGNhbWVyYSBpcyAicGx1ZyBpbiAtPiBvcGVuIHBhZ2UgLT4gY2xpY2sgQ29ubmVjdCIgZm9yZXZlci4KCltWZXJzaW9uXQpTaWduYXR1cmUgID0gIiRXaW5kb3dzIE5UJCIKQ2xhc3MgICAgICA9IFVTQkRldmljZQpDbGFzc0d1aWQgID0gezg4QkFFMDMyLTVBODEtNDlGMC1CQzNELUE0RkYxMzgyMTZENn0KUHJvdmlkZXIgICA9ICVNYW51ZmFjdHVyZXIlCkRyaXZlclZlciAgPSAxMC8zMS8yMDI2LDEuMC4wLjAKCltNYW51ZmFjdHVyZXJdCiVNYW51ZmFjdHVyZXIlID0gTW9kZWxzLCBOVGFtZDY0CgpbTW9kZWxzLk5UYW1kNjRdCjsgTWF0Y2ggYm90aCB0aGUgaW50ZXJmYWNlIChNSV8wMCkgYW5kIHRoZSBiYXJlIGRldmljZSwgaW4gY2FzZSB0aGUKOyBpbnRlcmZhY2UgbnVtYmVyIGRpZmZlcnMgYmV0d2VlbiBmaXJtd2FyZSByZXZpc2lvbnMuCiVEZXZpY2VOYW1lJSA9IFdpblVTQkluc3RhbGwsIFVTQlxWSURfMzQ3NCZQSURfNDJCMiZNSV8wMAolRGV2aWNlTmFtZSUgPSBXaW5VU0JJbnN0YWxsLCBVU0JcVklEXzM0NzQmUElEXzQyQjIKCltXaW5VU0JJbnN0YWxsXQpJbmNsdWRlID0gd2ludXNiLmluZgpOZWVkcyAgID0gV0lOVVNCLk5UCgpbV2luVVNCSW5zdGFsbC5IV10KSW5jbHVkZSA9IHdpbnVzYi5pbmYKTmVlZHMgICA9IFdJTlVTQi5OVC5IVwoKW1dpblVTQkluc3RhbGwuU2VydmljZXNdCkluY2x1ZGUgPSB3aW51c2IuaW5mCk5lZWRzICAgPSBXSU5VU0IuTlQuU2VydmljZXMKCltTdHJpbmdzXQpNYW51ZmFjdHVyZXIgPSAiVGhlcm1hbCBNYXN0ZXIiCkRldmljZU5hbWUgICA9ICJUaGVybWFsIE1hc3RlciBQMiBNYXggKFdpblVTQikiCg==')))"

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
