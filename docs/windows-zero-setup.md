# Making the viewer zero-setup on Windows

## The problem

WebUSB can only claim an interface that already has a **WinUSB-compatible
driver** bound to it. On a clean Windows machine the camera enumerates as a
vendor-specific interface (`class 0xFF`) with no driver, so the browser cannot
open it — Device Manager shows code 28 ("drivers not installed").

No JavaScript, and no change to this repository, can fix that: a web page has
no way to install a driver. Today the workaround is a one-time manual bind with
Zadig.

### Verified on hardware (2026-10-31)

P3 and P2 Max were both probed on the same machine. Their USB descriptors are
structurally identical apart from the product id, and **neither advertises
WCID**:

| | P3 | P2 Max |
| --- | --- | --- |
| PID | `0x45A2` | `0x42B2` |
| `bcdUSB` | `0x0200` | `0x0200` |
| BOS descriptor | **absent** (request stalls) | **absent** (request stalls) |
| Device class | `0xEF / 0x02 / 0x01` (IAD) | `0xEF / 0x02 / 0x01` (IAD) |
| Interface 0 | `0xFF / 0xF0 / 0x00`, EP `0x84`+`0x05` | same |
| Interface 1 | alt 0 empty, alt 1 EP `0x81`+`0x02` | same |

So a Windows machine where P3 "just works" is not getting that from the
camera — it already has a WinUSB driver bound (vendor package or Zadig). On a
genuinely clean Windows install, **both models** show code 28.

The useful corollary: because P3 and P2 Max are identical at the USB level,
whatever makes P3 work will make P2 Max work too, as soon as its product id is
covered.

## Two ways to remove the step

### Option A — extend the signed driver package (proven, already shipping)

Thermal Master's Windows software already installs **per-model WinUSB driver
packages**. On a machine where the official software was installed, the camera
is bound automatically on every plug-in and this viewer needs no manual step at
all. Verified on a working machine (installed 2026-06-27):

| INF | Catalog | Covers |
| --- | --- | --- |
| `oem70.inf` | `P1.cat` | `VID_3474&PID_45C2&MI_00` |
| `oem0.inf` | `P2.cat` | `VID_3474&PID_4281` |
| `oem2.inf` | `P3.cat` | `VID_3474&PID_45A2&MI_00` |
| `oem92.inf` | `P4.cat` | `VID_3474&PID_42A1` |
| `oem18.inf` | `ThermalCam DFU.cat` | firmware update interface |

#### What these packages actually are (verified 2026-10-31)

They are **libwdi-generated** packages, not WHQL-signed vendor drivers. Device
Manager reports:

- Digital signer: **`Microsoft (P3.inf) [Self]`** — a *self-signed* catalog,
  installed into the trusted store by libwdi
- Driver files include `libusbK.dll`, `WdfCoInstaller01009.dll`,
  `WinUSBCoInstaller2.dll` — libwdi's WinUSB payload
