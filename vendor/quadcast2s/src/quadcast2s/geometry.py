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

"""LED index <-> grid mapping.

The layout is documented in docs/PROTOCOL.md section 4, and it is not what you
would guess: the index runs *around* the microphone rather than up it. Six
angular blocks of eighteen, and within a block the strip climbs one body
column, crosses the top ring, then comes back down the neighbouring column.

    block b = indices 18b .. 18b+17          (b = 0..5)

      18b +  0 .. 18b +  7   body column 2b,   ascending   (0 = bottom)
      18b +  8 .. 18b +  9   TOP RING segment b
      18b + 10 .. 18b + 17   body column 2b+1, descending  (17 = bottom)

Everything else in the program works against the unrolled grid instead: twelve
columns around the microphone, nine rows tall, where rows 0..7 are the body
bottom-to-top and row 8 is the ring sitting on it. That is what lets rain fall
through the ring into the body rather than animating the two zones separately.
"""

LED_COUNT = 108
BLOCK = 18                              # LEDs per angular block
BLOCKS = 6
COLUMNS = 12                            # angular positions: two per block
BODY_ROWS = 8
RING_ROW = BODY_ROWS                    # the ring is row 8 of the grid
GRID_ROWS = BODY_ROWS + 1


def is_ring(i):
    """True for the twelve ring LEDs."""
    return i % BLOCK in (8, 9)


def column(i):
    """Angular position, 0..11. Defined for ring and body alike."""
    return 2 * (i // BLOCK) + (0 if i % BLOCK < 9 else 1)


def row(i):
    """Height on the grid: 0 is the bottom of the body, 8 is the ring."""
    r = i % BLOCK
    if r in (8, 9):
        return RING_ROW
    return r if r < 8 else 17 - r       # the run comes back down


def cell(i):
    """The grid cell (column, row) an LED occupies."""
    return column(i), row(i)


def index(col, r):
    """The LED at a grid cell. The inverse of cell()."""
    b, side = divmod(col, 2)
    if r == RING_ROW:
        return BLOCK * b + 8 + side
    return BLOCK * b + (r if side == 0 else 17 - r)


CELLS = [cell(i) for i in range(LED_COUNT)]
INDEX = {c: i for i, c in enumerate(CELLS)}

RING = [i for i in range(LED_COUNT) if is_ring(i)]
BODY = [i for i in range(LED_COUNT) if not is_ring(i)]
ALL = list(range(LED_COUNT))

ZONES = {"ring": RING, "body": BODY, "both": ALL}

BLACK = (0, 0, 0)


def blank_grid(colour=BLACK):
    """A grid[row][column] of one colour."""
    return [[colour] * COLUMNS for _ in range(GRID_ROWS)]


def grid_to_leds(grid):
    """Flatten a grid[row][column] into the 108 LEDs, in index order."""
    return [grid[r][c] for c, r in CELLS]


def blank_frame(colour=BLACK):
    return [colour] * LED_COUNT
