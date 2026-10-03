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

"""Starting and stopping the daemon on behalf of the GUI.

The GUI deliberately does not open the device itself. Only one process can
claim interface 1, and the daemon already knows how to take over from a
previous instance, so applying a preset is just running the command line and
letting that machinery do its job. It also means the GUI cannot get out of step
with what the CLI does, because it is the CLI doing it.
"""
import os
import signal
import subprocess
import time

from .. import daemon
from . import autostart
from .autostart import command


def apply(args):
    """Start streaming these arguments. Returns (ok, message).

    When the service is running, go through it rather than around it. Spawning
    a daemon directly would take the interface off the service's process;
    systemd would see that process die, restart it, and the restarted service
    would take the interface straight back -- so the change appeared to work
    for about two seconds and then silently reverted.
    """
    if autostart.service_active():
        autostart.write_env(args)
        ok, message = autostart.restart()
        return (True, " ".join(args)) if ok else (False, message)

    try:
        done = subprocess.run(command() + list(args),
                              capture_output=True, text=True, timeout=15)
    except (OSError, subprocess.SubprocessError) as e:
        return False, str(e)
    if done.returncode != 0:
        return False, (done.stderr or done.stdout).strip().split("\n")[0]
    return True, " ".join(args)


def stop():
    """Stop every instance, and wait for the device to actually be released.

    The service has to be stopped through systemd. Killing its process would
    only prompt a restart, so Stop would appear to do nothing.
    """
    stopped_service = False
    if autostart.service_active():
        autostart.stop()
        stopped_service = True

    pids = daemon.instances()
    for pid in pids:
        try:
            os.kill(pid, signal.SIGTERM)
        except OSError:
            pass
    deadline = time.monotonic() + 3.0
    while daemon.instances() and time.monotonic() < deadline:
        time.sleep(0.02)
    return len(pids) or (1 if stopped_service else 0)


def running():
    """The arguments the running instance was started with, or None.

    Read back from /proc rather than remembered, so it stays right even when
    something else -- a terminal, the autostart entry -- started the daemon.
    """
    for pid in daemon.instances():
        try:
            with open(f"/proc/{pid}/cmdline", "rb") as fh:
                args = [a.decode("utf-8", "replace")
                        for a in fh.read().split(b"\0") if a]
        except OSError:
            continue
        for k, arg in enumerate(args):
            if os.path.basename(arg) == daemon.PROGRAM or arg == daemon.PROGRAM:
                return args[k + 1:]
        if "-m" in args:
            return args[args.index("-m") + 2:]
    return None