- `DriverStore\FileRepository\p3.inf_amd64_*` holds `p3.inf`, `P3.cat`, `WinUsb\`

This is why the binding *looks* like a stock Microsoft driver (provider
"Microsoft", version `6.1.7600.16385`) and feels preinstalled — the only
give-aways are the `[Self]` signer and the extra DLLs.

The practical consequence: adding a new model does **not** require WHQL
signing. It is one more `DeviceID` entry in the same generated INF, re-signed
self-signed the same way the existing four already are.

So the cheapest route to "plug in and it just works" for a new model is not a
web change at all — it is one line in the driver INF plus a re-sign:

```
DeviceID = "VID_3474&PID_42B2&MI_00"
```

Ship that in the next release of the official software (or as a stand-alone
signed package) and every user who installs it — or already has it and
receives the update — gets zero-setup support for that model, including the
web viewer. Note that a package is matched per product ID: `P2.cat` covers
`42 81` and does **not** cover `42 B2`.

### Option B — WCID in firmware (no installer at all)

Teach the **firmware** to tell Windows what driver it wants. Windows has
two built-in mechanisms for exactly this, and either one makes Windows install
WinUSB **by itself** on a clean machine — no Zadig, no installer, no admin
rights, no download, no user action of any kind.

This is a firmware change, made once, and it covers every camera and every
future user, whether or not any Thermal Master software was ever installed.

| | MS OS 1.0 | MS OS 2.0 |
| --- | --- | --- |
| Where | string descriptor `0xEE` + vendor request | BOS descriptor |
| Needs `bcdUSB` bumped | **no** (works at `0x0200`) | yes, `0x0201`+ |
| Windows support | 7 and later | 8.1 and later |
| Effort for current firmware | **smaller — recommended** | larger |

Both models currently report `bcdUSB = 0x0200`, so **MS OS 1.0 is the cheaper
path**: it needs no change to the USB version the device declares.

Both options can coexist: Option A fixes existing models today, Option B makes
future models self-configuring.

## What the firmware needs to add — MS OS 1.0 (recommended)

### 1. Answer `GET_DESCRIPTOR(STRING, 0xEE, langid 0x0000)`

Return exactly 18 bytes:

| Offset | Size | Value |
| --- | --- | --- |
| 0 | 1 | `18` (bLength) |
| 1 | 1 | `0x03` (STRING) |
| 2 | 14 | `"MSFT100"` in UTF-16LE |
| 16 | 1 | `bVendorCode` — any unused vendor request code, e.g. `0x01` |
| 17 | 1 | `0x00` |

Windows probes this on every enumeration; if it stalls, Windows concludes the
device has no MS descriptors.

### 2. Answer the vendor request

`bmRequestType = 0xC0`, `bRequest = bVendorCode`, `wValue = 0x0000`,
`wIndex = 0x0004` (extended compat ID), `wLength` = the `dwLength` below.

Payload (`Microsoft OS Descriptor`):

| Offset | Size | Value |
| --- | --- | --- |
| 0 | 4 | `dwLength` — total length, `0x18` + 24 per function |
| 4 | 2 | `bcdVersion = 0x0100` |
| 6 | 2 | `wIndex = 0x0004` |
| 8 | 1 | `bCount` — number of functions, `1` for this camera |
| 9 | 7 | reserved, zero |
| 16 | 24 | function 0 (below) |

Function 0:

| Offset | Size | Value |
| --- | --- | --- |
| +0 | 1 | `bFirstInterfaceNumber = 0` |
| +1 | 1 | reserved, `0x01` |
| +2 | 8 | `CompatibleID = "WINUSB\0\0"` |
| +10 | 8 | `SubCompatibleID` = zeros |
| +18 | 6 | reserved, zero |

### 3. Optionally answer `wIndex = 0x0005` (extended properties)

Same vendor request with `wIndex = 0x0005` returns `DeviceInterfaceGUIDs`.
Not required for Windows to bind WinUSB, but useful if a desktop app also wants
to open the camera.

### 4. Leave the interface layout alone

Keep `class 0xFF / subclass 0xF0` on interface 0 — the viewer depends on it.

### Verify it

```bash
python3 tools/probe-ms-os.py --pid 0x42b2
```

Expect `MS OS 1.0 WINUSB: YES`. Then on a clean Windows machine, plug the camera
in and do nothing: Device Manager should show the camera with no warning icon,
and `DEVPKEY_Device_Service` should read `WinUSB` with `INF = winusb.inf`.

## What the firmware needs to add — MS OS 2.0 (alternative)

### 1. Raise `bcdUSB` to 0x0201

The BOS descriptor is only requested for USB 2.1 and later. The camera
currently reports `bcdUSB = 0x0200`, so this must be bumped first.

### 2. Add a BOS descriptor with a platform capability

Returned for `GET_DESCRIPTOR(BOS, 0x0F)`:

| Field | Value |
| --- | --- |
| `bDevCapabilityType` | `0x05` (PLATFORM) |
| `bmAttributes` | `0x00` |
| `bcdVersion` / `wIndex` | not used for this capability |
| PlatformCapabilityUUID | `{D8DD60DF-4589-4CC7-9CD2-659D9E648A9F}` |
| `dwWindowsVersion` | `0x06030000` (Windows 8.1 and later) |
| `wMSOSDescriptorSetTotalLength` | total length of the set below |
| `bMS_VendorCode` | vendor request code used to fetch the set (e.g. `0x01`) |
| `bAltEnumCode` | `0x00` |

Windows then fetches the descriptor set with
`GET_MS_DESCRIPTOR` (`bmRequestType = 0xC0`, `bRequest = bMS_VendorCode`,
`wIndex = 0x0007`, `wLength = total length`).

### 3. Add the descriptor set itself

**Compatible ID feature descriptor** — this is the part that makes Windows
choose WinUSB:

| Field | Value |
| --- | --- |
| `wLength` | `0x0028` (40) |
| `wDescriptorType` | `0x0003` (COMPATIBLE_ID) |
| `CompatibleID` | `"WINUSB\0\0"` (8 bytes, NUL padded) |
| `SubCompatibleID` | `"00000000"` (8 bytes, `0x00` padded — "no sub-ID") |

**Registry property feature descriptor** (recommended) — gives WinUSB a device
interface GUID so applications can enumerate it:

| Field | Value |
| --- | --- |
| `wDescriptorType` | `0x0004` (REG_PROPERTY) |
| `wPropertyDataType` | `0x0007` (REG_MULTI_SZ) |
| `wPropertyNameLength` | length of `"DeviceInterfaceGUIDs"` in UTF-16 incl. NUL |
| `PropertyName` | `"DeviceInterfaceGUIDs\0"` |
| `wPropertyDataLength` | length of the GUID string in UTF-16 incl. NUL |
| `PropertyData` | `"{xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx}\0"` |

Use a fresh GUID owned by Thermal Master and keep it stable across firmware
versions; host applications will look it up.

### 4. Keep the existing interfaces unchanged

Do **not** change the interface layout — the viewer depends on it:

```
interface 0 alt 0: class=0xff  ep 0x84 IN bulk, 0x05 OUT bulk   (commands)
interface 1 alt 0: class=0xff  no endpoints
interface 1 alt 1: class=0xff  ep 0x81 IN bulk, 0x02 OUT bulk   (video)
```

## How to verify

1. **Descriptors on Linux** (no driver needed):
   ```bash
   lsusb -v -d 3474:42b2 | grep -iA6 "Binary Object Store\|Microsoft OS"
   ```
   Expect a BOS descriptor with the platform capability UUID above, and a
   compatible-ID entry containing `WINUSB`.
2. **Clean Windows machine** — plug the camera in and do nothing:
   - Device Manager: the camera appears with **no warning icon**
   - PowerShell:
     ```powershell
     Get-PnpDevice -PresentOnly |
       Where-Object { $_.InstanceId -like "*VID_3474*" } |
       ForEach-Object {
         $svc = (Get-PnpDeviceProperty -InstanceId $_.InstanceId `
                 -KeyName 'DEVPKEY_Device_Service').Data
         "$($_.FriendlyName) -> $svc"
       }
     ```
     Expect `P2 MAX -> WinUSB`.
3. **The viewer**: open the page in Chrome and click **Connect camera**; the
   picker should list the camera with no prior Zadig step.

## Notes

- Machines that already bound another driver keep it until the device is
  uninstalled in Device Manager and rescanned; new machines bind WinUSB on
  first plug.
- The alternative — shipping a signed driver package (INF + catalog) — also
  works but still requires an installer and admin rights, so it is strictly
  worse than WCID for a "just open the page" experience.
- Until firmware ships this, Android and macOS already need no setup at all;
  only Windows asks for the one-time bind.
