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

"""The main window.

Applying is a button rather than something that happens as you drag a slider.
Every apply spawns a process which takes the USB interface away from the one
already streaming, so doing it on every slider tick would thrash the device for
no benefit. The preview updates live instead, which is the part you actually
want to be immediate, and it costs nothing because it never touches hardware.
"""
import os

from PySide6.QtCore import Qt, QTimer
from PySide6.QtWidgets import (QCheckBox, QComboBox, QHBoxLayout, QInputDialog,
                               QLabel, QMainWindow, QMessageBox, QPushButton,
                               QSplitter, QTabWidget, QVBoxLayout, QWidget)

from .. import daemon, effects
from ..colour import parse
from ..geometry import ZONES
from . import autostart, presets, runner
from .controls import ZonePanel
from .preview import LedPreview

REBUILD_DELAY = 120                     # ms; fire takes ~28ms to build
STATUS_POLL = 2000


class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("quadcast2s")
        self.resize(940, 580)
        self._presets = presets.load()
        self._loading = False

        self.preview = LedPreview()
        self.split_zones = QCheckBox("Control the ring and the body separately")
        self.both = ZonePanel("both", "Whole microphone")
        self.ring = ZonePanel("ring", "Ring (12 LEDs on top)")
        self.body = ZonePanel("body", "Body (12 columns of 8)")

        # Before anything that can ask for a rebuild: loading a preset does.
        self._rebuild = QTimer(self)
        self._rebuild.setSingleShot(True)
        self._rebuild.timeout.connect(self._refresh_preview)
        self._poll = QTimer(self)
        self._poll.timeout.connect(self._refresh_status)

        self._build_layout()
        self._connect()
        self._load_presets_into_combos()
        self._load_autostart()
        self._select_preset(0)

        self._poll.start(STATUS_POLL)
        self._refresh_preview()
        self._refresh_status()

    # -------------------------------------------------------------- layout

    def _build_layout(self):
        bar = QWidget()
        top = QHBoxLayout(bar)
        top.setContentsMargins(8, 8, 8, 0)
        self.preset_box = QComboBox()
        self.preset_box.setMinimumWidth(180)
        self.save = QPushButton("Save")
        self.save_as = QPushButton("Save as…")
        self.delete = QPushButton("Delete")
        self.apply = QPushButton("Apply")
        self.apply.setDefault(True)
        self.stop = QPushButton("Stop")
        top.addWidget(QLabel("Preset"))
        top.addWidget(self.preset_box)
        top.addWidget(self.save)
        top.addWidget(self.save_as)
        top.addWidget(self.delete)
        top.addStretch(1)
        top.addWidget(self.apply)
        top.addWidget(self.stop)

        lighting = QWidget()
        column = QVBoxLayout(lighting)
        column.addWidget(self.split_zones)
        column.addWidget(self.both)
        column.addWidget(self.ring)
        column.addWidget(self.body)
        column.addStretch(1)

        self.tabs = QTabWidget()
        self.tabs.addTab(lighting, "Lighting")
        self.tabs.addTab(self._settings_tab(), "Settings")

        split = QSplitter(Qt.Horizontal)
        split.addWidget(self.preview)
        split.addWidget(self.tabs)
        split.setStretchFactor(0, 2)
        split.setStretchFactor(1, 3)

        page = QWidget()
        body = QVBoxLayout(page)
        body.setContentsMargins(0, 0, 0, 0)
        body.addWidget(bar)
        body.addWidget(split, 1)
        self.setCentralWidget(page)

        self.status = QLabel("")
        self.statusBar().addWidget(self.status)

    def _settings_tab(self):
        tab = QWidget()
        column = QVBoxLayout(tab)

        column.addWidget(QLabel("<b>Start lighting when:</b>"))
        self.start_login = QCheckBox("I log in")
        self.start_connect = QCheckBox("The microphone is connected")
        self.start_keep = QCheckBox(
            "Keep it running — restart after sleep, unplug or a crash")
        for box in (self.start_login, self.start_connect, self.start_keep):
            box.setContentsMargins(12, 0, 0, 0)
            column.addWidget(box)

        self.autostart_preset = QComboBox()
        self.autostart_preset.setMinimumWidth(180)
        row = QWidget()
        line = QHBoxLayout(row)
        line.setContentsMargins(22, 6, 0, 0)
        line.addWidget(QLabel("Preset to start with"))
        line.addWidget(self.autostart_preset)
        line.addStretch(1)
        self.autostart_row = row
        column.addWidget(row)

        note = QLabel(
            "The microphone never holds a frame: it stays lit only while the "
            "program is running, which is why starting it is a service rather "
            "than a one-off command.\n\n"
            "The lighting comes back by itself after the machine sleeps or the "
            "microphone is unplugged, however it was started — the daemon "
            "notices and reopens the device. The third option above is the "
            "backstop for anything that kills the process outright.")
        note.setWordWrap(True)
        note.setStyleSheet("color:palette(mid);")
        column.addSpacing(10)
        column.addWidget(note)
        column.addStretch(1)

        self.config_note = QLabel("")
        self.config_note.setStyleSheet("color:palette(mid);")
        self.config_note.setWordWrap(True)
        column.addWidget(self.config_note)
        return tab

    def _connect(self):
        self.split_zones.toggled.connect(self._zones_toggled)
        for panel in (self.both, self.ring, self.body):
            panel.changed.connect(self._queue_rebuild)
        self.preset_box.currentIndexChanged.connect(self._preset_chosen)
        self.save.clicked.connect(self._save)
        self.save_as.clicked.connect(self._save_as)
        self.delete.clicked.connect(self._delete)
        self.apply.clicked.connect(self._apply)
        self.stop.clicked.connect(self._stop)
        self.start_login.toggled.connect(self._autostart_changed)
        self.start_connect.toggled.connect(self._autostart_changed)
        self.start_keep.toggled.connect(self._autostart_changed)
        self.autostart_preset.currentIndexChanged.connect(
            self._autostart_changed)

    # -------------------------------------------------------------- presets

    def _zones_toggled(self, split):
        self.both.setVisible(not split)
        self.ring.setVisible(split)
        self.body.setVisible(split)
        self._queue_rebuild()

    def _panels(self):
        return ([self.ring, self.body] if self.split_zones.isChecked()
                else [self.both])

    def _current(self, name=None):
        """What is on screen, as a Preset."""
        return presets.Preset(name or self.preset_box.currentText(),
                              [p.value() for p in self._panels()])

    def _load_presets_into_combos(self):
        for box in (self.preset_box, self.autostart_preset):
            box.blockSignals(True)
            remembered = box.currentText()
            box.clear()
            box.addItems([p.name for p in self._presets])
            if remembered:
                box.setCurrentText(remembered)
            box.blockSignals(False)

    def _select_preset(self, row):
        self.preset_box.blockSignals(True)
        self.preset_box.setCurrentIndex(row)
        self.preset_box.blockSignals(False)
        self._show(self._presets[row])

    def _preset_chosen(self, row):
        if 0 <= row < len(self._presets):
            self._show(self._presets[row])

    def _show(self, preset):
        self._loading = True
        try:
            split = len(preset.zones) > 1 or preset.zones[0].zone != "both"
            self.split_zones.setChecked(split)
            self._zones_toggled(split)
            if split:
                for panel in (self.ring, self.body):
                    match = next((z for z in preset.zones
                                  if z.zone == panel.zone_name), None)
                    if match:
                        panel.set_value(match)
            else:
                self.both.set_value(preset.zones[0])
        finally:
            self._loading = False
        self._queue_rebuild()

    def _save(self):
        row = self.preset_box.currentIndex()
        if row < 0:
            return self._save_as()
        preset = self._current(self._presets[row].name)
        problems = presets.validate(preset)
        if problems:
            return self._complain(problems)
        self._presets[row] = preset
        presets.save(self._presets)
        self._flash(f"Saved “{preset.name}”")

    def _save_as(self):
        name, ok = QInputDialog.getText(self, "Save preset", "Name")
        if not ok or not name.strip():
            return
        name = name.strip()
        preset = self._current(name)
        problems = presets.validate(preset)
        if problems:
            return self._complain(problems)
        existing = next((i for i, p in enumerate(self._presets)
                         if p.name == name), None)
        if existing is None:
            self._presets.append(preset)
            existing = len(self._presets) - 1
        else:
            self._presets[existing] = preset
        presets.save(self._presets)
        self._load_presets_into_combos()
        self.preset_box.blockSignals(True)
        self.preset_box.setCurrentIndex(existing)
        self.preset_box.blockSignals(False)
        self._flash(f"Saved “{name}”")

    def _delete(self):
        row = self.preset_box.currentIndex()
        if row < 0 or len(self._presets) <= 1:
            return self._flash("The last preset cannot be deleted")
        name = self._presets[row].name
        confirm = QMessageBox.question(self, "Delete preset",
                                       f"Delete “{name}”?")
        if confirm != QMessageBox.Yes:
            return
        del self._presets[row]
        presets.save(self._presets)
        self._load_presets_into_combos()
        self._select_preset(min(row, len(self._presets) - 1))
        self._autostart_changed()
        self._flash(f"Deleted “{name}”")

    # ------------------------------------------------------------- hardware

    def _apply(self):
        preset = self._current()
        problems = presets.validate(preset)
        if problems:
            return self._complain(problems)
        ok, message = runner.apply(preset.args())
        self._flash(message if ok else f"Could not apply: {message}")
        self._refresh_status()

    def _stop(self):
        stopped = runner.stop()
        self._flash("Stopped" if stopped else "Nothing was running")
        self._refresh_status()

    def _refresh_status(self):
        args = runner.running()
        if args is None:
            self.status.setText("Not running — the microphone is showing its "
                                "own animation")
        else:
            self.status.setText("Streaming:  quadcast2s " + " ".join(args))

    # -------------------------------------------------------------- preview

    def _queue_rebuild(self, *_):
        if not self._loading:
            self._rebuild.start(REBUILD_DELAY)

    def _refresh_preview(self):
        layers = []
        for panel in self._panels():
            zone = panel.value()
            scheme = effects.Scheme(
                colours=[parse(c) for c in zone.colours] if not
                (zone.random and effects.TRAITS[zone.mode].random) else [],
                speed=zone.speed, delay=zone.delay,
                brightness=zone.brightness,
                random=zone.random, seed=1)
            layers.append(daemon.Layer(ZONES[zone.zone],
                                       effects.build(zone.mode, scheme)))
        self.preview.set_layers(layers)

    # ------------------------------------------------------------ autostart

    def _load_autostart(self):
        boxes = (self.start_login, self.start_connect, self.start_keep)
        for box in boxes:
            box.blockSignals(True)
        self.autostart_preset.blockSignals(True)

        usable = autostart.available()
        self.start_login.setChecked(usable and autostart.login_enabled())
        self.start_connect.setChecked(autostart.connect_enabled())
        self.start_keep.setChecked(autostart.keep_running_enabled())
        for box in boxes:
            box.setEnabled(usable)
        if not usable:
            self.config_note.setText(
                "No systemd user session was found, so these options are "
                "unavailable. The lighting can still be started by hand.")

        remembered = autostart.read_env()
        if remembered:
            match = next((p for p in self._presets
                          if p.args() == remembered), None)
            if match:
                self.autostart_preset.setCurrentText(match.name)

        for box in boxes:
            box.blockSignals(False)
        self.autostart_preset.blockSignals(False)
        self._sync_autostart_row()

    def _sync_autostart_row(self):
        self.autostart_row.setEnabled(
            self.start_login.isChecked() or self.start_connect.isChecked())

    def _autostart_changed(self, *_):
        """Apply all three switches.

        Each is a real mechanism rather than a preference this program has to
        remember and replay: enabling the unit, a flag file the udev-started
        unit tests for, and a drop-in.
        """
        self._sync_autostart_row()
        name = self.autostart_preset.currentText()
        preset = next((p for p in self._presets if p.name == name), None)
        if preset is not None:
            autostart.write_env(preset.args())

        problems = []
        for setter, wanted, what in (
                (autostart.set_login, self.start_login.isChecked(), "login"),
                (autostart.set_connect, self.start_connect.isChecked(),
                 "connect"),
                (autostart.set_keep_running, self.start_keep.isChecked(),
                 "restart")):
            ok, message = setter(wanted)
            if not ok:
                problems.append(f"{what}: {message}")

        if problems:
            self._flash("; ".join(problems))
            return
        chosen = [label for label, on in (
            ("log in", self.start_login.isChecked()),
            ("device connects", self.start_connect.isChecked()),
            ("keep running", self.start_keep.isChecked())) if on]
        self._flash("Starts on: " + (", ".join(chosen) if chosen else "nothing"))

    # ---------------------------------------------------------------- chrome

    def _flash(self, message):
        self.statusBar().showMessage(message, 4000)

    def _complain(self, problems):
        QMessageBox.warning(self, "quadcast2s", "\n".join(problems))
