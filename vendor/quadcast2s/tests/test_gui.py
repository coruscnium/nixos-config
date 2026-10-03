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

"""Presets, autostart and the runner.

These are deliberately free of Qt so they can be tested without a display, in
the same spirit as the effects being testable without hardware. Every test
redirects XDG_CONFIG_HOME into a temporary directory: none of this ever touches
the real configuration.
"""
import os
import tempfile
import unittest
from unittest import mock

from quadcast2s.effects import TRAITS
from quadcast2s.gui import autostart, presets


class Sandbox(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.old = os.environ.get("XDG_CONFIG_HOME")
        os.environ["XDG_CONFIG_HOME"] = self.tmp.name

    def tearDown(self):
        if self.old is None:
            os.environ.pop("XDG_CONFIG_HOME", None)
        else:
            os.environ["XDG_CONFIG_HOME"] = self.old
        self.tmp.cleanup()


class TestArgs(Sandbox):
    def test_whole_microphone(self):
        zone = presets.Zone(mode="solid", colours=["ff0000"], brightness=60)
        self.assertEqual(zone.args(), ["solid", "ff0000", "-b", "60"])

    def test_zone_flag_comes_first(self):
        zone = presets.Zone(zone="ring", mode="wave")
        self.assertEqual(zone.args()[0], "--ring")

    def test_speed_is_omitted_where_the_mode_ignores_it(self):
        self.assertNotIn("-s", presets.Zone(mode="solid").args())
        self.assertIn("-s", presets.Zone(mode="wave").args())

    def test_delay_only_for_blink(self):
        self.assertIn("-d", presets.Zone(mode="blink", delay=90).args())
        self.assertNotIn("-d", presets.Zone(mode="cycle", delay=90).args())

    def test_extra_colours_dropped_where_only_one_is_used(self):
        zone = presets.Zone(mode="fire", colours=["ff4000", "00ff00"])
        self.assertEqual(zone.args()[:2], ["fire", "ff4000"])

    def test_random_replaces_the_colours(self):
        zone = presets.Zone(mode="rain", colours=["ff0000"], random=True)
        self.assertIn("random", zone.args())
        self.assertNotIn("ff0000", zone.args())

    def test_random_ignored_where_the_mode_has_no_use_for_it(self):
        zone = presets.Zone(mode="wave", colours=["ff0000"], random=True)
        self.assertNotIn("random", zone.args())

    def test_every_default_preset_is_a_valid_command_line(self):
        from quadcast2s import cli
        for preset in presets.defaults():
            self.assertEqual(presets.validate(preset), [], preset.name)
            options, sections = cli.parse(preset.args())
            self.assertEqual(len(sections), len(preset.zones))

    def test_every_mode_round_trips_through_the_parser(self):
        from quadcast2s import cli
        for mode in TRAITS:
            preset = presets.Preset("t", [presets.Zone(mode=mode)])
            _, sections = cli.parse(preset.args())
            self.assertEqual(sections[0].mode, mode)


class TestStorage(Sandbox):
    def test_round_trip(self):
        original = presets.defaults()
        presets.save(original)
        again = presets.load()
        self.assertEqual([p.name for p in again], [p.name for p in original])
        self.assertEqual([p.args() for p in again], [p.args() for p in original])

    def test_missing_file_gives_defaults(self):
        self.assertTrue(presets.load())

    def test_rubbish_file_gives_defaults(self):
        path = presets.presets_path()
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as fh:
            fh.write("{not json")
        self.assertTrue(presets.load())

    def test_save_is_atomic(self):
        presets.save(presets.defaults())
        leftovers = [f for f in os.listdir(os.path.dirname(presets.presets_path()))
                     if f.endswith(".tmp")]
        self.assertEqual(leftovers, [])


class TestValidate(Sandbox):
    def test_accepts_a_normal_preset(self):
        self.assertEqual(presets.validate(presets.defaults()[0]), [])

    def test_rejects(self):
        cases = {
            "no name": presets.Preset(" "),
            "unknown mode": presets.Preset("x", [presets.Zone(mode="stars")]),
            "bad colour": presets.Preset("x", [presets.Zone(colours=["zz"])]),
            "same zone twice": presets.Preset("x", [presets.Zone(zone="ring"),
                                                    presets.Zone(zone="ring")]),
            "zone plus both": presets.Preset("x", [presets.Zone(zone="both"),
                                                   presets.Zone(zone="ring")]),
            "brightness": presets.Preset("x", [presets.Zone(brightness=140)]),
        }
        for why, preset in cases.items():
            self.assertTrue(presets.validate(preset), why)


class TestAutostart(Sandbox):
    """The three start triggers.

    systemctl is stubbed: these check that the right call is made and that the
    file-based switches land in the right place, not that systemd works.
    """

    def test_all_three_are_off_by_default(self):
        self.assertFalse(autostart.connect_enabled())
        self.assertFalse(autostart.keep_running_enabled())

    def test_connect_flag_is_a_plain_file_in_the_users_config(self):
        # No root needed: the udev-started unit tests for this path, so opting
        # in never means editing a udev rule.
        autostart.set_connect(True)
        self.assertTrue(autostart.connect_enabled())
        self.assertTrue(autostart.connect_flag().startswith(self.tmp.name))
        autostart.set_connect(False)
        self.assertFalse(autostart.connect_enabled())

    def test_keep_running_writes_a_drop_in(self):
        with mock.patch.object(autostart, "systemctl",
                               return_value=(True, "")):
            autostart.set_keep_running(True)
            self.assertTrue(autostart.keep_running_enabled())
            with open(autostart.dropin_path()) as fh:
                body = fh.read()
            self.assertIn("[Service]", body)
            self.assertIn("Restart=always", body)
            autostart.set_keep_running(False)
        self.assertFalse(autostart.keep_running_enabled())

    def test_login_enables_the_unit(self):
        calls = []

        def fake(*args, check=False):
            calls.append(args)
            return True, ""

        with mock.patch.object(autostart, "systemctl", fake):
            autostart.set_login(True)
            autostart.set_login(False)
        # `enable` alone would not start it until the next login, which reads
        # as the switch doing nothing.
        self.assertEqual(calls, [("enable", "--now", "quadcast2s.service"),
                                 ("disable", "quadcast2s.service")])

    def test_enabling_login_removes_the_legacy_xdg_entry(self):
        # Both mechanisms at once would start two daemons.
        legacy = autostart.legacy_desktop_path()
        os.makedirs(os.path.dirname(legacy), exist_ok=True)
        open(legacy, "w").close()
        with mock.patch.object(autostart, "systemctl",
                               return_value=(True, "")):
            autostart.set_login(True)
        self.assertFalse(os.path.exists(legacy))

    def test_env_round_trip(self):
        args = ["--ring", "rain", "3fa0ff", "-b", "100"]
        autostart.write_env(args)
        self.assertEqual(autostart.read_env(), args)

    def test_env_file_is_shell_free(self):
        # systemd parses EnvironmentFile itself; it is not run by a shell.
        autostart.write_env(["fire", "ff4000", "-s", "40"])
        with open(autostart.env_path()) as fh:
            body = fh.read()
        self.assertIn("QUADCAST2S_ARGS=fire ff4000 -s 40", body)

    def test_command_is_absolute(self):
        # A service runs without a shell's PATH.
        self.assertTrue(os.path.isabs(autostart.command()[0]))

    def test_command_prefers_the_script_beside_the_interpreter(self):
        import sys
        import tempfile
        with tempfile.TemporaryDirectory() as fake:
            bin_dir = os.path.join(fake, "bin")
            os.makedirs(bin_dir)
            script = os.path.join(bin_dir, "quadcast2s")
            open(script, "w").close()
            os.chmod(script, 0o755)
            real = sys.executable
            sys.executable = os.path.join(bin_dir, "python3")
            try:
                self.assertEqual(autostart.command(), [script])
            finally:
                sys.executable = real


class TestRunnerAndService(Sandbox):
    """The GUI must cooperate with the service, not race it."""

    def test_apply_goes_through_the_service_when_it_is_running(self):
        # Spawning a daemon directly would take the interface off the
        # service's process; systemd restarts it and takes it straight back,
        # so the change reverts after a couple of seconds.
        from quadcast2s.gui import runner
        with mock.patch.object(autostart, "service_active", return_value=True), \
                mock.patch.object(autostart, "restart",
                                  return_value=(True, "")) as restarted, \
                mock.patch.object(runner.subprocess, "run") as spawned:
            ok, _ = runner.apply(["fire", "ff4000"])
        self.assertTrue(ok)
        restarted.assert_called_once()
        spawned.assert_not_called()
        self.assertEqual(autostart.read_env(), ["fire", "ff4000"])

    def test_apply_spawns_directly_when_no_service_is_running(self):
        from quadcast2s.gui import runner
        done = mock.Mock(returncode=0, stdout="", stderr="")
        with mock.patch.object(autostart, "service_active", return_value=False), \
                mock.patch.object(runner.subprocess, "run",
                                  return_value=done) as spawned:
            ok, _ = runner.apply(["solid", "ff0000"])
        self.assertTrue(ok)
        spawned.assert_called_once()

    def test_stop_stops_the_service_first(self):
        # Killing the process alone would just prompt a restart.
        from quadcast2s.gui import runner
        with mock.patch.object(autostart, "service_active", return_value=True), \
                mock.patch.object(autostart, "stop",
                                  return_value=(True, "")) as stopped, \
                mock.patch.object(runner.daemon, "instances", return_value=[]):
            self.assertEqual(runner.stop(), 1)
        stopped.assert_called_once()


try:
    os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
    from PySide6.QtWidgets import QApplication, QColorDialog
    HAVE_QT = True
except ImportError:                     # the GUI is an optional extra
    HAVE_QT = False


@unittest.skipUnless(HAVE_QT, "PySide6 is not installed")
class TestSwatchStyling(Sandbox):
    """The colour picker must not be painted in the colour being picked.

    Qt style sheets cascade into child widgets, and a dialog is a child. An
    unscoped `background-color` on the swatch turned every label, spin box and
    button in QColorDialog the same colour, which made it unusable.
    """

    app = None

    def setUp(self):
        super().setUp()
        if TestSwatchStyling.app is None:
            TestSwatchStyling.app = QApplication.instance() or QApplication([])

    def test_stylesheet_is_scoped_to_the_button(self):
        from quadcast2s.gui.controls import Swatch
        sheet = Swatch("ff0000").styleSheet()
        self.assertIn("#swatch", sheet,
                      "an unscoped rule cascades into every child widget")
        self.assertTrue(sheet.lstrip().startswith("QPushButton#swatch"), sheet)

    def test_a_child_dialog_is_not_repainted(self):
        from quadcast2s.gui.controls import Swatch
        swatch = Swatch("ff0000")
        swatch.show()
        dialog = QColorDialog(swatch)       # worst case: parented to the swatch
        dialog.setOption(QColorDialog.DontUseNativeDialog)
        dialog.show()
        self.app.processEvents()
        image = dialog.grab().toImage()

        red = 0
        total = 0
        for y in range(0, image.height(), 4):
            for x in range(0, image.width(), 4):
                pixel = image.pixelColor(x, y)
                total += 1
                if pixel.red() > 200 and pixel.green() < 60 and pixel.blue() < 60:
                    red += 1
        dialog.close()
        swatch.close()
        self.assertLess(red / max(total, 1), 0.25,
                        "the swatch colour has flooded the colour dialog")


if __name__ == "__main__":
    unittest.main()
