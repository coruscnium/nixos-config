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


"""The version number is written in four places; they must agree.

pyproject.toml, the package's __version__, the PKGBUILD's pkgver and the
AppStream release list are all separate files, and nothing but this test stops
one of them being forgotten during a bump. Skipped when run against an
installed copy, where the packaging files are not present.
"""
import pathlib
import re
import unittest

import quadcast2s

ROOT = pathlib.Path(__file__).resolve().parent.parent
METAINFO = ROOT / "desktop" / "xyz.coruscnium.quadcast2s.metainfo.xml"


def find(path, pattern):
    try:
        text = path.read_text()
    except OSError:
        return None
    match = re.search(pattern, text, re.MULTILINE)
    return match.group(1) if match else None


@unittest.skipUnless((ROOT / "pyproject.toml").exists(),
                     "not running from a source checkout")
class TestVersions(unittest.TestCase):
    def test_pyproject_matches_the_package(self):
        self.assertEqual(
            find(ROOT / "pyproject.toml", r'^version = "([^"]+)"'),
            quadcast2s.__version__)

    def test_pkgbuild_matches_the_package(self):
        self.assertEqual(
            find(ROOT / "packaging" / "PKGBUILD", r'^pkgver=(\S+)'),
            quadcast2s.__version__)

    def test_appstream_names_this_release(self):
        newest = find(METAINFO, r'<release version="([^"]+)"')
        self.assertEqual(newest, quadcast2s.__version__,
                         "the newest AppStream release entry is not this version")

    def test_appstream_releases_are_newest_first(self):
        found = re.findall(r'<release version="([^"]+)"', METAINFO.read_text())
        parsed = [tuple(int(n) for n in v.split(".")) for v in found]
        self.assertEqual(parsed, sorted(parsed, reverse=True), found)

    def test_version_is_a_plain_release_number(self):
        # pacman's vercmp ranks 0.1.0.dev0 above 0.1.0, so a dev suffix in an
        # installable package makes the next real release look older.
        self.assertRegex(quadcast2s.__version__, r"^\d+\.\d+\.\d+$")


if __name__ == "__main__":
    unittest.main()
