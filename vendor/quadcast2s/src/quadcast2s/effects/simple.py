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

"""The effects that share one mechanism: a per-frame colour sequence.

`solid` is the degenerate case -- one frame, held forever. `cycle` walks a
colour list; `wave` and `vertical` are the same walk with the phase offset per
LED, by angular position and by height. `blink`, `lightning` and `pulse` build
their sequence out of ramps and gaps instead of a gradient.

The one thing to get right here is how frames are shared out between colour
transitions. Splitting a loop evenly makes short hops crawl and long ones race,
because colours are not equally far apart in RGB -- the default rainbow is badly
uneven and the result reads as the animation repeatedly speeding up and slowing
down. Frames are therefore allocated in proportion to the distance each
transition has to cover. See docs/EFFECTS.md.
"""
from .. import colour, geometry
from ..colour import BLACK
from ..geometry import BODY_ROWS, COLUMNS, LED_COUNT
from .base import speed_range

BLINK_COLOURS = 6                       # how many to invent when none are given


# ------------------------------------------------------------ the sequence

def apportion(weights, total):
    """Split `total` between len(weights) transitions, proportionally.

    Largest-remainder, with a floor of one frame each so a transition between
    two identical colours still takes a frame rather than vanishing.
    """
    n = len(weights)
    total = max(total, n)
    span = sum(weights)
    if span == 0:                       # every colour identical; split evenly
        share = [total // n] * n
        for k in range(total - sum(share)):
            share[k] += 1
        return share

    exact = [w * total / span for w in weights]
    share = [max(1, int(e)) for e in exact]
    order = sorted(range(n), key=lambda k: exact[k] % 1, reverse=True)
    k = 0
    while sum(share) < total:
        share[order[k % n]] += 1
        k += 1
    k = 0
    while sum(share) > total:
        j = order[-1 - (k % n)]
        if share[j] > 1:
            share[j] -= 1
        k += 1
    return share


def gradient(palette, total):
    """A looping colour per frame, through `palette` and back to the start."""
    n = len(palette)
    pairs = [(palette[i], palette[(i + 1) % n]) for i in range(n)]
    shares = apportion([colour.distance(a, b) for a, b in pairs], total)
    seq = []
    for (a, b), span in zip(pairs, shares):
        seq += [colour.lerp(a, b, step, span) for step in range(span)]
    return seq


def sequence(scheme):
    """The colour sequence behind cycle, wave and vertical."""
    palette = scheme.palette(colour.RAINBOW)
    length = speed_range(8, 96, scheme.speed)
    return gradient(palette, length * len(palette))


def _hold(frame_colour, count):
    """`count` frames of one flat colour. The frames are shared, not copied."""
    frame = [frame_colour] * LED_COUNT
    return [frame] * count


# ------------------------------------------------------------------ effects

def solid(scheme, frames):
    """A constant colour. Only the first colour given is used."""
    return _hold(scheme.first(), 1)


def cycle(scheme, frames):
    """The whole microphone sweeping through the colour list as one gradient."""
    return [[c] * LED_COUNT for c in sequence(scheme)]


def wave(scheme, frames):
    """`cycle`, phase-shifted by angular position, so colour travels around.

    Twelve columns of resolution rather than the six angular blocks: twice as
    smooth, and it costs nothing.
    """
    seq = sequence(scheme)
    n = len(seq)
    offset = [geometry.column(i) * n // COLUMNS for i in range(LED_COUNT)]
    return [[seq[(t + offset[i]) % n] for i in range(LED_COUNT)]
            for t in range(n)]


def vertical(scheme, frames):
    """`cycle`, phase-shifted by row, so colour travels up the microphone.

    The eight body rows are spread over exactly one full loop of the sequence,
    which makes the gradient continuous and puts the ring -- row 8, one whole
    loop up -- back in phase with the bottom row. The offset is subtracted so
    the colour climbs rather than falls.
    """
    seq = sequence(scheme)
    n = len(seq)
    offset = [geometry.row(i) * n // BODY_ROWS for i in range(LED_COUNT)]
    return [[seq[(t - offset[i]) % n] for i in range(LED_COUNT)]
            for t in range(n)]


def blink(scheme, frames):
    """On, off, on, stepping through the colour list. The only user of -d."""
    if scheme.given():
        palette = scheme.palette()
    else:
        rng = scheme.rng()              # no colours given: invent some
        palette = [scheme.dim(colour.hsv(rng(360)))
                   for _ in range(BLINK_COLOURS)]

    on = speed_range(3, 60, scheme.speed)
    off = on if scheme.delay is None else scheme.delay

    out = []
    for col in palette:
        out += _hold(col, on) + _hold(BLACK, off)
    return out


def _flash(scheme, shuffle):
    """A fast ramp up, a slow decay, then darkness. Shared by the two below.

    The ramps are indexed step + 1 out of total so they actually reach their
    endpoint; otherwise the flash never quite gets to full and the decay never
    quite gets to black.
    """
    palette = scheme.palette()
    if shuffle:
        rng = scheme.rng()
        palette = list(palette)
        for k in range(len(palette) - 1, 0, -1):
            j = rng(k + 1)
            palette[k], palette[j] = palette[j], palette[k]

    rise = speed_range(2, 12, scheme.speed)
    fall = speed_range(8, 80, scheme.speed)
    dark = speed_range(2, 30, scheme.speed)

    out = []
    for col in palette:
        for step in range(rise):
            out += _hold(colour.lerp(BLACK, col, step + 1, rise), 1)
        for step in range(fall):
            out += _hold(colour.lerp(col, BLACK, step + 1, fall), 1)
        out += _hold(BLACK, dark)
    return out


def lightning(scheme, frames):
    """Flashes in an unpredictable order."""
    return _flash(scheme, shuffle=True)


def pulse(scheme, frames):
    """The same flash, walking the colour list in the order given."""
    return _flash(scheme, shuffle=False)
