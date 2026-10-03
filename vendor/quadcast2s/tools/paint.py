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

"""Light LEDs by index, to check a guess about the layout. See README.md.

    paint.py '<expr>'   expr is evaluated per LED with `i` bound to its index
                        and must return 0xRRGGBB (0 = off)
"""
import sys
import signal
from quadcast2s.usb import QC2S, LED_COUNT

if len(sys.argv) < 2:
    sys.exit(__doc__)

expr = sys.argv[1]
leds = []
for i in range(LED_COUNT):
    v = int(eval(expr, {"__builtins__": {}}, {"i": i, "n": LED_COUNT}))
    leds.append(((v >> 16) & 0xff, (v >> 8) & 0xff, v & 0xff))

lit = [i for i, c in enumerate(leds) if any(c)]
print(f"{len(lit)} of {LED_COUNT} lit: {lit}")
print("streaming until interrupted (the device does not latch a frame)")

running = [True]
signal.signal(signal.SIGINT, lambda *_: running.__setitem__(0, False))
signal.signal(signal.SIGTERM, lambda *_: running.__setitem__(0, False))

d = QC2S(quiet=True)
try:
    while running[0]:
        d.send_frame(leds)
finally:
    d.close()
