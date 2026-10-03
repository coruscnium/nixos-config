# quadcast2s

Control the RGB lighting on a **HyperX QuadCast 2 S** microphone from Linux.

> **Status: working.** The protocol, the LED layout, all ten effects and the
> CLI are implemented. See [docs/PLAN.md](docs/PLAN.md) for the architecture.

## Why this exists

The QuadCast 2 S has 108 individually addressable LEDs — a ring of 12 on top
and a body of 96 arranged as twelve columns of eight — and the vendor software
is Windows-only.

The protocol and the physical LED layout were worked out by probing the device
directly, and are written up in [docs/PROTOCOL.md](docs/PROTOCOL.md). The
layout is not what you would guess: the LED index runs *around* the microphone
rather than up it, and the strip climbs one column, crosses the ring, then
comes back down the next one.

## Requirements

- Linux, Python 3.9+
- `pyusb`, and libusb
- access to the device (see the udev rule below)

## Install

### Arch (and derivatives) — the packaged route

```bash
cd packaging
makepkg -si
```

pacman owns every file, so nothing is installed behind its back and nothing is
"broken". You get `quadcast2s` and `quadcast2s-gui` on `PATH`, a
**QuadCast 2 S Lighting** entry in your application menu, the udev rule in
`/usr/lib/udev/rules.d`, and the docs under `/usr/share/doc/quadcast2s`.

Replug the microphone once afterwards so the udev rule applies to it. The GUI
needs `pyside6`, which is an optional dependency: `sudo pacman -S pyside6`.

### Other distributions

Device access first:

```bash
sudo cp udev/70-quadcast2s.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules && sudo udevadm trigger
```

then replug the microphone. The rule uses `TAG+="uaccess"`, so on any systemd
distribution the logged-in user gets access with no group membership to
arrange.

**Without a virtualenv**, if `pyusb` (and `PySide6` for the GUI) come from your
package manager:

```bash
./scripts/install-local.sh
```

That puts two-line wrappers for `quadcast2s` and `quadcast2s-gui` in
`~/.local/bin`, running the source tree in place. Nothing is installed into
Python, so PEP 668 does not come into it, and edits take effect immediately.
Undo with `rm ~/.local/bin/quadcast2s ~/.local/bin/quadcast2s-gui`.

**In a virtualenv**, to pin the dependencies to this project:

```bash
python3 -m venv --system-site-packages .venv
.venv/bin/pip install -e '.[gui]'      # drop [gui] for the command line alone
```

**Without installing anything at all**, straight out of a checkout:

```bash
PYTHONPATH=src python3 -m quadcast2s solid ff0000
PYTHONPATH=src python3 -m quadcast2s.gui
```

## Usage

```
quadcast2s [OPTIONS] MODE [COLOURS...]
quadcast2s [OPTIONS] --ring MODE [COLOURS...] --body MODE [COLOURS...]
```

```bash
quadcast2s solid ff0000              # steady red
quadcast2s wave                      # rainbow travelling around the mic
quadcast2s fire ff4000 -s 40         # slower flames
quadcast2s --ring rain --body fire   # a different effect in each zone
quadcast2s rain random               # drops in colours it picks itself
quadcast2s cycle -b 30               # dimmed
```

| Mode | |
|---|---|
| `solid` | one steady colour |
| `blink` | on, off, stepping through the colour list — the only user of `-d` |
| `cycle` | the whole microphone sweeping through the colours |
| `wave` | `cycle`, travelling around the microphone |
| `vertical` | `cycle`, travelling up it |
| `lightning` | flashes in an unpredictable order |
| `pulse` | the same flash, in the order given |
| `spin` | a comet circling the twelve columns |
| `fire` | a heat simulation up the body |
| `rain` | drops falling through the ring into the body |

| Option | |
|---|---|
| `--ring` / `--body` | pick a zone; with neither, the mode fills the whole microphone |
| `-b`, `--brightness` | 0–100 |
| `-s`, `--speed` | 1–100, default 81. Does something in every animated mode |
| `-d`, `--delay` | off-time for `blink`, in frames |
| `--dump` | print the frames as JSON instead of lighting anything |
| `--wait` | wait for the microphone rather than failing when it is missing, for running under a service manager |

