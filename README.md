# Thermal Master Web Viewer

A browser-based viewer for **Thermal Master USB thermal cameras**. Plug the
camera in, open the page, click **Connect camera**. No install, no local
server, no native driver — the page talks to the camera directly over WebUSB.

Unofficial, and not affiliated with or endorsed by Thermal Master.

中文使用说明见 **[docs/zh-CN.md](docs/zh-CN.md)**。

## Supported cameras

Recognition is by USB **product ID** (`VID:PID`), not by the product name
string.

| Model | USB ID | Stream | Status |
| --- | --- | --- | --- |
| **P2 Max** | `3474:42b2` | 256×192 @ 25 fps | verified on hardware (fw 00.00.01.03, hw P2max-00.01) |
| P3 | `3474:45a2` | 256×192 @ 25 fps | verified |
| P1 | `3474:45c2` | 160×120 @ 25 fps | verified |
| P2 / P2 Pro / P3 Lite | own PID | 256×192 | works through the 256×192 fallback profile, not yet hardware-tested |

Every P2/P3-class camera streams the same 256×192 frame layout, so an
unrecognised PID still works: `resolveModel()` falls back to the 256×192
profile and only the model label is generic. If you have a model whose PID is
not listed, add one line to `web/js/models.js`.

> **Renaming the device does not break recognition.** The viewer never matches
> on the USB product string, so a camera whose firmware reports a different
> name (for example "P3 LITE") is still matched by its PID and streams exactly
> as before.

## Use it

Serve `web/` from anywhere:

```bash
python3 -m http.server -d web 8723       # then open http://localhost:8723
```

WebUSB needs a secure context, and `http://localhost` counts as one. Opening
`index.html` as a `file://` URL will not work — the page is built from ES
modules, which browsers refuse to load over `file://`.

### Browser and platform support

| Platform | Setup needed to view |
| --- | --- |
| **Android** (Chrome) | **none** — plug the camera in and open the page |
| **macOS** (Chrome / Edge) | **none** |
| **Windows** (Chrome / Edge) | one-time WinUSB bind — the page now auto-prompts with a one-click installer |
| **Linux** | one udev rule for `3474:*` |
| iOS / iPadOS (Safari) | not supported — no WebUSB |
| Firefox / Safari (desktop) | not supported — no WebUSB |

## Windows: one-time WinUSB bind

A web page cannot install drivers, so on Windows the camera's vendor interface
has to be bound to **WinUSB** once per machine. No JavaScript can change this:
the browser is only allowed to claim an interface that already has a
WinUSB-compatible driver.

### If the official Thermal Master software is installed, there is nothing to do

The vendor's Windows software installs signed per-model WinUSB driver packages
(`P1.cat`, `P2.cat`, `P3.cat`, `P4.cat`). Once one of those is on the machine,
Windows binds WinUSB automatically every time that model is plugged in, and
this viewer works with no further step.

A brand-new model is only covered once the vendor adds its product ID to one of
those packages. Until then, such a camera shows up in Device Manager with
warning code 28 and needs the manual bind below.

To see which packages a machine has, look for `DeviceID` lines containing
`VID_3474` in `C:\Windows\INF\oem*.inf` (the files are UTF-16).

### Or use the in-page installer (recommended)

The viewer **automatically shows a setup card** when it finds the camera but
cannot claim its interface — the Windows "driver not installed" symptom (Device
Manager warning code 28). The card offers a single download —
`web/driver/p2max-setup.bat` — that is fully self-contained (the driver
descriptor is embedded, no extra files needed):

1. Plug the camera in.
2. Click **Download driver setup (.bat)** in the card and double-click the file.
3. Windows shows the **User Account Control** prompt — click **Yes** (the script
   asks for administrator rights itself; no right-click needed).
4. Refresh the page and click **Connect camera** again.

The script binds the in-box `winusb.inf` to `VID_3474&PID_42B2` (both the control
and streaming interfaces), and only for this camera. It does **not** enable Test
Mode and does **not** change Secure Boot, driver signing or any other system
setting; it never reboots and never touches another USB device. On a machine
with driver-signature enforcement the unsigned INF can still be blocked — the
script says so and points to the official Thermal Master driver or Zadig
instead. The same INF is readable at `web/driver/p2max.inf`.

### Otherwise, bind it once with Zadig

