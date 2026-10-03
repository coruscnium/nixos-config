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

"""A live preview of the microphone.

Because every effect is a pure function from options to frames, the preview can
run the real thing: it builds the same frames the daemon would send and steps
through them at the device's own 32 fps. It is not a mock, so it cannot drift
away from what the hardware does, and it works with the microphone unplugged.

The view is the unrolled grid rather than a picture of a microphone -- twelve
columns around, eight rows up, and the ring as a separate strip on top. That is
the shape the LEDs actually make once you know the index runs around the mic
rather than up it, and it is the shape the effects are written against.

The soft halo behind each cell is not decoration: the real diffuser blooms a
single lit LED into a blob, and a preview of hard-edged squares makes effects
look tidier than they are.
"""
from PySide6.QtCore import QRectF, QTimer, Qt
from PySide6.QtGui import QColor, QPainter
from PySide6.QtWidgets import QWidget

from .. import daemon
from ..geometry import BODY_ROWS, COLUMNS, GRID_ROWS, RING_ROW, index

FPS = 32
GAP = 0.18                              # between cells, in cell widths
RING_GAP = 0.55                         # extra space under the ring


class LedPreview(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setMinimumSize(260, 300)
        self._layers = []
        self._frame = [(0, 0, 0)] * 108
        self._tick = 0
        self._timer = QTimer(self)
        self._timer.timeout.connect(self._advance)
        self._timer.start(1000 // FPS)

    def set_layers(self, layers):
        """`layers` are daemon.Layer objects, exactly as the daemon composites."""
        self._layers = layers
        self._tick = 0
        self._recompose()

    def _advance(self):
        if self._layers:
            self._tick += 1
            self._recompose()

    def _recompose(self):
        self._frame = daemon.compose(self._layers, self._tick)
        self.update()

    # ------------------------------------------------------------- painting

    def _metrics(self):
        """Cell size and origin, keeping the grid square and centred."""
        rows = GRID_ROWS + RING_GAP
        cell = min(self.width() / (COLUMNS + GAP), self.height() / (rows + GAP))
        w = cell * (COLUMNS + GAP)
        h = cell * (rows + GAP)
        return cell, (self.width() - w) / 2, (self.height() - h) / 2

    def _cell_rect(self, cell, x0, y0, col, row):
        # row 0 is the bottom of the body; the ring sits above the top row.
        if row == RING_ROW:
            top = 0.0
        else:
            top = (BODY_ROWS - 1 - row) + 1 + RING_GAP
        return QRectF(x0 + cell * (col + GAP / 2), y0 + cell * (top + GAP / 2),
                      cell * (1 - GAP), cell * (1 - GAP))

    @staticmethod
    def _blob(painter, row, rect, cell):
        """Ring LEDs are drawn round, body LEDs square: the ring really is a
        ring of twelve, and the shape says which zone you are looking at
        without needing a label."""
        if row == RING_ROW:
            painter.drawEllipse(rect)
        else:
            painter.drawRoundedRect(rect, cell * 0.22, cell * 0.22)

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing)
        painter.fillRect(self.rect(), QColor(18, 18, 20))
        cell, x0, y0 = self._metrics()
        painter.setPen(Qt.NoPen)

        for row in range(GRID_ROWS):
            for col in range(COLUMNS):
                r, g, b = self._frame[index(col, row)]
                rect = self._cell_rect(cell, x0, y0, col, row)
                lit = r or g or b
                if lit:
                    # the diffuser's own bloom, so the preview is not crisper
                    # than the hardware can ever be
                    painter.setBrush(QColor(r, g, b, 60))
                    self._blob(painter, row,
                               rect.adjusted(-cell * 0.32, -cell * 0.32,
                                             cell * 0.32, cell * 0.32), cell)
                painter.setBrush(QColor(r, g, b) if lit else QColor(38, 38, 42))
                self._blob(painter, row, rect, cell)
        painter.end()
