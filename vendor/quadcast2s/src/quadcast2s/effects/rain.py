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

"""Slanting raindrops falling through the ring into the body.

Built on the unrolled grid so the drops genuinely fall *through* the ring --
row 8 -- and on down the body, rather than the two zones animating separately.

Points worth keeping:

  * `-s` sets the fall time directly, in frames. Specifying rain by
    repeats-per-loop instead put the default at about 0.2 s per drop, which the
    user called "WAY too fast to tell".
  * The speed jitter is proportional, a quarter of the base. A fixed spread is
    as wide as the whole range at the slow end and leaves `-s` doing almost
    nothing.
  * Drops are drawn anti-aliased across the cells they fall between, in both
    axes. With only twelve by nine cells, snapping to whole cells makes them
    visibly jump from row to row.
  * Overlapping drops add, so two crossing paths brighten where they meet.
"""
from .. import colour, geometry
from ..colour import BLACK, gamma
from ..geometry import COLUMNS, GRID_ROWS
from .base import cycles, speed_range

UNIT = 256                              # fixed point: 256 units to one cell
DROPS = 7                               # eighteen read as "an avalanche"
FALL_LO, FALL_HI = 14, 170              # frames for one fall
DUTY_LO, DUTY_HI = 45, 90               # per cent of the cycle spent falling
TRAIL_LO, TRAIL_HI = 2, 4               # cells of fading trail
DRIFT = 700                             # 1/256 cell of sideways travel per fall
PEAK, PEAK_SPREAD = 150, 106
JITTER = 4                              # base // JITTER, i.e. proportional


def splat(grid, x, y, level, col):
    """Add one anti-aliased point of light at a fractional cell position."""
    c0, fx = divmod(x, UNIT)
    r0, fy = divmod(y, UNIT)
    for dc, wx in ((0, UNIT - fx), (1, fx)):
        if wx <= 0:
            continue
        c = (c0 + dc) % COLUMNS
        for dr, wy in ((0, UNIT - fy), (1, fy)):
            if wy <= 0:
                continue
            r = r0 + dr
            if not 0 <= r < GRID_ROWS:
                continue
            lit = level * wx * wy // (UNIT * UNIT)
            if lit:
                grid[r][c] = colour.add(grid[r][c], colour.scale(col, lit))


def rain(scheme, frames):
    rng = scheme.rng()
    if scheme.random:
        palette = [scheme.dim(colour.hsv(rng(360))) for _ in range(DROPS)]
    else:
        palette = scheme.palette()

    base = speed_range(FALL_LO, FALL_HI, scheme.speed)
    jitter = max(1, base // JITTER)

    drops = []
    for _ in range(DROPS):
        fall = max(4, base - jitter + rng(2 * jitter + 1))
        duty = DUTY_LO + rng(DUTY_HI - DUTY_LO + 1)
        cycle = cycles(frames, fall * 100 // duty)
        fall = min(fall, cycle)
        # Every fall gets its own column, slant, brightness, trail and colour.
        # Drawing them once per drop instead made each drop repeat one
        # identical fall every couple of seconds -- seven metronomes rather
        # than rain, and far more obvious than the loop itself.
        falls = [(rng(COLUMNS * UNIT), rng(2 * DRIFT + 1) - DRIFT,
                  PEAK + rng(PEAK_SPREAD),
                  TRAIL_LO + rng(TRAIL_HI - TRAIL_LO + 1),
                  palette[rng(len(palette))])
                 for _ in range(frames // cycle)]
        drops.append((cycle, rng(cycle), fall, falls))

    out = []
    for t in range(frames):
        grid = [[BLACK] * COLUMNS for _ in range(GRID_ROWS)]
        for cycle, phase, fall, falls in drops:
            k = (t + phase) % cycle
            if k >= fall:
                continue                # idling between falls
            # Which fall this is. The swap happens as a fall begins, while the
            # drop is off the grid, so it is never seen changing.
            x0, drift, peak, trail, col = falls[
                ((t + phase) // cycle) % len(falls)]
            # The head starts above the ring and finishes below the body, so
            # the drop is seen entering and leaving rather than appearing.
            top, bottom = GRID_ROWS, -(trail + 1)
            y = top * UNIT - (top - bottom) * UNIT * k // fall
            x = x0 + drift * k // fall
            for j in range(trail + 1):
                level = peak * (trail + 1 - j) // (trail + 1)
                splat(grid, x % (COLUMNS * UNIT), y + j * UNIT, gamma(level), col)
        out.append(geometry.grid_to_leds(grid))
    return out
