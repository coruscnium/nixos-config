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

"""Colour arithmetic, kept in integers throughout.

Small and used everywhere, so the details matter. Two of them in particular,
both from docs/EFFECTS.md:

  * lerp() divides by `total`, never `total - 1`. With `total - 1` a segment
    ends on the next colour and the following segment starts on it, so every
    boundary holds one value for two frames and the motion visibly hitches.
  * gamma() exists because LEDs are linear in PWM and the eye is not. A linear
    ramp appears to fall off a cliff and then crawl.
"""

BLACK = (0, 0, 0)
WHITE = (255, 255, 255)
DEFAULT = (0xf2, 0x00, 0x00)


def clamp(v, lo=0, hi=255):
    return lo if v < lo else hi if v > hi else v


def scale(colour, level):
    """Dim a colour. level runs 0..255."""
    level = clamp(level)
    return tuple(c * level // 255 for c in colour)


def lerp(a, b, step, total):
    """Interpolate a -> b. Divide by total, NOT total - 1; see the module doc."""
    if total <= 0:
        return tuple(a)
    return tuple(x + (y - x) * step // total for x, y in zip(a, b))


def add(a, b):
    """Saturating add, for light that overlaps."""
    return tuple(min(255, x + y) for x, y in zip(a, b))


def distance(a, b):
    """Manhattan distance in RGB, used to budget transition lengths."""
    return sum(abs(x - y) for x, y in zip(a, b))


def gamma(level):
    """Perceptual correction for a 0..255 brightness level."""
    level = clamp(level)
    return level * level // 255


def luminance(colour):
    """Rough perceived brightness. Only used by the test suite."""
    r, g, b = colour
    return (r * 54 + g * 183 + b * 19) // 256


def parse(text):
    """A hex colour, with or without a leading '#'."""
    s = text[1:] if text.startswith("#") else text
    if not s or len(s) > 6 or any(c not in "0123456789abcdefABCDEF" for c in s):
        raise ValueError(f"not a colour: {text}")
    v = int(s, 16)
    return (v >> 16) & 0xff, (v >> 8) & 0xff, v & 0xff


def format(colour):
    return "%02x%02x%02x" % tuple(colour)


def hsv(h, s=255, v=255):
    """h in degrees, s and v 0..255. Only used to build the palettes."""
    h %= 360
    sector, offset = divmod(h * 6, 360)
    rise = v * offset // 360
    fall = v - rise
    p = v * (255 - s) // 255
    q = p + (v - p) * fall // max(v, 1)
    t = p + (v - p) * rise // max(v, 1)
    return [(v, t, p), (q, v, p), (p, v, t),
            (p, q, v), (t, p, v), (v, p, q)][sector]


# The default for `cycle` and friends: nine hues, evenly spaced, so the
# sequence closes back on red without repeating it.
RAINBOW = [hsv(h) for h in range(0, 360, 40)]

