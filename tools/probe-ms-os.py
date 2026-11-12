#!/usr/bin/env python3
"""Check whether a Thermal Master camera advertises Microsoft OS descriptors.

If it does, Windows installs WinUSB by itself the first time the camera is
plugged into a clean machine: no installer, no admin rights, no user action.
That is the only way to get true plug-and-play on Windows, and it is done in
firmware, not in this repository.

    pip install pyusb libusb-package
    python3 tools/probe-ms-os.py              # checks vendor 0x3474
    python3 tools/probe-ms-os.py --vid 0x3474 --pid 0x42b2

Both mechanisms are probed:

  MS OS 1.0  string descriptor 0xEE returns "MSFT100" + a vendor request code;
             a vendor request then returns the extended compat ID descriptor.
  MS OS 2.0  BOS descriptor carries a platform capability with UUID
             D8DD60DF-4589-4CC7-9CD2-659D9E648A9F.

Exit code 0 means at least one camera advertises WCID.
"""
from __future__ import annotations

import argparse
import sys

try:
    import usb.core
    import libusb_package
    BACKEND = libusb_package.get_libusb1_backend()
except Exception:  # pyusb present but no libusb binding
    import usb.core
    BACKEND = None

MS_OS_20_UUID = "D8DD60DF-4589-4CC7-9CD2-659D9E648A9F"


def get_string(dev, index: int, langid: int):
    try:
        head = bytes(dev.ctrl_transfer(0x80, 0x06, (0x03 << 8) | index, langid, 2, timeout=1000))
        if len(head) < 2 or head[1] != 0x03:
            return None
        raw = bytes(dev.ctrl_transfer(0x80, 0x06, (0x03 << 8) | index, langid, head[0], timeout=1000))
        return raw[2:].decode("utf-16-le", "replace")
    except Exception:
        return None


def probe_os10(dev) -> bool:
    msft = None
    for langid in (0x0000, 0x0409):
        s = get_string(dev, 0xEE, langid)
        if s and s.startswith("MSFT"):
            msft = s
            print(f"    OS 1.0: string 0xEE = {s!r} (langid {langid:#06x})")
            break
    if not msft:
        print("    OS 1.0: no 0xEE string")
        return False

    vendor_code = ord(msft[7]) if len(msft) > 7 else 0
    print(f"    OS 1.0: vendor request code = {vendor_code:#04x}")
    try:
        head = bytes(dev.ctrl_transfer(0xC0, vendor_code, 0, 0x0004, 16, timeout=1000))
        total = int.from_bytes(head[0:4], "little")
        body = bytes(dev.ctrl_transfer(0xC0, vendor_code, 0, 0x0004, total, timeout=1000))
        count = int.from_bytes(body[4:8], "little")
        print(f"    OS 1.0: extended compat ID, length={total}, functions={count}")
        found = False
        off = 16
        for i in range(count):
            sect = body[off:off + 24]
            if len(sect) < 24:
                break
            cid = sect[2:10].split(b"\x00")[0].decode("ascii", "replace")
            scid = sect[10:18].split(b"\x00")[0].decode("ascii", "replace")
            print(f"      function {i}: iface={sect[0]} CompatibleID={cid!r} SubCompatibleID={scid!r}")
            if cid.upper() == "WINUSB":
                found = True
            off += 24
        return found
    except Exception as exc:
        print(f"    OS 1.0: compat ID request failed ({type(exc).__name__})")
        return False


def probe_os20(dev) -> bool:
    try:
        head = bytes(dev.ctrl_transfer(0x80, 0x06, 0x0F00, 0, 5, timeout=1000))
        total = head[2] | (head[3] << 8)
        data = bytes(dev.ctrl_transfer(0x80, 0x06, 0x0F00, 0, total, timeout=1000))
    except Exception:
        print("    OS 2.0: no BOS descriptor")
        return False

    print(f"    OS 2.0: BOS present, capabilities={head[4]}")
    found = False
    i = 5
    while i + 2 < len(data):
        blen, btype = data[i], data[i + 1]
        if blen == 0:
            break
        if btype == 0x05 and blen >= 20:
            u = data[i + 2:i + 18]
            uuid = (u[3::-1].hex() + "-" + u[5:3:-1].hex() + "-" + u[7:5:-1].hex()
                    + "-" + u[8:10].hex() + "-" + u[10:16].hex()).upper()
            print(f"      platform capability UUID={uuid}")
            if uuid.startswith(MS_OS_20_UUID):
                found = True
        i += blen
    return found


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--vid", type=lambda s: int(s, 0), default=0x3474)
    ap.add_argument("--pid", type=lambda s: int(s, 0), default=None)
    args = ap.parse_args()

    kwargs = {"idVendor": args.vid, "find_all": True}
    if args.pid is not None:
        kwargs["idProduct"] = args.pid
    devices = list(usb.core.find(backend=BACKEND, **kwargs))

    if not devices:
        print(f"No device with vendor {args.vid:#06x} found.")
        print("Plug the camera in and run again.")
        return 1

    any_wcid = False
    for dev in devices:
        print("=" * 60)
        try:
            name = dev.product
        except Exception:
            name = "?"
        print(f"PID={dev.idProduct:#06x}  bcdUSB={dev.bcdUSB:#06x}  product={name}")

        os10 = probe_os10(dev)
        os20 = probe_os20(dev)
        wcid = os10 or os20
        any_wcid = any_wcid or wcid

        print(f"    -> MS OS 1.0 WINUSB: {'YES' if os10 else 'no'}")
        print(f"    -> MS OS 2.0 WINUSB: {'YES' if os20 else 'no'}")
        print(f"    -> RESULT: {'WCID PRESENT - Windows will install WinUSB automatically'
                                if wcid else 'NO WCID - Windows needs an INF (vendor installer)'}")

    print("=" * 60)
    print("SUMMARY: " + ("at least one camera is self-configuring on Windows"
                         if any_wcid else "no camera is self-configuring; a driver install is required"))
    return 0 if any_wcid else 2


if __name__ == "__main__":
    sys.exit(main())
