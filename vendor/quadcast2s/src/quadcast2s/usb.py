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

"""Talking to the HyperX QuadCast 2 S controller (03f0:02b5).

The protocol is written up in docs/PROTOCOL.md. In short:

    transport : interrupt transfers on interface 1, EP 0x06 OUT / 0x85 IN
    packet    : always 64 bytes, byte 0 is a HID report ID
    frame     : one 44 01 <n> header, then n packets of 44 02 <index> <RGB*20>
    response  : 64 bytes, rsp[0] == 0xff, rsp[14:16] echoes the command

Two things matter and are easy to get wrong:

  * the device never latches a frame -- stop streaming and the firmware takes
    the LEDs back and resumes its own animation;
  * the response to every packet must be read. Writing without reading is
    accepted by the USB stack and runs far faster, but the device ignores the
    frames entirely and the lights never change.
"""
import sys
import time

import usb.core
import usb.util

VID, PID = 0x03f0, 0x02b5
IFACE = 1
EP_OUT, EP_IN = 0x06, 0x85

PACKET = 64
HEADER = 4                              # report id, subcommand, index, pad
LEDS_PER_PACKET = (PACKET - HEADER) // 3
PACKETS_PER_FRAME = 6
LED_COUNT = 108                         # 120 slots exist; 108 are real

REPORT_LED = 0x44
SUB_COUNT = 0x01
SUB_RGB = 0x02


class QC2S:
    def __init__(self, quiet=False):
        self.quiet = quiet
        self.dev = usb.core.find(idVendor=VID, idProduct=PID)
        if self.dev is None:
            sys.exit("QuadCast 2 S controller (03f0:02b5) not found")
        try:
            if self.dev.is_kernel_driver_active(IFACE):
                self.dev.detach_kernel_driver(IFACE)
        except (usb.core.USBError, NotImplementedError):
            pass
        try:
            usb.util.claim_interface(self.dev, IFACE)
        except usb.core.USBError:
            sys.exit("could not claim the device -- something else is holding it")

    def close(self):
        try:
            usb.util.release_interface(self.dev, IFACE)
            self.dev.attach_kernel_driver(IFACE)
        except Exception:
            pass

    def xfer(self, data, timeout=1000, read=True):
        """Send one 64-byte packet and return the 64-byte answer."""
        buf = bytearray(PACKET)
        buf[:len(data)] = data
        self.dev.write(EP_OUT, buf, timeout)
        if not read:
            return None
        try:
            return bytes(self.dev.read(EP_IN, PACKET, timeout))
        except usb.core.USBError as e:
            if not self.quiet:
                print(f"  <no answer: {e}>")
            return None

    def send_frame(self, leds):
        """Display one frame. leds is a list of (r, g, b)."""
        count = (len(leds) + LEDS_PER_PACKET - 1) // LEDS_PER_PACKET
        self.xfer([REPORT_LED, SUB_COUNT, count, 0])
        for p in range(count):
            packet = bytearray([REPORT_LED, SUB_RGB, p, 0])
            for colour in leds[p * LEDS_PER_PACKET:(p + 1) * LEDS_PER_PACKET]:
                packet += bytes(colour)
            self.xfer(packet)           # the answer must be read, see above


def flush(d, tries=6):
    """Drain stale packets from the IN endpoint before a fresh exchange."""
    for _ in range(tries):
        try:
            d.dev.read(EP_IN, PACKET, 30)
        except usb.core.USBError:
            break


def hexdump(b, indent="  "):
    if b is None:
        return indent + "(none)"
    return "\n".join(
        indent + f"{i:02x}: " + " ".join(f"{x:02x}" for x in b[i:i + 16])
        for i in range(0, len(b), 16))
