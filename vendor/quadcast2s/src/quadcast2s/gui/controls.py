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

"""The per-zone controls.

The command line lets the ring and the body each run a different mode, so the
panel below is exactly one section of it and the window shows either one panel
or two. Whatever a panel reads back is a presets.Zone, which is the same object
that gets saved and the same one that turns into argv.

Controls that a mode ignores are disabled rather than left to look as though
they work -- `-d` only means anything to `blink`, `solid` has no speed, and
several modes use only the first colour they are given. That mapping lives in
effects.TRAITS so this file is not a second opinion about it.
"""
from PySide6.QtCore import Qt, Signal
from PySide6.QtGui import QColor
from PySide6.QtWidgets import (QCheckBox, QColorDialog, QComboBox, QFormLayout,
                               QGroupBox, QHBoxLayout, QLabel, QPushButton,
                               QSlider, QSpinBox, QVBoxLayout, QWidget)

from .. import colour
from ..effects import TRAITS, names
from . import presets

MAX_COLOURS = 9
SWATCH = 30


class Swatch(QPushButton):
    """One colour, opening a picker when clicked."""

    picked = Signal()

    def __init__(self, value="ff0000", parent=None):
        super().__init__(parent)
        self.setObjectName("swatch")
        self.setFixedSize(SWATCH, SWATCH)
        self.setCursor(Qt.PointingHandCursor)
        self.set_value(value)
        self.clicked.connect(self._choose)

    def set_value(self, value):
        self._value = value.lower()
        r, g, b = colour.parse(self._value)
        # a light border on dark colours, so black is still visibly a swatch
        edge = "#666" if r + g + b < 120 else "rgba(0,0,0,80)"
        # Scoped to this one button by object name. Qt style sheets cascade to
        # every child widget, and a dialog opened from here is a child: an
        # unscoped rule painted the entire colour picker -- labels, spin boxes,
        # OK and Cancel -- in the colour being picked, and made it unreadable.
        self.setStyleSheet(
            f"QPushButton#swatch {{ background-color:#{self._value};"
            f"border:1px solid {edge};border-radius:4px; }}")
        self.setToolTip(f"#{self._value}")

    def value(self):
        return self._value

    def _choose(self):
        start = QColor(*colour.parse(self._value))
        # Parent on the window rather than on this button, so the dialog is not
        # a child of a styled widget in the first place.
        chosen = QColorDialog.getColor(start, self.window(), "Colour")
        if chosen.isValid():
            self.set_value("%02x%02x%02x" % (chosen.red(), chosen.green(),
                                             chosen.blue()))
            self.picked.emit()


class ColourList(QWidget):
    """A row of swatches, with buttons to add and remove one."""

    changed = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._swatches = []
        self._limit = MAX_COLOURS
        row = QHBoxLayout(self)
        row.setContentsMargins(0, 0, 0, 0)
        row.setSpacing(4)
        self._row = row
        self._add = QPushButton("+")
        self._remove = QPushButton("−")
        for button, slot in ((self._add, self._add_one),
                             (self._remove, self._remove_one)):
            button.setFixedSize(SWATCH, SWATCH)
            button.clicked.connect(slot)
        row.addWidget(self._add)
        row.addWidget(self._remove)
        row.addStretch(1)
        self.set_values(["ff0000"])

    def set_limit(self, limit):
        """How many colours this mode will actually use."""
        self._limit = limit or MAX_COLOURS
        while len(self._swatches) > self._limit:
            self._drop_last()
        self._sync_buttons()

    def values(self):
        return [s.value() for s in self._swatches]

    def set_values(self, values):
        values = [v.lower() for v in values] or ["ff0000"]
        while self._swatches:
            self._drop_last()
        for value in values[:self._limit]:
            self._append(value)
        self._sync_buttons()

    def _append(self, value):
        swatch = Swatch(value, self)
        swatch.picked.connect(self.changed)
        self._row.insertWidget(len(self._swatches), swatch)
        self._swatches.append(swatch)

    def _drop_last(self):
        swatch = self._swatches.pop()
        self._row.removeWidget(swatch)
        swatch.deleteLater()

    def _add_one(self):
        if len(self._swatches) < self._limit:
            last = self._swatches[-1].value() if self._swatches else "ff0000"
            self._append(last)
            self._sync_buttons()
            self.changed.emit()

    def _remove_one(self):
        if len(self._swatches) > 1:
            self._drop_last()
            self._sync_buttons()
            self.changed.emit()

    def _sync_buttons(self):
        self._add.setEnabled(len(self._swatches) < self._limit)
        self._remove.setEnabled(len(self._swatches) > 1)


