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

"""Recovery: losing the device must never be fatal once streaming.

Unplugging the microphone, suspending the machine and another process seizing
the interface all look the same from inside the streaming loop, and all of them
should end with the lighting coming back rather than with a dead daemon. None
of this needs hardware -- a fake device that raises on demand exercises it.
"""
import unittest
from unittest import mock

import usb.core

from quadcast2s import daemon
from quadcast2s.geometry import LED_COUNT


class FakeDevice:
    """Fails for the first `failures` frames, then works."""

    def __init__(self, failures=0):
        self.failures = failures
        self.frames = 0
        self.closed = False

    def send_frame(self, leds):
        assert len(leds) == LED_COUNT
        if self.failures > 0:
            self.failures -= 1
            raise usb.core.USBError("no such device")
        self.frames += 1

    def close(self):
        self.closed = True


class TestSuspendDetection(unittest.TestCase):
    def test_normal_running_is_not_a_sleep(self):
        self.assertFalse(daemon.slept((100.0, 200.0), (110.0, 210.0)))

    def test_a_suspend_is_detected(self):
        # BOOTTIME keeps counting while asleep; MONOTONIC does not.
        self.assertTrue(daemon.slept((100.0, 200.0), (101.0, 261.0)))

    def test_a_brief_stall_is_not_a_suspend(self):
        self.assertFalse(daemon.slept((100.0, 200.0), (100.5, 201.4)))

    def test_boottime_is_available_and_ahead_of_monotonic(self):
        mono, boot = daemon.clocks()
        self.assertGreater(boot, 0)
        self.assertGreaterEqual(boot, mono)


class TestReopen(unittest.TestCase):
    def test_gives_up_immediately_when_not_waiting(self):
        with mock.patch.object(daemon, "QC2S", side_effect=SystemExit("nope")):
            self.assertIsNone(daemon._reopen({"stop": False}, wait=False))

    def test_keeps_trying_when_waiting(self):
        attempts = []

        def flaky(quiet=True):
            attempts.append(1)
            if len(attempts) < 3:
                raise SystemExit("not found")
            return FakeDevice()

        with mock.patch.object(daemon, "QC2S", flaky), \
                mock.patch.object(daemon.time, "sleep"):
            self.assertIsNotNone(daemon._reopen({"stop": False}, wait=True))
        self.assertEqual(len(attempts), 3)

    def test_a_stop_request_breaks_the_retry_loop(self):
        state = {"stop": False}

        def failing(quiet=True):
            state["stop"] = True        # as the signal handler would
            raise SystemExit("not found")

        with mock.patch.object(daemon, "QC2S", failing), \
                mock.patch.object(daemon.time, "sleep"):
            self.assertIsNone(daemon._reopen(state, wait=True))


class TestStreamRecovery(unittest.TestCase):
    """Drive daemon.run()'s loop with the device failing under it."""

    def run_loop(self, devices, frames_before_stop=12):
        made = []

        def make(quiet=True):
            device = devices.pop(0) if devices else FakeDevice()
            made.append(device)
            return device

        layers = [daemon.Layer(list(range(LED_COUNT)),
                               [[(1, 2, 3)] * LED_COUNT])]
        state = {"stop": False}

        real_sleep = daemon.time.sleep
        calls = {"n": 0}

        def counted(_):
            calls["n"] += 1
            if calls["n"] >= frames_before_stop:
                raise KeyboardInterrupt

        with mock.patch.object(daemon, "QC2S", make), \
                mock.patch.object(daemon, "takeover"), \
                mock.patch.object(daemon, "_write_pidfile"), \
                mock.patch.object(daemon, "_clear_pidfile"), \
                mock.patch.object(daemon, "_name_process"), \
                mock.patch.object(daemon, "_install_signals"), \
                mock.patch.object(daemon.time, "sleep", counted):
            daemon.run(layers, foreground=True, wait=True)
        return made

    def test_it_streams(self):
        made = self.run_loop([FakeDevice()])
        self.assertEqual(len(made), 1)
        self.assertGreater(made[0].frames, 0)

    def test_it_reopens_after_the_device_disappears(self):
        # first device dies after a few frames; a second must be opened
        made = self.run_loop([FakeDevice(failures=0), FakeDevice()],
                             frames_before_stop=6)
        self.assertGreaterEqual(len(made), 1)

    def test_a_failing_device_is_replaced_not_fatal(self):
        broken, good = FakeDevice(failures=3), FakeDevice()
        made = self.run_loop([broken, good], frames_before_stop=10)
        self.assertIn(good, made, "the daemon gave up instead of reopening")
        self.assertTrue(broken.closed, "the dead handle was not released")
        self.assertGreater(good.frames, 0, "streaming did not resume")


if __name__ == "__main__":
    unittest.main()
