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

"""The command line grammar, and the zone compositor.

Both are pure; nothing here opens the device.
"""
import contextlib
import io
import unittest

from quadcast2s import cli, daemon
from quadcast2s.__main__ import layers
from quadcast2s.geometry import BODY, RING


def parse(line):
    return cli.parse(line.split())


class TestParsing(unittest.TestCase):
    def test_bare_mode_fills_the_whole_microphone(self):
        _, sections = parse("solid")
        self.assertEqual([s.zone for s in sections], ["both"])
        self.assertEqual(sections[0].mode, "solid")

    def test_colours(self):
        _, sections = parse("solid ff0000 #00ff00")
        self.assertEqual(sections[0].colours, [(255, 0, 0), (0, 255, 0)])

    def test_zero_is_black(self):
        _, sections = parse("solid 0")
        self.assertEqual(sections[0].colours, [(0, 0, 0)])

    def test_two_zones_two_modes(self):
        _, sections = parse("--ring solid ffffff --body solid 003300")
        self.assertEqual([s.zone for s in sections], ["ring", "body"])

    def test_aliases(self):
        _, sections = parse("--upper solid --lower solid")
        self.assertEqual([s.zone for s in sections], ["ring", "body"])

    def test_options_bind_to_their_section(self):
        _, sections = parse("-b 50 --ring solid -s 20 --body solid")
        ring, body = (s.built for s in sections)
        self.assertEqual((ring.speed, ring.brightness), (20, 50))
        self.assertEqual((body.speed, body.brightness), (81, 50))

    def test_inline_values(self):
        _, sections = parse("solid --speed=30 --brightness=10")
        self.assertEqual(sections[0].built.speed, 30)
        self.assertEqual(sections[0].built.brightness, 10)

    def test_random_is_not_a_colour(self):
        _, sections = parse("solid random")
        self.assertTrue(sections[0].random)
        self.assertEqual(sections[0].colours, [])

    def test_zones_share_one_seed(self):
        # Otherwise each zone draws its own raindrops and its own flames.
        _, sections = parse("--ring solid --body solid")
        self.assertEqual(len({s.built.seed for s in sections}), 1)

    def test_rejects(self):
        for line in ("", "nonsense", "solid zzz", "solid --ring solid",
                     "--ring solid --ring solid", "--ring", "solid -s",
                     "solid -s 0", "solid -b 101", "solid --wat"):
            with self.assertRaises(cli.Usage, msg=line):
                parse(line)

    def test_help_and_version_exit_zero(self):
        for flag in ("--help", "-V"):
            with contextlib.redirect_stdout(io.StringIO()) as out:
                with self.assertRaises(SystemExit) as caught:
                    parse(flag)
            self.assertEqual(caught.exception.code, 0)
            self.assertIn("quadcast2s", out.getvalue())


class TestComposition(unittest.TestCase):
    def show(self, line):
        return layers(parse(line)[1])

    def test_zone_isolation(self):
        frame = daemon.compose(self.show("--ring solid ffffff --body solid 0"), 0)
        self.assertEqual([i for i, c in enumerate(frame) if any(c)], RING)

        frame = daemon.compose(self.show("--body solid ffffff --ring solid 0"), 0)
        self.assertEqual([i for i, c in enumerate(frame) if any(c)], BODY)

    def test_brightness(self):
        frame = daemon.compose(self.show("solid ffffff -b 50"), 0)
        self.assertEqual(frame[0], (127, 127, 127))

    def test_layers_loop_independently(self):
        # A one-frame layer must hold, not run off the end.
        show = self.show("solid ff0000")
        for t in (0, 1, 999):
            self.assertEqual(daemon.compose(show, t)[0], (255, 0, 0))

    def test_sequence_length(self):
        self.assertEqual(len(daemon.sequence(self.show("solid"), 40)), 40)


class TestInstanceMatching(unittest.TestCase):
    def test_matches_our_own_invocations(self):
        for args in (["/usr/local/bin/quadcast2s", "solid"],
                     ["python3", "-m", "quadcast2s", "solid"],
                     ["/usr/bin/python3", "/opt/src/quadcast2s/__main__.py"],
                     # installed console script: the shebang puts the
                     # interpreter in argv[0] and our name only in argv[1].
                     ["/v/bin/python3", "/v/bin/quadcast2s", "solid"],
                     ["/usr/bin/python3.14", "/usr/bin/quadcast2s"]):
            self.assertTrue(daemon._looks_like_us(args), args)

    def test_does_not_match_a_shell_sitting_in_the_project(self):
        # This is the `pkill -f` trap: the project directory is called
        # quadcast2s, so a text match on whole command lines kills your shell.
        for args in (["zsh"],
                     ["-zsh"],
                     ["zsh", "-c", "cd ~/src/quadcast2s && python3 -m quadcast2s"],
                     ["vim", "/home/x/quadcast2s/src/quadcast2s/daemon.py"],
                     ["python3", "tools/paint.py", "0xff0000"],
                     ["vim", "quadcast2s"],
                     ["ls", "-l", "quadcast2s"],
                     ["grep", "-r", "quadcast2s", "."]):
            self.assertFalse(daemon._looks_like_us(args), args)


if __name__ == "__main__":
    unittest.main()
