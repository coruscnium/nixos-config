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

"""Single-instance handling, signals, and the streaming loop.

The microphone never latches a frame -- stop sending and the firmware takes the
LEDs back and resumes its own rainbow -- so the program has to keep streaming
for as long as the lighting should stay put. It therefore backgrounds itself
and a new run takes the device over from the old one.

Two things here are subtler than they look, both recorded in docs/PLAN.md:

  * A pid file alone is not enough. A replaced instance removes the file on its
    way out, so any run whose pid never made it back into the file becomes
    invisible and is never handed over, leaving two instances fighting over the
    device. Ask the kernel instead: scan /proc, signal, and *wait* for them to
    go. The pid file is kept only as a fallback.
  * Signal handling must not depend on the main loop noticing a flag. libusb's
    synchronous transfers can block in futex_wait when the device is contended,
    so the loop may never get to look. The handler exits the process itself.
"""
import errno
import os
import signal
import sys
import time

import usb.core

from .geometry import BLACK, LED_COUNT
from .usb import QC2S

PROGRAM = "quadcast2s"
FPS = 32                                # the handshake sets this; see PROTOCOL
FRAME_TIME = 1.0 / FPS
TAKEOVER_TIMEOUT = 3.0

RETRY_MIN = 0.5                         # seconds between attempts to reopen
RETRY_MAX = 5.0
SUSPEND_GAP = 2.0                       # seconds of unaccounted time = a sleep


def slept(before, after):
    """Did the machine suspend between these two clock readings?

    CLOCK_MONOTONIC stops while the machine is suspended and CLOCK_BOOTTIME
    does not, so time that BOOTTIME accounts for and MONOTONIC does not is time
    spent asleep. That makes a resume detectable with no systemd integration at
    all, which matters because the *user* manager has no sleep.target to hook,
    and because the daemon is just as often started from a terminal.

    Worth detecting even though the device usually survives: this microphone
    sets power/persist, so after a resume the handle can still look valid while
    the firmware has quietly taken the LEDs back.
    """
    return (after[1] - before[1]) - (after[0] - before[0]) > SUSPEND_GAP


def clocks():
    return time.monotonic(), time.clock_gettime(time.CLOCK_BOOTTIME)


# --------------------------------------------------------------- composition

class Layer:
    """One zone's loop of frames, and the LED indices it owns."""

    def __init__(self, indices, frames):
        self.indices = indices
        self.frames = frames

    def paint(self, out, t):
        frame = self.frames[t % len(self.frames)]
        for i in self.indices:
            out[i] = frame[i]


def compose(layers, t, out=None):
    """Flatten the layers into one 108-LED frame for tick `t`."""
    if out is None:
        out = [BLACK] * LED_COUNT
    for layer in layers:
        layer.paint(out, t)
    return out


def sequence(layers, count):
    """The first `count` composed frames. Used by --dump; touches no device."""
    return [compose(layers, t) for t in range(count)]


# ---------------------------------------------------------------- instances

def _pidfile():
    runtime = os.environ.get("XDG_RUNTIME_DIR")
    if runtime and os.path.isdir(runtime):
        return os.path.join(runtime, f"{PROGRAM}.pid")
    return os.path.join("/tmp", f"{PROGRAM}-{os.getuid()}.pid")


def _is_python(arg):
    return os.path.basename(arg).startswith("python")


def _looks_like_us(args):
    """Is this /proc cmdline another copy of this program?

    Deliberately structural rather than a substring match. This project's own
    directory is called quadcast2s, so anything matching whole command lines
    as text -- pkill -f, notably -- also kills the shell you are sitting in.

    All three ways of starting it have to be recognised. Installed as a console
    script the shebang means argv is `python3 /usr/bin/quadcast2s ...`, with the
    interpreter in argv[0] and our name only in argv[1]; missing that case left
    an installed instance invisible to the takeover scan, so a second run
    claimed the device alongside the first instead of replacing it.

    argv[1] counts only when argv[0] is a Python interpreter. Without that
    guard `vim quadcast2s` or `ls quadcast2s` would match and be killed.
    """
    if not args:
        return False
    if os.path.basename(args[0]) == PROGRAM:
        return True
    if _is_python(args[0]):
        if len(args) > 1 and os.path.basename(args[1]) == PROGRAM:
            return True
        for a, b in zip(args, args[1:]):
            if a == "-m" and b == PROGRAM:
                return True
    return any(a.endswith(os.path.join(PROGRAM, "__main__.py")) for a in args)


