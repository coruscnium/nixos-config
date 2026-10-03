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

"""A comet circling the twelve columns.

Two things here are not obvious, and both were found by the user describing
what they saw rather than by reading the code.

Measure the distance from the head *one way around*. Using the nearest
distance fades the comet to both sides at once, which with a seven-column tail
lights ten of the twelve columns and reads as "a black column circling around"
-- a gap orbiting the microphone rather than a comet.

And give the head a plateau. There are only twelve angular positions, so a
head one column wide is at full brightness when it lines up with a column and
dimmer when it falls between two, and the peak visibly throbs as it travels.
A plateau radius wider than half the column spacing means at least one column
is always at full: measured peak brightness went from a standard deviation of
11.65 to exactly 0.00.
"""
from .. import colour, geometry
from ..colour import gamma
from ..geometry import COLUMNS, LED_COUNT
from .base import speed_range

UNIT = 256                              # fixed point: 256 units to one column
AROUND = COLUMNS * UNIT
PLATEAU = 160                           # > half the 128 half-spacing; see above
TAIL = 7 * UNIT                         # trails behind the head only
LEAD = 2 * UNIT                         # a short ramp ahead of it


def level_at(distance_behind):
    """Brightness 0..255 for a column that far behind the head."""
    ahead = AROUND - distance_behind if distance_behind else 0
    if min(distance_behind, ahead) <= PLATEAU:
        return 255
    if distance_behind <= TAIL:
        return 255 * (TAIL - distance_behind) // (TAIL - PLATEAU)
    if ahead <= LEAD:
        # Without this the column ahead stays black until the head crosses it
        # and then snaps to full, so the head jumps from column to column.
        return 255 * (LEAD - ahead) // (LEAD - PLATEAU)
    return 0


def spin(scheme, frames):
    col = scheme.first()
    revolution = speed_range(16, 160, scheme.speed)
    column_of = [geometry.column(i) for i in range(LED_COUNT)]

    out = []
    for t in range(revolution):
        head = t * AROUND // revolution
        shade = [colour.scale(col, gamma(level_at((head - c * UNIT) % AROUND)))
                 for c in range(COLUMNS)]
        out.append([shade[column_of[i]] for i in range(LED_COUNT)])
    return out
