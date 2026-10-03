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

"""Effects, checked the way docs/TESTING.md says to check them.

No hardware: every effect is a pure function of its scheme, so the loop can be
generated and measured here. The two checks that earn their keep are the loop
seam and the response to --speed; both catch bugs that are invisible in code
review and expensive to find by eye.

Note that the random effects differ between runs by design. Everything here
pins the seed, and test_same_seed_is_reproducible is what stops a comparison
between two runs being mistaken for a real difference.
"""
import statistics
import unittest

from quadcast2s import colour, geometry
from quadcast2s.effects import EFFECTS, build, names
from quadcast2s.effects.base import Rng, Scheme, cycles
from quadcast2s.effects.simple import apportion, gradient

STATIC = {"solid"}
ANIMATED = sorted(set(EFFECTS) - STATIC)
SPEEDS = (1, 20, 40, 60, 80, 100)


def frame_delta(f0, f1):
    lum = colour.luminance
    return sum(abs(lum(a) - lum(b)) for a, b in zip(f0, f1)) / len(f0)


def motion(frames):
    """Mean, spread and worst per-LED luminance change between frames."""
    d = [frame_delta(a, b) for a, b in zip(frames, frames[1:])]
    if not d:
        return 0.0, 0.0, 0.0
    return statistics.mean(d), statistics.pstdev(d), max(d)


def mean_motion(mode, speed, seeds=(1, 7, 99)):
    """Averaged over seeds, so a random effect's noise does not mask a trend."""
    return statistics.mean(
        motion(build(mode, Scheme(speed=speed, seed=s)))[0] for s in seeds)


class TestEveryEffect(unittest.TestCase):
    def test_shape(self):
        for mode in names():
            frames = build(mode, Scheme())
            self.assertGreaterEqual(len(frames), 1, mode)
            for frame in frames:
                self.assertEqual(len(frame), geometry.LED_COUNT, mode)
            for frame in frames:
                for col in frame:
                    self.assertEqual(len(col), 3, mode)
                    self.assertTrue(all(0 <= v <= 255 for v in col), mode)

    def test_loop_seam(self):
        # The wrap must be no worse than a normal frame step, or the
        # animation visibly jumps every time the loop repeats.
        for mode in ANIMATED:
            frames = build(mode, Scheme())
            _, _, worst = motion(frames)
            self.assertLessEqual(frame_delta(frames[-1], frames[0]), worst,
                                 f"{mode} jumps at the loop seam")

    def test_speed_is_monotonic(self):
        # `-s` must do something in every animated mode. It is easy for an
        # effect to ignore it and look like it responded, because the motion
        # is random enough to seem different.
        for mode in ANIMATED:
            means = [mean_motion(mode, s) for s in SPEEDS]
            self.assertEqual(means, sorted(means),
                             f"{mode} does not speed up: {means}")
            self.assertGreater(means[-1], means[0] * 1.5,
                               f"{mode} barely responds to --speed: {means}")

    def test_same_seed_is_reproducible(self):
        for mode in names():
            self.assertEqual(build(mode, Scheme(seed=4321)),
                             build(mode, Scheme(seed=4321)), mode)

    def test_brightness(self):
        for mode in names():
            dark = build(mode, Scheme(brightness=0))
            self.assertFalse(any(any(c) for f in dark for c in f),
                             f"{mode} ignores --brightness")
            full = build(mode, Scheme(brightness=100, seed=11))
            half = build(mode, Scheme(brightness=50, seed=11))
            self.assertLess(sum(sum(c) for f in half for c in f),
                            sum(sum(c) for f in full for c in f), mode)


class TestDefaultPalettes(unittest.TestCase):
    def test_traits_cover_every_mode(self):
        from quadcast2s.effects import TRAITS
        self.assertEqual(set(TRAITS), set(EFFECTS))

    def test_naming_the_default_colours_changes_nothing(self):
        # The GUI always sends explicit colours. That must be indistinguishable
        # from sending none, or the preview and the presets would both lie.
        from quadcast2s.effects import TRAITS
        for mode, traits in TRAITS.items():
            if mode == "blink":
                continue            # invents random colours when given none
            self.assertEqual(
                build(mode, Scheme(seed=3)),
                build(mode, Scheme(colours=traits.palette, seed=3)),
                f"{mode} differs when its own default colours are named")


class TestApportion(unittest.TestCase):
    def test_sums_exactly(self):
        for total in (10, 37, 216, 300):
            for weights in ([1, 1, 1], [170] * 9, [16, 526, 510, 510], [0, 0]):
                self.assertEqual(sum(apportion(weights, total)), total)

    def test_floor_of_one(self):
        self.assertTrue(all(s >= 1 for s in apportion([1, 1000], 20)))

    def test_proportional(self):
        share = apportion([100, 300], 40)
        self.assertEqual(share, [10, 30])

    def test_identical_colours_split_evenly(self):
        self.assertEqual(apportion([0, 0, 0], 30), [10, 10, 10])


