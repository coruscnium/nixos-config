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

"""The effect registry: name -> builder, and what each one actually uses.

Every builder has the signature described in base.py:

    build(scheme, frames) -> list of frames of 108 (r, g, b) tuples
"""
from collections import namedtuple

from .. import colour

from . import fire as _fire, rain as _rain, simple, spin as _spin
from .base import LOOP_FRAMES, Scheme

EFFECTS = {
    "blink": simple.blink,
    "cycle": simple.cycle,
    "fire": _fire.fire,
    "lightning": simple.lightning,
    "pulse": simple.pulse,
    "rain": _rain.rain,
    "solid": simple.solid,
    "spin": _spin.spin,
    "vertical": simple.vertical,
    "wave": simple.wave,
}


# What each mode does with the options, so a front end can grey out the ones
# that would be ignored rather than pretending they work. `colours` is 1 where
# only the first is used, None where any number of them are, and `random` marks
# the modes that do something meaningful with the literal word `random`.
# `palette` is what the mode uses when given no colours at all. A front end
# that shows colour swatches needs it: without it, "no colours" has to be
# represented as an empty row, and anything that fills the row with a guess
# quietly changes what the mode does. Naming the real constants here means
# passing these colours in explicitly reproduces the default exactly, which
# test_effects asserts.
Traits = namedtuple("Traits", "colours speed delay random palette")

_RED = [colour.DEFAULT]

TRAITS = {
    "blink":     Traits(None, True, True, True, _RED),
    "cycle":     Traits(None, True, False, False, colour.RAINBOW),
    "fire":      Traits(1, True, False, False, _RED),
    "lightning": Traits(None, True, False, False, _RED),
    "pulse":     Traits(None, True, False, False, _RED),
    "rain":      Traits(None, True, False, True, _RED),
    "solid":     Traits(1, False, False, False, _RED),
    "spin":      Traits(1, True, False, False, _RED),
    "vertical":  Traits(None, True, False, False, colour.RAINBOW),
    "wave":      Traits(None, True, False, False, colour.RAINBOW),
}


def names():
    return sorted(EFFECTS)


def traits(name):
    return TRAITS[name]


def build(name, scheme, frames=LOOP_FRAMES):
    """Render `name` into a loop of frames. No device involved."""
    try:
        builder = EFFECTS[name]
    except KeyError:
        raise ValueError(f"unknown mode: {name}")
    return builder(scheme, frames)


__all__ = ["EFFECTS", "LOOP_FRAMES", "Scheme", "TRAITS", "Traits",
           "build", "names", "traits"]
