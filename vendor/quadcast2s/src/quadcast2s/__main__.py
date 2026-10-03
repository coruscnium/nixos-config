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

"""Entry point: `quadcast2s ...` or `python3 -m quadcast2s ...`."""
import json
import sys

from . import cli, daemon, effects
from .geometry import ZONES


def layers(sections):
    """Render each zone's mode into a Layer the daemon can composite."""
    return [daemon.Layer(ZONES[s.zone], effects.build(s.mode, s.built))
            for s in sections]


def main(argv=None):
    try:
        options, sections = cli.parse(sys.argv[1:] if argv is None else argv)
    except cli.Usage as e:
        sys.stderr.write(f"quadcast2s: {e}\n\n{cli.usage()}")
        return 2

    show = layers(sections)
    if options.dump:
        json.dump(daemon.sequence(show, options.frames), sys.stdout)
        sys.stdout.write("\n")
        return 0

    daemon.run(show, foreground=options.foreground, wait=options.wait)
    return 0


if __name__ == "__main__":
    sys.exit(main())