class TestGradient(unittest.TestCase):
    def test_even_steps_on_an_uneven_palette(self):
        # The "slinky": splitting a loop evenly makes short hops crawl and
        # long ones race. Budgeting by distance is what fixes it.
        palette = [(255, 0, 0), (255, 0, 16), (0, 255, 0), (0, 0, 255)]
        seq = gradient(palette, 96)
        steps = [colour.distance(seq[i], seq[(i + 1) % len(seq)])
                 for i in range(len(seq))]
        self.assertLess(statistics.pstdev(steps), 3.0, steps)

    def test_closes_the_loop(self):
        seq = gradient(colour.RAINBOW, 216)
        self.assertEqual(len(seq), 216)
        self.assertEqual(seq[0], colour.RAINBOW[0])

    def test_single_colour_is_constant(self):
        self.assertEqual(set(gradient([(9, 9, 9)], 20)), {(9, 9, 9)})


class TestTravel(unittest.TestCase):
    def test_cycle_is_uniform(self):
        for frame in build("cycle", Scheme()):
            self.assertEqual(len(set(frame)), 1)

    def test_wave_spans_all_twelve_columns(self):
        for frame in build("wave", Scheme()):
            seen = {frame[geometry.index(c, 0)] for c in range(12)}
            self.assertEqual(len(seen), 12)

    def test_wave_travels_one_way_around(self):
        frames = build("wave", Scheme())
        step = len(frames) // 12
        start = frames[0][geometry.index(0, 0)]
        where = [next(c for c in range(12)
                      if frames[k * step][geometry.index(c, 0)] == start)
                 for k in range(3)]
        self.assertEqual(where, [0, 11, 10])

    def test_vertical_climbs(self):
        frames = build("vertical", Scheme())
        step = len(frames) // 8
        start = frames[0][geometry.index(0, 0)]
        where = [next(r for r in range(8)
                      if frames[k * step][geometry.index(0, r)] == start)
                 for k in range(3)]
        self.assertEqual(where, [0, 1, 2])

    def test_vertical_is_flat_around_the_microphone(self):
        for frame in build("vertical", Scheme()):
            for r in range(8):
                row = {frame[geometry.index(c, r)] for c in range(12)}
                self.assertEqual(len(row), 1)

    def test_ring_continues_the_top_of_the_body(self):
        # Eight rows span one full loop, so the ring lands back in phase.
        for frame in build("vertical", Scheme()):
            self.assertEqual(frame[geometry.index(0, 8)],
                             frame[geometry.index(0, 0)])


class TestBlink(unittest.TestCase):
    def test_goes_fully_dark(self):
        frames = build("blink", Scheme(colours=[(255, 0, 0)]))
        self.assertTrue(any(not any(c) for f in frames for c in f))

    def test_delay_lengthens_the_gap(self):
        short = build("blink", Scheme(colours=[(255, 0, 0)], delay=4))
        long = build("blink", Scheme(colours=[(255, 0, 0)], delay=40))
        self.assertEqual(len(long) - len(short), 36)

    def test_invents_colours_when_none_are_given(self):
        frames = build("blink", Scheme(seed=5))
        lit = {f[0] for f in frames if any(f[0])}
        self.assertGreater(len(lit), 1)


class TestFlash(unittest.TestCase):
    def test_ramps_reach_their_endpoints(self):
        frames = build("pulse", Scheme(colours=[(255, 0, 0)]))
        flat = [f[0] for f in frames]
        self.assertIn((255, 0, 0), flat, "the flash never reaches full")
        self.assertIn((0, 0, 0), flat, "the flash never reaches black")

    def test_pulse_keeps_the_given_order(self):
        palette = [(255, 0, 0), (0, 255, 0), (0, 0, 255)]
        frames = build("pulse", Scheme(colours=palette))
        peaks = [f[0] for f in frames if f[0] in palette]
        self.assertEqual([p for i, p in enumerate(peaks)
                          if i == 0 or peaks[i - 1] != p], palette)


class TestBase(unittest.TestCase):
    def test_cycles_divides_exactly_and_takes_the_nearest(self):
        for want in range(1, 40):
            k = cycles(300, want)
            self.assertEqual(300 % k, 0)
        self.assertEqual(cycles(300, 7), 6)      # 6 is nearer than 10
        self.assertEqual(cycles(300, 13), 12)    # 12 is nearer than 15
        self.assertEqual(cycles(300, 11), 12)    # a tie; the rule takes up

    def test_rng_is_reproducible_and_bounded(self):
        a, b = Rng(1234), Rng(1234)
        self.assertEqual([a(50) for _ in range(20)], [b(50) for _ in range(20)])
        self.assertTrue(all(0 <= Rng(7)(12) < 12 for _ in range(50)))

    def test_rng_zero_length(self):
        self.assertEqual(Rng(3)(0), 0)


if __name__ == "__main__":
    unittest.main()
