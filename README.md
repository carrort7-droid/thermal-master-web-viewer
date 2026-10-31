# Thermal Master Web Viewer

A browser-based viewer for **Thermal Master USB thermal cameras**. Plug the
camera in, open the page, click **Connect camera**. No install, no local
server, no native driver — the page talks to the camera directly over WebUSB.

Unofficial, and not affiliated with or endorsed by Thermal Master.

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

| Platform | Notes |
| --- | --- |
| Chrome, Edge, Opera | works |
| Firefox, Safari | no WebUSB, so no |
| macOS | works as-is |
| Android | works — plug the camera straight into the phone and open the page |
| Linux | needs a udev rule granting access to `3474:*` |
| Windows | the camera interface must be bound to WinUSB (see below) |

## Windows: binding WinUSB

Windows does not let a browser claim a vendor-specific interface that has no
driver. Bind **WinUSB** once with [Zadig](https://zadig.akeo.ie):

1. Open Zadig → `Options` → **List All Devices**
2. Pick **P2 MAX** (or your camera) in the device dropdown — check that the
   USB ID reads `3474` / `42B2` (or `45A2` / `45C2`) before continuing
3. Leave **Target Driver** on `WinUSB (v6.1.7600.16385)`
4. Click **Install Driver** (or **Replace Driver** if a driver is present)

This changes only that machine's driver binding; the camera itself is not
modified. On another Windows PC, repeat the step once (or install the vendor
software). Android, iOS and macOS need none of this. To undo it, uninstall the
device in Device Manager and rescan.

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
