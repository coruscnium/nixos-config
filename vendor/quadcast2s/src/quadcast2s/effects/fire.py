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

"""A heat simulation over the body grid.

Three things make this read as fire rather than as an orange microphone:

  * The upper rows cool faster, so the flames taper to dark tips. Without the
    `rise` term the tips sat at 114 and it read as "the whole mic is orange".
  * The palette, not a flat brightness scale of one colour. Heat runs black ->
    the chosen colour -> that colour with its green lifted toward yellow ->
    white-hot, which is what a flame actually does.
  * Sub-frame interpolation. Running the simulation at the full frame rate
    strobes; it "reads more like random flicker".

A chaotic simulation has no natural period, so unlike the other effects this
one cannot be made to meet itself at the loop point. The last frames are
cross-faded into the first instead.
"""
from .. import colour, geometry
from ..colour import WHITE, gamma
from ..geometry import BODY_ROWS, COLUMNS, LED_COUNT, RING_ROW
from .base import speed_range

COOLING = 30                            # per cell per simulation step
RISE = 5                                # how much faster the upper rows cool
SPARKING = 150                          # out of 255, per column per step
WARMUP = 40                             # steps thrown away, so frame 0 is lit
BLEND = 24                              # frames of cross-fade at the loop point

WARM_AT = 128                           # heat at which the colour starts to shift
WHITE_AT = 208                          # heat at which it goes white-hot


def hotter(col):
    """The chosen colour with its green lifted toward yellow."""
    return col[0], max(col), col[2]


def step(heat, rng):
    """One simulation step: cool, drift upward, then maybe spark at the base."""
    for r in range(BODY_ROWS):
        cool = COOLING * (BODY_ROWS + r * RISE) // BODY_ROWS
        row = heat[r]
        for c in range(COLUMNS):
            row[c] = max(0, row[c] - rng(cool + 1))

    for r in range(BODY_ROWS - 1, 0, -1):
        below, under = heat[r - 1], heat[max(0, r - 2)]
        row = heat[r]
        for c in range(COLUMNS):
            row[c] = (below[c] + 2 * under[c]) // 3

    base = heat[0]
    for c in range(COLUMNS):
        if rng(255) < SPARKING:
            base[c] = 160 + rng(96)


def shade(heat, col, warm, white):
    """Map a heat value to a colour.

    `white` is passed in rather than taken from the constant because it is a
    colour the effect invents for itself, and anything invented at runtime has
    to be put through brightness explicitly or -b silently does nothing.
    """
    if heat < WARM_AT:
        return colour.scale(col, gamma(heat * 255 // WARM_AT))
    if heat < WHITE_AT:
        return colour.lerp(col, warm, heat - WARM_AT, WHITE_AT - WARM_AT)
    return colour.lerp(warm, white, heat - WHITE_AT, 256 - WHITE_AT)


def paint(a, b, k, sub, col, warm, white):
    """One frame, interpolated k/sub of the way between two simulation states."""
    grid = [[(a[r][c] * (sub - k) + b[r][c] * k) // sub for c in range(COLUMNS)]
            for r in range(BODY_ROWS)]
    # The ring is the flame tips reaching the top: carry the drift one row on.
    grid.append([(grid[-1][c] + 2 * grid[-2][c]) // 3 for c in range(COLUMNS)])
    return [shade(grid[r][c], col, warm, white) for c, r in geometry.CELLS]


def fire(scheme, frames):
    col = scheme.first()
    warm = hotter(col)
    white = scheme.dim(WHITE)
    rng = scheme.rng()
    sub = speed_range(1, 12, scheme.speed)
    length = max(sub * 2, frames // sub * sub)      # a whole number of steps

    heat = [[0] * COLUMNS for _ in range(BODY_ROWS)]
    for _ in range(WARMUP):
        step(heat, rng)

    states = []
    for _ in range((length + BLEND) // sub + 2):
        states.append([row[:] for row in heat])
        step(heat, rng)

    raw = [paint(states[f // sub], states[f // sub + 1], f % sub, sub,
                 col, warm, white)
           for f in range(length + BLEND)]

    out = raw[:length]
    for k in range(BLEND):              # fade the overrun back into the start
        out[k] = [colour.lerp(raw[length + k][i], raw[k][i], k + 1, BLEND)
                  for i in range(LED_COUNT)]
    return out