class ZonePanel(QGroupBox):
    """One section of the command line."""

    changed = Signal()

    def __init__(self, zone="both", title="Whole microphone", parent=None):
        super().__init__(title, parent)
        self.zone_name = zone
        self._quiet = False

        self.mode = QComboBox()
        self.mode.addItems(names())
        self.mode.setCurrentText("solid")

        self.colours = ColourList()
        self.colours.set_values(presets.default_colours("solid"))
        self.random = QCheckBox("pick colours automatically")

        self.speed = QSlider(Qt.Horizontal)
        self.speed.setRange(1, 100)
        self.speed.setValue(presets.DEFAULT_SPEED)
        self.speed_value = QLabel(str(presets.DEFAULT_SPEED))
        self.speed_value.setMinimumWidth(28)

        self.brightness = QSlider(Qt.Horizontal)
        self.brightness.setRange(0, 100)
        self.brightness.setValue(100)
        self.brightness_value = QLabel("100")
        self.brightness_value.setMinimumWidth(28)

        self.delay = QSpinBox()
        self.delay.setRange(0, 600)
        self.delay.setValue(20)
        self.delay.setSuffix(" frames")

        form = QFormLayout(self)
        form.addRow("Mode", self.mode)
        form.addRow("Colours", self.colours)
        form.addRow("", self.random)
        form.addRow("Speed", self._with_value(self.speed, self.speed_value))
        form.addRow("Brightness",
                    self._with_value(self.brightness, self.brightness_value))
        form.addRow("Off time", self.delay)

        self.mode.currentTextChanged.connect(self._mode_changed)
        self.colours.changed.connect(self._emit)
        self.random.toggled.connect(self._random_changed)
        self.speed.valueChanged.connect(self._speed_changed)
        self.brightness.valueChanged.connect(self._brightness_changed)
        self.delay.valueChanged.connect(self._emit)
        self._sync_traits()

    @staticmethod
    def _with_value(slider, label):
        box = QWidget()
        row = QHBoxLayout(box)
        row.setContentsMargins(0, 0, 0, 0)
        row.addWidget(slider)
        row.addWidget(label)
        return box

    # ------------------------------------------------------------- reactions

    def _emit(self, *_):
        if not self._quiet:
            self.changed.emit()

    def _speed_changed(self, value):
        self.speed_value.setText(str(value))
        self._emit()

    def _brightness_changed(self, value):
        self.brightness_value.setText(str(value))
        self._emit()

    def _random_changed(self, *_):
        self._sync_traits()
        self._emit()

    def _mode_changed(self, *_):
        self._sync_traits()
        self._emit()

    def _sync_traits(self):
        """Grey out whatever this mode ignores."""
        traits = TRAITS[self.mode.currentText()]
        self.random.setEnabled(traits.random)
        if not traits.random:
            self.random.setChecked(False)
        automatic = traits.random and self.random.isChecked()
        self.colours.setEnabled(not automatic)
        self.colours.set_limit(traits.colours)
        self.speed.setEnabled(traits.speed)
        self.speed_value.setEnabled(traits.speed)
        self.delay.setEnabled(traits.delay)

    # ------------------------------------------------------------ the value

    def value(self):
        return presets.Zone(
            zone=self.zone_name, mode=self.mode.currentText(),
            colours=self.colours.values(), speed=self.speed.value(),
            brightness=self.brightness.value(),
            delay=self.delay.value() if TRAITS[self.mode.currentText()].delay
            else None,
            random=self.random.isChecked())

    def set_value(self, zone):
        self._quiet = True                  # one signal at the end, not ten
        try:
            self.mode.setCurrentText(zone.mode)
            # A preset naming no colours means "whatever the mode uses by
            # default". Show those, so the swatches are never a lie about what
            # will be sent -- and so saving cannot silently replace a rainbow
            # with one red.
            self.colours.set_values(zone.colours
                                    or presets.default_colours(zone.mode))
            self.random.setChecked(zone.random)
            self.speed.setValue(zone.speed)
            self.brightness.setValue(zone.brightness)
            if zone.delay is not None:
                self.delay.setValue(zone.delay)
            self._sync_traits()
        finally:
            self._quiet = False
        self.changed.emit()