def _name_process():
    """Set the kernel's comm, so `pgrep -x quadcast2s` actually finds us.

    Installed as a console script the process is really the Python interpreter,
    so comm reads `python3` and the `pkill -x quadcast2s` that the README
    documents would never match anything. comm is capped at fifteen bytes,
    which the name fits inside. Best effort: it is only a convenience.
    """
    try:
        import ctypes
        ctypes.CDLL(None).prctl(15, PROGRAM.encode() + b"\0", 0, 0, 0)
    except Exception:
        pass


def _ancestors():
    """Our own parent chain, which must never be signalled.

    The process that launches the daemon is itself `python3 -m quadcast2s`, so
    a takeover scan run from a child would match its own waiting parent and
    kill it -- which shows up as the launch exiting 143 instead of 0.
    """
    chain, pid = set(), os.getpid()
    while pid > 1:
        try:
            with open(f"/proc/{pid}/status") as fh:
                line = next(l for l in fh if l.startswith("PPid:"))
        except (OSError, StopIteration):
            break
        pid = int(line.split()[1])
        if pid in chain:
            break
        chain.add(pid)
    return chain


def _siblings():
    """Pids of other instances belonging to this user."""
    me, uid, found = os.getpid(), os.getuid(), []
    kin = _ancestors()
    for entry in os.listdir("/proc"):
        if not entry.isdigit():
            continue
        pid = int(entry)
        if pid == me or pid in kin:
            continue
        try:
            if os.stat(f"/proc/{pid}").st_uid != uid:
                continue
            with open(f"/proc/{pid}/cmdline", "rb") as fh:
                args = [a.decode("utf-8", "replace")
                        for a in fh.read().split(b"\0") if a]
        except OSError:
            continue                    # it exited from under us; fine
        if _looks_like_us(args):
            found.append(pid)
    return found


def instances():
    """Pids of the instances currently streaming. Used by the GUI."""
    return _siblings()


def _stale_pid():
    """The pid file, kept as a portable fallback to the /proc scan."""
    try:
        with open(_pidfile()) as fh:
            pid = int(fh.read().strip())
    except (OSError, ValueError):
        return []
    return [pid] if pid != os.getpid() and _alive(pid) else []


def _alive(pid):
    try:
        os.kill(pid, 0)
    except OSError as e:
        return e.errno == errno.EPERM
    return True


def takeover(timeout=TAKEOVER_TIMEOUT):
    """Stop every other instance and wait for it to actually be gone."""
    victims = set(_siblings()) | set(_stale_pid())
    for pid in victims:
        try:
            os.kill(pid, signal.SIGTERM)
        except OSError:
            pass
    deadline = time.monotonic() + timeout
    while victims and time.monotonic() < deadline:
        victims = {pid for pid in victims if _alive(pid)}
        if victims:
            time.sleep(0.02)
    for pid in victims:                 # it ignored SIGTERM; insist
        try:
            os.kill(pid, signal.SIGKILL)
        except OSError:
            pass
    deadline = time.monotonic() + 1.0
    while any(_alive(pid) for pid in victims) and time.monotonic() < deadline:
        time.sleep(0.02)


def _write_pidfile():
    try:
        with open(_pidfile(), "w") as fh:
            fh.write(str(os.getpid()))
    except OSError:
        pass


def _clear_pidfile():
    """Remove the pid file only if it is still ours."""
    try:
        with open(_pidfile()) as fh:
            if int(fh.read().strip()) != os.getpid():
                return
        os.unlink(_pidfile())
    except (OSError, ValueError):
        pass


# ------------------------------------------------------------------ signals

def _install_signals(get_device, state):
    def stop(signum, frame):
        state["stop"] = True
        _exit_now(get_device())

    for sig in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
        signal.signal(sig, stop)


