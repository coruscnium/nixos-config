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


"""When the lighting should start, and how it comes back.

Three independent switches, each a real mechanism rather than a setting this
program has to remember and act on itself:

  login    systemctl --user enable quadcast2s.service
  connect  a flag file the udev-started quadcast2s-hotplug.service tests for
  keep     a drop-in setting Restart=always on the service

The flag file is why "start when the microphone is connected" needs no root:
the udev rule always asks for quadcast2s-hotplug.service, and that unit has a
ConditionPathExists on the flag, so systemd skips it unless the user opted in.
Editing udev rules would need privileges; touching a file in one's own config
directory does not.

Nothing here imports Qt, so it is all testable without a display.

Suspend is deliberately absent. The daemon detects a resume itself, by noticing
time that CLOCK_BOOTTIME accounts for and CLOCK_MONOTONIC does not, and reopens
the device. That works however it was started, including from a terminal, which
matters because the systemd *user* manager has no sleep.target to hook.
"""
import os
import shutil
import subprocess
import sys

NAME = "quadcast2s"
SERVICE = "quadcast2s.service"
LEGACY_DESKTOP = "quadcast2s.desktop"       # the XDG autostart file we used to write


def config_dir():
    base = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    return os.path.join(base, NAME)


def env_path():
    """Where the service reads its arguments from."""
    return os.path.join(config_dir(), "service.env")


def connect_flag():
    return os.path.join(config_dir(), "start-on-connect")


def dropin_path():
    base = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    return os.path.join(base, "systemd", "user", SERVICE + ".d", "restart.conf")


def legacy_desktop_path():
    base = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    return os.path.join(base, "autostart", LEGACY_DESKTOP)


def command():
    """The absolute command that starts the daemon, as a list.

    The interpreter's own bin directory comes first. Run from a virtualenv the
    console script sits next to sys.executable but that directory is usually
    not on PATH, so asking PATH alone would miss the very binary running us.
    """
    sibling = os.path.join(os.path.dirname(sys.executable), NAME)
    if os.path.isfile(sibling) and os.access(sibling, os.X_OK):
        return [sibling]
    found = shutil.which(NAME)
    if found:
        return [found]
    src = os.path.dirname(os.path.dirname(os.path.dirname(
        os.path.abspath(__file__))))
    return ["/usr/bin/env", f"PYTHONPATH={src}", sys.executable, "-m", NAME]


# ------------------------------------------------------------------ systemd

def systemctl(*args, check=False):
    """Run `systemctl --user ...`. Returns (ok, output)."""
    try:
        done = subprocess.run(["systemctl", "--user", *args],
                              capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.SubprocessError) as e:
        return False, str(e)
    return done.returncode == 0, (done.stdout + done.stderr).strip()


def available():
    """Is there a user service manager to talk to at all?"""
    if not shutil.which("systemctl"):
        return False
    ok, _ = systemctl("is-system-running")
    return ok or os.path.exists(
        os.environ.get("XDG_RUNTIME_DIR", "") + "/systemd/private")


def write_env(args):
    """Record the arguments the service should stream."""
    os.makedirs(config_dir(), exist_ok=True)
    path = env_path()
    tmp = path + ".tmp"
    with open(tmp, "w") as fh:
        fh.write("# written by quadcast2s-gui\n")
        fh.write("QUADCAST2S_ARGS=" + " ".join(args) + "\n")
    os.replace(tmp, path)


def read_env():
    try:
        with open(env_path()) as fh:
            for line in fh:
                if line.startswith("QUADCAST2S_ARGS="):
                    return line.split("=", 1)[1].strip().split()
    except OSError:
        pass
    return []


# ------------------------------------------------------------- the switches

def login_enabled():
    ok, _ = systemctl("is-enabled", SERVICE)
    return ok


def set_login(on):
    """Enable the service, and start it now.

    `enable` alone only takes effect at the next login, so ticking the box
    appears to do nothing at all -- which reads as broken rather than as
    deferred. `--now` makes the switch mean what it looks like it means.

    Unticking only disables: stopping the lighting because an autostart
    preference changed would be a surprise. Use Stop for that.
    """
    if on:
        # The old XDG autostart entry would start a second copy alongside the
        # service, so it goes when the service takes over.
        _unlink(legacy_desktop_path())
        return systemctl("enable", "--now", SERVICE)
    return systemctl("disable", SERVICE)


def connect_enabled():
    return os.path.exists(connect_flag())


def set_connect(on):
    if on:
        os.makedirs(config_dir(), exist_ok=True)
        open(connect_flag(), "w").close()
    else:
        _unlink(connect_flag())
    return True, ""


def keep_running_enabled():
    return os.path.exists(dropin_path())


def set_keep_running(on):
    path = dropin_path()
    if on:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as fh:
            fh.write("# written by quadcast2s-gui\n"
                     "[Service]\n"
                     "Restart=always\n")
    else:
        _unlink(path)
        _prune(os.path.dirname(path))
    return systemctl("daemon-reload")


def _unlink(path):
    try:
        os.unlink(path)
    except OSError:
        pass


def _prune(path):
    try:
        os.rmdir(path)
    except OSError:
        pass


def service_active():
    ok, _ = systemctl("is-active", SERVICE)
    return ok


def restart():
    return systemctl("restart", SERVICE)


def stop():
    return systemctl("stop", SERVICE)
