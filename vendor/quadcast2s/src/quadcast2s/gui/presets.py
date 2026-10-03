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

"""Named lighting setups, saved as JSON.

A preset is just what the user chose on screen, and it turns back into the same
command line the CLI already understands. Keeping the argv as the interchange
format means the GUI never becomes a second source of truth about what an
option does -- the string in a preset is the string you could have typed.

Stored at $XDG_CONFIG_HOME/quadcast2s/presets.json.
"""
import json
import os

from .. import colour
from ..effects import TRAITS

VERSION = 1
DEFAULT_SPEED = 81
DEFAULT_BRIGHTNESS = 100
ZONE_FLAG = {"ring": "--ring", "body": "--body"}


def default_colours(mode):
    """The colours a mode uses when given none, as hex.

    The GUI always shows explicit swatches, so this is what fills them in. It
    comes out of effects.TRAITS rather than being guessed here, and passing
    them in produces frames identical to passing nothing.
    """
    return [colour.format(c) for c in TRAITS[mode].palette]


def config_dir():
    base = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    return os.path.join(base, "quadcast2s")


def presets_path():
    return os.path.join(config_dir(), "presets.json")


class Zone:
    """One zone's settings: exactly one section of the command line."""

    def __init__(self, zone="both", mode="solid", colours=(),
                 speed=DEFAULT_SPEED, brightness=DEFAULT_BRIGHTNESS,
                 delay=None, random=False):
        self.zone = zone
        self.mode = mode
        self.colours = [c.lower() for c in colours]
        self.speed = speed
        self.brightness = brightness
        self.delay = delay
        self.random = random

    def args(self):
        """This zone as command line arguments."""
        traits = TRAITS[self.mode]
        out = []
        if self.zone != "both":
            out.append(ZONE_FLAG[self.zone])
        out.append(self.mode)
        if self.random and traits.random:
            out.append("random")
        else:
            out += self.colours[:traits.colours] if traits.colours else self.colours
        out += ["-b", str(self.brightness)]
        if traits.speed:
            out += ["-s", str(self.speed)]
        if traits.delay and self.delay is not None:
            out += ["-d", str(self.delay)]
        return out

    def to_json(self):
        return {"zone": self.zone, "mode": self.mode, "colours": self.colours,
                "speed": self.speed, "brightness": self.brightness,
                "delay": self.delay, "random": self.random}

    @classmethod
    def from_json(cls, d):
        return cls(zone=d.get("zone", "both"), mode=d.get("mode", "solid"),
                   colours=d.get("colours", []),
                   speed=d.get("speed", DEFAULT_SPEED),
                   brightness=d.get("brightness", DEFAULT_BRIGHTNESS),
                   delay=d.get("delay"), random=d.get("random", False))

    def copy(self):
        return Zone.from_json(self.to_json())


class Preset:
    def __init__(self, name, zones=None):
        self.name = name
        self.zones = list(zones) if zones else [Zone()]

    def args(self):
        out = []
        for zone in self.zones:
            out += zone.args()
        return out

    def to_json(self):
        return {"name": self.name, "zones": [z.to_json() for z in self.zones]}

    @classmethod
    def from_json(cls, d):
        return cls(d["name"], [Zone.from_json(z) for z in d.get("zones", [])]
                   or [Zone()])

    def copy(self, name=None):
        return Preset(name or self.name, [z.copy() for z in self.zones])


def validate(preset):
    """Reasons this preset would not survive a round trip, if any."""
    problems = []
    if not preset.name.strip():
        problems.append("a preset needs a name")
    if not preset.zones:
        problems.append("a preset needs at least one zone")
    if len({z.zone for z in preset.zones}) != len(preset.zones):
        problems.append("the same zone is set twice")
    if any(z.zone == "both" for z in preset.zones) and len(preset.zones) > 1:
        problems.append("a whole-microphone mode cannot be combined with a zone")
    for zone in preset.zones:
        if zone.mode not in TRAITS:
            problems.append(f"unknown mode: {zone.mode}")
        for c in zone.colours:
            try:
                colour.parse(c)
            except ValueError as e:
                problems.append(str(e))
        if not 0 <= zone.brightness <= 100:
            problems.append("brightness must be 0-100")
        if not 1 <= zone.speed <= 100:
            problems.append("speed must be 1-100")
    return problems


def defaults():
    """What a fresh install starts with: one per effect, plus a way to stop.

    One effect each, deliberately. A preset that combines two zones is a fine
    thing to save, but it is a poor thing to ship: it makes an effect look like
    it only exists as half of something else. The ring/body split is still one
    checkbox away.
    """
    return [
        Preset("Solid", [Zone(mode="solid", colours=["ff0000"])]),
        Preset("Blink", [Zone(mode="blink", random=True)]),
        Preset("Cycle", [Zone(mode="cycle")]),
        Preset("Wave", [Zone(mode="wave")]),
        Preset("Vertical", [Zone(mode="vertical")]),
        Preset("Spin", [Zone(mode="spin")]),
        Preset("Pulse", [Zone(mode="pulse")]),
        Preset("Lightning", [Zone(mode="lightning")]),
        Preset("Fire", [Zone(mode="fire", colours=["ff4000"], speed=40)]),
        Preset("Rain", [Zone(mode="rain", colours=["3fa0ff"])]),
        Preset("Off", [Zone(mode="solid", colours=["000000"])]),
    ]


def load(path=None):
    """Every saved preset. A missing or unreadable file gives the defaults."""
    path = path or presets_path()
    try:
        with open(path) as fh:
            data = json.load(fh)
    except (OSError, ValueError):
        return defaults()
    try:
        found = [Preset.from_json(p) for p in data["presets"]]
    except (KeyError, TypeError):
        return defaults()
    return found or defaults()


def save(presets, path=None):
    """Write them out, creating the config directory if need be."""
    path = path or presets_path()
    os.makedirs(os.path.dirname(path), exist_ok=True)
    body = {"version": VERSION, "presets": [p.to_json() for p in presets]}
    tmp = path + ".tmp"
    with open(tmp, "w") as fh:
        json.dump(body, fh, indent=2)
        fh.write("\n")
    os.replace(tmp, path)               # never leave a half-written file
