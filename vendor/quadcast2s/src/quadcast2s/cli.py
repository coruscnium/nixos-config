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

"""Argument parsing.

    quadcast2s [OPTIONS] MODE [COLOURS...]
    quadcast2s [OPTIONS] --ring MODE [COLOURS...] --body MODE [COLOURS...]

The zones are named for what they physically are. A ring of twelve LEDs sits on
top of a body of ninety-six, and each can run a different mode in one
invocation; `--upper` and `--lower` are accepted as undocumented aliases for
anyone with the habit.

Options bind to the section they appear in, so

    quadcast2s --ring cycle -s 30 --body fire

runs the ring slowly and the body at the default speed. Options given before
any mode are defaults for every section.
"""
import random as _random
import sys

from . import colour
from .effects import EFFECTS, names
from .effects.base import DEFAULT_SPEED, Scheme

ZONE_FLAGS = {"--ring": "ring", "--body": "body",
              "--upper": "ring", "--lower": "body"}

VALUE_OPTS = {"-b": "brightness", "--brightness": "brightness",
              "-s": "speed", "--speed": "speed",
              "-d": "delay", "--delay": "delay"}

LIMITS = {"brightness": (0, 100), "speed": (1, 100), "delay": (0, 10000)}

USAGE = """usage: quadcast2s [OPTIONS] MODE [COLOURS...]
       quadcast2s [OPTIONS] --ring MODE [COLOURS...] --body MODE [COLOURS...]

modes:
  %s

zones:
  --ring            the twelve LEDs on top
  --body            the ninety-six in the twelve columns
                    with neither, the mode fills the whole microphone

options:
  -b, --brightness N   0-100 (default 100)
  -s, --speed N        1-100 (default %d)
  -d, --delay N        off-time for `blink`, in frames
  -f, --foreground     stay in the foreground instead of backgrounding
      --wait           wait for the microphone instead of failing when it is
                       missing. For running under a service manager
      --dump           print the frames as JSON instead of lighting anything
      --frames N       how many frames --dump should print (default 300)
  -h, --help           this
  -V, --version        version

colours are hex, with or without a leading '#'. The word `random` in place of
colours asks the mode to choose them.

The microphone does not hold a frame, so the program keeps streaming. Running
it again replaces the instance already going. Stop it with `pkill -x
quadcast2s` -- never `pkill -f`, which matches whole command lines and will
take your shell with it.
"""


class Usage(Exception):
    """A bad command line. Reported on stderr with exit status 2."""


class Section:
    """One zone and the mode filling it."""

    def __init__(self, zone):
        self.zone = zone
        self.mode = None
        self.colours = []
        self.random = False
        self.opts = {}

    def scheme(self, defaults, seed):
        opts = dict(defaults, **self.opts)
        return Scheme(colours=self.colours,
                      speed=opts.get("speed", DEFAULT_SPEED),
                      delay=opts.get("delay"),
                      brightness=opts.get("brightness", 100),
                      random=self.random,
                      seed=seed)


class Options:
    def __init__(self):
        self.foreground = False
        self.wait = False
        self.dump = False
        self.frames = 300


def usage():
    return USAGE % ("  ".join(names()), DEFAULT_SPEED)


def _number(name, text):
    try:
        value = int(text)
    except ValueError:
        raise Usage(f"{name} needs a number, not {text!r}")
    lo, hi = LIMITS.get(name, (0, 1 << 30))
    if not lo <= value <= hi:
        raise Usage(f"{name} must be between {lo} and {hi}, not {value}")
    return value


def parse(argv):
    """Turn a command line into (Options, [Section]). Raises Usage."""
    opts = Options()
    defaults = {}
    sections = []
    current = None
    args = list(argv)

    while args:
        tok = args.pop(0)

        if tok in ("-h", "--help"):
            sys.stdout.write(usage())
            raise SystemExit(0)
        if tok in ("-V", "--version"):
            from . import __version__
            sys.stdout.write(f"quadcast2s {__version__}\n")
            raise SystemExit(0)
        if tok in ("-f", "--foreground"):
            opts.foreground = True
            continue
        if tok == "--wait":
            opts.wait = True
            continue
        if tok == "--dump":
            opts.dump = True
            continue
        if tok == "--frames":
            if not args:
                raise Usage("--frames needs a number")
            opts.frames = max(1, _number("frames", args.pop(0)))
            continue

        if tok in ZONE_FLAGS:
            current = Section(ZONE_FLAGS[tok])
            sections.append(current)
            continue

        name, _, inline = tok.partition("=")
        if name in VALUE_OPTS:
            if not inline:
                if not args:
                    raise Usage(f"{tok} needs a value")
                inline = args.pop(0)
            key = VALUE_OPTS[name]
            (current.opts if current else defaults)[key] = _number(key, inline)
            continue

        if tok.startswith("-") and tok != "-":
            raise Usage(f"unknown option: {tok}")

        if current is None:
            current = Section("both")
            sections.append(current)
        if current.mode is None:
            current.mode = tok
        elif tok == "random":
            current.random = True       # the mode picks its own colours
        else:
            try:
                current.colours.append(colour.parse(tok))
            except ValueError as e:
                raise Usage(str(e))

    return opts, _validate(opts, sections, defaults)


def _validate(opts, sections, defaults):
    if not sections:
        raise Usage("no mode given")
    if any(s.zone == "both" for s in sections) and len(sections) > 1:
        raise Usage("a mode without a zone already fills the whole microphone; "
                    "give every mode a --ring or --body")
    seen = set()
    for section in sections:
        if section.mode is None:
            raise Usage(f"--{section.zone} was given no mode")
        if section.mode not in EFFECTS:
            raise Usage(f"unknown mode: {section.mode}")
        if section.zone in seen:
            raise Usage(f"--{section.zone} given twice")
        seen.add(section.zone)

    # One seed per run, so two zones running the same effect draw one scene
    # rather than two independent ones.
    seed = _random.SystemRandom().randrange(1, 1 << 32)
    for section in sections:
        section.built = section.scheme(defaults, seed)
    return sections