Options bind to the section they appear in, so `--ring cycle -s 30 --body fire`
runs the ring slowly and the body at the default speed.

## The GUI

```bash
quadcast2s-gui                             # installed
PYTHONPATH=src python3 -m quadcast2s.gui   # from a source checkout
```

The Arch package adds a **QuadCast 2 S Lighting** entry to the application
menu, so it does not have to be started from a terminal. Other distributions
can copy [desktop/quadcast2s-gui.desktop](desktop/) into
`~/.local/share/applications/`.

A small Qt front end: pick a mode and colours, watch a live preview, save the
result as a named preset, and optionally start a preset at login. It ships with
one preset per effect, so everything is reachable without reading the manual.

It does **not** open the device itself. Applying a preset runs the same command
line you could have typed, and the daemon's own takeover replaces whatever was
already streaming — so the GUI can never disagree with the CLI about what an
option does, and running one does not lock out the other.

The preview is the real thing rather than an illustration: it builds the same
frames the daemon would send and steps through them at the device's 32 fps, so
it works with the microphone unplugged.

Presets live in `~/.config/quadcast2s/presets.json`. The Settings tab has three
independent start triggers, all off by default — at login, when the microphone
is connected, and keep-running — backed by a systemd user service, a udev rule
and a drop-in respectively.

The lighting **recovers by itself** after the machine sleeps or the microphone
is unplugged, however it was started: the daemon spots a resume by comparing
`CLOCK_MONOTONIC` against `CLOCK_BOOTTIME`, and reopens the device on any USB
error.

Needs `PySide6`, which the command line does not.
[docs/GUI.md](docs/GUI.md) covers how it is put together and why.

The microphone does not hold a frame: stop sending and the firmware takes the
LEDs back and resumes its own rainbow. The program therefore runs
continuously. Running it again replaces the instance already going, so there is
no need to kill anything to change mode.

To stop it, use `pkill -x quadcast2s`. Avoid `pkill -f quadcast2s` — the `-f`
flag matches whole command lines and will also kill any shell sitting in a
directory of that name.

## Device access

The microphone presents two USB devices. Lighting lives on the **controller**,
`03f0:02b5` — not on `03f0:0d84`, which is the audio device. The rule is
[udev/70-quadcast2s.rules](udev/70-quadcast2s.rules), and the package installs
it for you.

It grants access with `TAG+="uaccess"`, which asks logind for an ACL on the
device node for whoever is logged in at the seat. That needs no group and no
re-login. Earlier versions of this rule said `GROUP="plugdev"`, a Debian
convention — on Arch that group does not exist, so the rule silently did
nothing.

## Tools

[tools/](tools/) has two small programs used to explore the hardware —
`probe.py` asks the device what it supports, `paint.py` lights LEDs by index so
a guess about the layout can be checked by eye.

## Documentation

| | |
|---|---|
| [docs/PROTOCOL.md](docs/PROTOCOL.md) | USB protocol, command set, LED geometry, timing |
| [docs/EFFECTS.md](docs/EFFECTS.md) | effect specifications and the display-physics lessons behind them |
| [docs/TESTING.md](docs/TESTING.md) | how to verify effects, mostly without looking at the mic |
| [docs/PLAN.md](docs/PLAN.md) | architecture and build order |
| [docs/GUI.md](docs/GUI.md) | the front end: what it is built on, and the traps in it |

`tests/` runs with the microphone unplugged: every effect is a pure function
from options to frames, so density, loop seams and speed response are all
checked numerically. `python3 -m unittest discover -s tests`.

## Licence

**AGPL-3.0-only.** See [LICENSE](LICENSE).

This is an independent implementation, written from protocol facts obtained by
probing the hardware. It is **not** derived from
[Ors1mer/QuadcastRGB](https://gitlab.com/Ors1mer/QuadcastRGB), which is a
separate GPL-2.0-only project supporting several HyperX microphones. If you
want the QuadCast S, QuadCast 2 or DuoCast, use that instead — this project
deliberately supports the QuadCast 2 S only.