def _exit_now(device, code=0):
    """Release the device and go, without waiting for the main loop.

    A blocked libusb transfer will not return just because a flag was set, so
    the handler cannot hand control back. Releasing can itself block, hence the
    alarm: two seconds, then leave regardless. The kernel tidies up the rest.
    """
    signal.signal(signal.SIGALRM, lambda *_: os._exit(code))
    signal.alarm(2)
    _clear_pidfile()
    try:
        if device is not None:
            device.close()
    except Exception:
        pass
    os._exit(code)


# ---------------------------------------------------------------- daemonising

def daemonise():
    """Double-fork into the background, reporting startup failure first.

    The parent blocks until the child has taken the device over, so a failure
    to claim it is still reported on the terminal and still sets the exit
    status. Success is silent, which is the contract the regression run in
    docs/TESTING.md asserts.
    """
    read_fd, write_fd = os.pipe()
    pid = os.fork()
    if pid:                             # original process
        os.close(write_fd)
        with os.fdopen(read_fd) as fh:
            message = fh.read()
        os.waitpid(pid, 0)
        if message:
            sys.stderr.write(message)
            os._exit(1)
        os._exit(0)

    os.close(read_fd)
    os.setsid()
    if os.fork():                       # intermediate: never a session leader
        os._exit(0)
    return write_fd


def _detach(write_fd, message=None):
    """Finish the handshake and let go of the terminal."""
    if message:
        os.write(write_fd, message.encode())
    os.close(write_fd)
    null = os.open(os.devnull, os.O_RDWR)
    for fd in (0, 1, 2):
        os.dup2(null, fd)
    if null > 2:
        os.close(null)


# --------------------------------------------------------------------- loop

def _reopen(state, wait):
    """Get the device back, retrying with a backoff. None if giving up."""
    delay = RETRY_MIN
    while True:
        try:
            return QC2S(quiet=True)
        except SystemExit:
            # Not plugged in, or somebody else is holding it. Only a run that
            # asked to wait keeps trying; an interactive one has already
            # reported the failure and should not hang.
            if not wait:
                return None
        if state["stop"]:
            return None
        time.sleep(delay)
        delay = min(delay * 2, RETRY_MAX)


def run(layers, foreground=False, wait=False):
    """Take the device over and stream `layers` until told to stop.

    Once streaming, losing the device is never fatal: it is reopened and the
    stream resumes. Unplugging the microphone, suspending the machine and
    having another process seize the interface all look the same from here, and
    all of them should end with the lighting coming back by itself rather than
    with a dead daemon.
    """
    takeover()                          # before forking, never from the child
    write_fd = None if foreground else daemonise()
    try:
        device = QC2S(quiet=True)
    except SystemExit as e:
        if not wait:
            if write_fd is None:
                raise
            _detach(write_fd, f"{e}\n" if e.code else None)
            os._exit(1 if e.code else 0)
        device = None                   # --wait: come up before the hardware

    if write_fd is not None:
        _detach(write_fd)
    _name_process()
    _write_pidfile()
    state = {"stop": False}
    _install_signals(lambda: device, state)

    out = [BLACK] * LED_COUNT
    tick = 0
    mark = clocks()
    try:
        while not state["stop"]:
            if device is None:
                device = _reopen(state, wait)
                if device is None:
                    break
                mark = clocks()
            deadline = time.monotonic() + FRAME_TIME
            compose(layers, tick, out)
            try:
                device.send_frame(out)
            except usb.core.USBError:
                # Gone, reset, or taken. Drop the handle and get it back.
                try:
                    device.close()
                except Exception:
                    pass
                device = None
                continue
            tick += 1

            now = clocks()
            if slept(mark, now):
                # The handle may still be valid but the firmware has had the
                # LEDs back. Reopen rather than trust it.
                try:
                    device.close()
                except Exception:
                    pass
                device = None
            mark = now

            rest = deadline - time.monotonic()
            if rest > 0:                # the handshake normally beats us to it
                time.sleep(rest)
    except KeyboardInterrupt:
        pass
    finally:
        _clear_pidfile()
        if device is not None:
            device.close()
