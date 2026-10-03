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

"""Geometry: the ring/body partition and the grid round trip.

Needs no hardware. The facts asserted here come from docs/PROTOCOL.md section 4
and were established visually against a real microphone.
"""
import unittest

from quadcast2s import geometry as g


class TestZones(unittest.TestCase):
    def test_counts(self):
        self.assertEqual(g.LED_COUNT, 108)
        self.assertEqual(len(g.RING), 12)
        self.assertEqual(len(g.BODY), 96)

    def test_ring_is_exactly_offsets_8_and_9(self):
        self.assertEqual(g.RING, [i for i in range(108) if i % 18 in (8, 9)])

    def test_zones_partition_every_led(self):
        self.assertEqual(sorted(g.RING + g.BODY), list(range(108)))


class TestGrid(unittest.TestCase):
    def test_body_covers_12_columns_by_8_rows(self):
        cells = [g.cell(i) for i in g.BODY]
        self.assertEqual(len(set(cells)), 96, "duplicate body cells")
        self.assertEqual(sorted(set(cells)),
                         sorted((c, r) for c in range(12) for r in range(8)))

    def test_ring_covers_all_12_columns_once(self):
        self.assertEqual(sorted(g.column(i) for i in g.RING), list(range(12)))
        self.assertTrue(all(g.row(i) == g.RING_ROW for i in g.RING))

    def test_round_trip(self):
        for i in range(108):
            self.assertEqual(g.index(*g.cell(i)), i)

    def test_every_cell_is_occupied_once(self):
        self.assertEqual(len(g.INDEX), 12 * 9)

    def test_serpentine_run(self):
        # A block climbs column 2b, crosses the ring, comes back down 2b+1.
        for b in range(6):
            base = 18 * b
            self.assertEqual([g.cell(base + k) for k in range(8)],
                             [(2 * b, r) for r in range(8)])
            self.assertEqual(g.cell(base + 8), (2 * b, 8))
            self.assertEqual(g.cell(base + 9), (2 * b + 1, 8))
            self.assertEqual([g.cell(base + 10 + k) for k in range(8)],
                             [(2 * b + 1, 7 - r) for r in range(8)])

    def test_grid_to_leds(self):
        grid = g.blank_grid()
        grid[8] = [(1, 2, 3)] * 12
        leds = g.grid_to_leds(grid)
        self.assertEqual([i for i, c in enumerate(leds) if any(c)], g.RING)


if __name__ == "__main__":
    unittest.main()