Bind it once with [Zadig](https://zadig.akeo.ie):

1. Open Zadig → `Options` → **List All Devices**
2. Pick **P2 MAX** (or your camera) in the device dropdown — check that the
   USB ID reads `3474` / `42B2` (or `45A2` / `45C2`) before continuing
3. Leave **Target Driver** on `WinUSB (v6.1.7600.16385)`
4. Click **Install Driver** (or **Replace Driver** if a driver is present)

This changes only that machine's driver binding; the camera itself is not
modified. To undo it, uninstall the device in Device Manager and rescan.

### Making it zero-setup for every visitor

The only way to remove this step for end users is on the **firmware** side, not
in this repository: expose a Microsoft OS 2.0 descriptor set that advertises
the `WINUSB` compatible ID. Windows then binds WinUSB automatically the first
time the camera is plugged into a clean machine, and the viewer works with no
Zadig, no installer and no admin rights.

That change is specified, with the descriptor layout and a verification
procedure, in [docs/windows-zero-setup.md](docs/windows-zero-setup.md).

## Features

- Live thermal image at 25 fps, 256×192 (P2 Max / P3 / P2 class) or 160×120 (P1)
- Hover for a per-pixel temperature; live max / min / centre / average
- 7 palettes; thermal, IR-brightness, or blended view
- Auto / rolling / manual temperature range
- Emissivity and reflected-temperature correction
- Rotate 90° either way, hot/cold markers, reticle, labels, °C / °F
- Freeze, and one-click PNG / CSV export (the CSV is every pixel's temperature)
- Works on a phone; controls collapse into bottom drawers
- Keeps the screen awake while streaming
- Shutter (NUC) trigger and gain-mode switch
- Firmware log in a collapsible footer

## How it works

The camera is not a UVC webcam. Both interfaces are vendor-specific
(`class=0xFF`), which WebUSB is allowed to claim:

```
interface 0 alt 0: class=0xff  ep 0x84 IN bulk, 0x05 OUT bulk   (commands)
interface 1 alt 0: class=0xff  no endpoints                     (idle)
interface 1 alt 1: class=0xff  ep 0x81 IN bulk, 0x02 OUT bulk   (video)
```

**Commands** are 18 bytes over a vendor control transfer (`bRequest=0x20`).
`cmd_type` is big-endian, every other field little-endian, with a CRC16-CCITT
over the first 16 bytes.

**Frames** are `2 × (2h + 2) × w` bytes between 12-byte start and end markers.
For a 256×192 detector that is 197,632 bytes per frame at 25 fps, carrying two
planes: IR brightness (8-bit) and thermal (16-bit, units of 1/64 kelvin), so
`°C = raw / 64 − 273.15`.

Frames are read in fixed 16 KiB chunks and resynchronised on the short 12-byte
trailing transfer, which is what makes the boundary findable.

### P2 Max measurements

Captured from hardware on 2026-10-31:

| Field | Value |
| --- | --- |
| VID:PID | `3474:42b2` |
| Product | `P2 MAX` |
| Firmware | `00.00.01.03` |
| Hardware | `P2max-00.01` |
| Part number | `P2M-1A00800056` |
| Frame size | 197,632 B, markers OK |
| Rate | 25.1 fps |

## Layout

```
web/index.html       markup
web/styles.css       styles
web/js/models.js     device profiles (USB ID -> name, width, height)
web/js/usb.js        WebUSB driver: commands, streaming, frame parsing
web/js/viewer.js     state, geometry, rendering, overlay
web/js/ui.js         control wiring, pointer, PNG/CSV export
web/js/log.js        firmware log capture and panel
web/js/panels.js     which secondary panel is showing, in both layouts
web/js/wakelock.js   holds the screen on while the camera streams
web/js/text.js       pure helpers for assembling the log
web/js/palettes.js   colour palettes
web/js/download.js   handing a generated file to the browser
web/js/session.js    the camera in use, shared between modules
web/js/main.js       entry point and connection flow
web/driver/p2max-setup.bat   self-contained Windows WinUSB binder, surfaced by the in-page setup card
tools/usb-info.py    optional descriptor dump for troubleshooting
tests/               tests for the shipped driver and log helpers
```

Native ES modules, loaded directly by the browser. No bundler, no transpiler,
nothing to install.

## Tests

```bash
node tests/test_webusb.mjs
```

It rebuilds all 11 command buffers from scratch and compares them byte for
byte, CRC included, against buffers captured from the official app.

## Troubleshooting

**The picker shows no device.** On Windows, bind WinUSB first. On Linux, add a
udev rule. Use `python3 tools/usb-info.py` to check what the OS sees.

On Windows the fastest way to tell what is wrong is:

```powershell
powershell -ExecutionPolicy Bypass -File tools\windows\check-driver.ps1
```

It prints, per connected camera, the driver in use and whether the viewer can
open it.

**The image looks flat and grey.** Usually correct — a room is nearly uniform
in temperature. Point it at something warm, or switch the range mode.

**The camera clicks every ~90 seconds.** That is the mechanical shutter doing a
flat-field correction. **Shutter** triggers one on demand.

## Licence and credits

[Apache-2.0](LICENSE). This project is a derivative of
[ferrolho/thermal-master-viewer](https://github.com/ferrolho/thermal-master-viewer);
see [NOTICE](NOTICE) for the full attribution chain, including the protocol
work by `jvdillon/p3-ir-camera`,
`skywalker1905/thermal-camera-viewer`, `xaionaro-go/thermalmaster` and
`Phalphy/OpenP3`.

"Thermal Master" is a trademark of its owner, used only to state which hardware
this software talks to. No vendor logo or branding is reproduced.
