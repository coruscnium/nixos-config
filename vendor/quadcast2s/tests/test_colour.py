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

"""Colour arithmetic: endpoints, saturation, monotonicity."""
import unittest

from quadcast2s import colour as c


class TestLerp(unittest.TestCase):
    def test_hits_both_endpoints(self):
        a, b = (10, 200, 3), (250, 0, 60)
        self.assertEqual(c.lerp(a, b, 0, 16), a)
        self.assertEqual(c.lerp(a, b, 16, 16), b)

    def test_segment_boundaries_do_not_repeat_a_frame(self):
        # The `total - 1` bug: with total - 1 a segment ends on the next
        # colour and the following segment starts on it, so the boundary
        # holds one value for two frames and the motion hitches.
        a, b, d = (0, 0, 0), (255, 255, 255), (0, 0, 255)
        seq = [c.lerp(a, b, s, 8) for s in range(8)]
        seq += [c.lerp(b, d, s, 8) for s in range(8)]
        for f0, f1 in zip(seq, seq[1:]):
            self.assertNotEqual(f0, f1)

    def test_monotonic(self):
        prev = -1
        for s in range(33):
            v = c.lerp((0, 0, 0), (255, 255, 255), s, 32)[0]
            self.assertGreaterEqual(v, prev)
            prev = v

    def test_zero_total_is_safe(self):
        self.assertEqual(c.lerp((1, 2, 3), (9, 9, 9), 0, 0), (1, 2, 3))


class TestArithmetic(unittest.TestCase):
    def test_scale(self):
        self.assertEqual(c.scale((255, 128, 0), 255), (255, 128, 0))
        self.assertEqual(c.scale((255, 128, 0), 0), (0, 0, 0))
        self.assertEqual(c.scale((200, 100, 50), 128)[0], 100)

    def test_add_saturates(self):
        self.assertEqual(c.add((200, 0, 0), (200, 40, 0)), (255, 40, 0))

    def test_distance(self):
        self.assertEqual(c.distance((0, 0, 0), (255, 255, 255)), 765)
        self.assertEqual(c.distance((1, 2, 3), (1, 2, 3)), 0)


class TestGamma(unittest.TestCase):
    def test_endpoints(self):
        self.assertEqual(c.gamma(0), 0)
        self.assertEqual(c.gamma(255), 255)

    def test_monotonic_and_convex(self):
        vals = [c.gamma(v) for v in range(256)]
        self.assertEqual(vals, sorted(vals))
        # darkens the middle, which is the whole point
        self.assertLess(c.gamma(128), 128)


class TestParse(unittest.TestCase):
    def test_forms(self):
        self.assertEqual(c.parse("ff0000"), (255, 0, 0))
        self.assertEqual(c.parse("#00ff00"), (0, 255, 0))
        self.assertEqual(c.parse("0"), (0, 0, 0))

    def test_rejects_rubbish(self):
        for bad in ("", "gg0000", "1234567", "#"):
            with self.assertRaises(ValueError):
                c.parse(bad)

    def test_round_trip(self):
        self.assertEqual(c.format(c.parse("3fa0ff")), "3fa0ff")


class TestPalettes(unittest.TestCase):
    def test_rainbow_is_nine_distinct_colours(self):
        self.assertEqual(len(c.RAINBOW), 9)
        self.assertEqual(len(set(c.RAINBOW)), 9)

    def test_rainbow_starts_at_red(self):
        self.assertEqual(c.RAINBOW[0], (255, 0, 0))


if __name__ == "__main__":
    unittest.main()
