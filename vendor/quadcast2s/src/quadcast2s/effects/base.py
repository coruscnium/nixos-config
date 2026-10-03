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

"""Shared machinery for the effects: schemes, speed mapping, looping, RNG.

An effect is a pure function

    build(scheme, frames) -> list of frames, each 108 (r, g, b) tuples

with no device access at all. That is what lets the whole test suite run with
the microphone unplugged, and it is worth preserving.

`frames` is the loop length to aim for. Effects with a natural period of their
own (a colour sequence, say) are free to return a different number; the daemon
plays each zone's loop independently, so lengths need not agree.
"""
from .. import colour

DEFAULT_SPEED = 81
LOOP_FRAMES = 1200                      # 37.5 s at the device's 32 fps

# Only `fire` and `rain` use this -- everything else has a natural length of
# its own. At 300 frames the loop was 9.4 s and the repeat was plainly visible;
# 1200 costs about a megabyte and a tenth of a second to build, which is
# nothing next to being able to see the seam come round. It is also far more
# composite than 300 (30 divisors against 18), so the periods cycles() can pick
# land closer to the speed actually asked for.


def speed_range(lo, hi, spd):
    """A duration: higher speed gives a SMALLER result."""
    return lo + (hi - lo) * (100 - spd) // 100


def speed_scale(lo, hi, spd):
    """A rate: higher speed gives a LARGER result."""
    return lo + (hi - lo) * spd // 100


def cycles(frames, want):
    """Repeats that divide `frames` exactly, nearest to `want`.

    Nearest, not the next one up: always rounding up shortens every period and
    drags the whole speed range toward the fast end.
    """
    want = min(max(1, want), frames)    # rain asks for more than a loop at -s 1
    up = next(k for k in range(max(1, want), frames + 1) if frames % k == 0)
    down = next(k for k in range(min(want, frames), 0, -1) if frames % k == 0)
    return up if (up - want) <= (want - down) else down


class Rng:
    """A private linear congruential generator.

    The zones are filled in separate passes, so sharing Python's global RNG
    gives each zone its own raindrops and its own flames. Every pass makes one
    of these from the same per-run seed instead, and the two zones then draw
    the same scene.
    """

    def __init__(self, seed):
        self.s = seed & 0xFFFFFFFF or 1

    def __call__(self, n):
        self.s = (self.s * 1103515245 + 12345) & 0xFFFFFFFF
        return (self.s >> 16) % n if n > 0 else 0

    def pick(self, seq):
        return seq[self(len(seq))]


class Scheme:
    """What the user asked for, as an effect sees it.

    Brightness is applied here and nowhere else. Colours invented at runtime --
    random rain, `blink` with no colours, the white-hot end of `fire` -- are the
    ones that miss it and leave `-b` silently doing nothing, so every colour an
    effect uses must come out of palette(), first() or dim().
    """

    def __init__(self, colours=(), speed=DEFAULT_SPEED, delay=None,
                 brightness=100, random=False, seed=1):
        self._colours = list(colours)
        self.speed = min(100, max(1, speed))
        self.delay = delay
        self.brightness = min(100, max(0, brightness))
        self.random = random
        self.seed = seed & 0xFFFFFFFF or 1

    @property
    def level(self):
        return 255 * self.brightness // 100

    def dim(self, col):
        """Apply brightness to a colour the effect invented itself."""
        return colour.scale(col, self.level)

    def palette(self, default=None):
        """The colour list, brightness applied, falling back to `default`."""
        src = self._colours or list(default or [colour.DEFAULT])
        return [self.dim(c) for c in src]

    def first(self, default=colour.DEFAULT):
        return self.palette([default])[0]

    def given(self):
        """True if the user named colours explicitly."""
        return bool(self._colours)

    def rng(self):
        """A fresh generator, identical for every zone of the same run."""
        return Rng(self.seed)

    def __repr__(self):
        return ("Scheme(colours=%r, speed=%d, delay=%r, brightness=%d, "
                "random=%r, seed=%d)"
                % ([colour.format(c) for c in self._colours], self.speed,
                   self.delay, self.brightness, self.random, self.seed))
