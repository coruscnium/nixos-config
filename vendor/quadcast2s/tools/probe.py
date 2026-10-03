#!/usr/bin/env python3
# quadcast2s - RGB lighting for the HyperX QuadCast 2 S
#
# Copyright (C) 2026 Coruscnium
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, version 3 of the License only.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero
# General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.
#
# SPDX-License-Identifier: AGPL-3.0-only

"""Ask the Quadcast 2S controller what it supports. See README.md."""
import sys
from quadcast2s.usb import QC2S, flush, hexdump

# Skipped on purpose: 0x10 resets the controller, and the 0xf0/0xf1/0xfa-0xfd
# block is numbered like a firmware-update interface. Neither was poked.
SAFE_REPORTS = [0x01, 0x07, 0x11, 0x14, 0x15, 0x40, 0x41, 0x42, 0x43, 0x44,
                0x45, 0x62, 0x63, 0x64, 0x65, 0xdb]


def info(d):
    flush(d)
    r = d.xfer([0x01, 0x00, 0, 0])
    if not r:
        print("no answer")
        return
    text = "".join(chr(c) if 32 <= c < 127 else "" for c in r[1:])
    print(f"firmware: {text.strip()}")


def reports(d):
    print("report  answered by  payload")
    for rid in SAFE_REPORTS:
        flush(d)
        r = d.xfer([rid, 0x00, 0, 0], timeout=500)
        if r is None or not any(r):
            print(f"  {rid:02x}      -")
            continue
        body = " ".join(f"{x:02x}" for x in r[1:12])
        print(f"  {rid:02x}      {r[0]:02x}          {body}")


def sub(d, rid):
    print(f"subcommands of report {rid:02x}:")
    for s in range(0x00, 0x10):
        flush(d)
        r = d.xfer([rid, s, 0, 0], timeout=500)
        if r is None or not any(r):
            print(f"  {s:02x}  -")
        else:
            print(f"  {s:02x}  answered on {r[0]:02x}: "
                  + " ".join(f"{x:02x}" for x in r[:16]))


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__ + "\nusage: probe.py info|reports|sub <report>")
    d = QC2S(quiet=True)
    try:
        what = sys.argv[1]
        if what == "info":
            info(d)
        elif what == "reports":
            reports(d)
        elif what == "sub":
            sub(d, int(sys.argv[2], 0))
        else:
            sys.exit(f"unknown command: {what}")
    finally:
        d.close()


main()
