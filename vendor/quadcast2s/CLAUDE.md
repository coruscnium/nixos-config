# quadcast2s

Controls the RGB lighting on a **HyperX QuadCast 2 S** microphone from Linux.
Python, AGPL-3.0-only, maintained by Coruscnium.

If you are picking this up with no memory of earlier sessions, read this file
and then `docs/PROTOCOL.md`. Between them they contain everything that was
learned the hard way; almost none of it is guessable from the code.

---

## The licensing boundary — read this first

This project is **AGPL-3.0-only**. It exists because of a licensing
constraint, and that constraint governs how you may work on it.

There is a sibling directory, `../quadcastrgb`. It is a fork of
[Ors1mer/QuadcastRGB](https://gitlab.com/Ors1mer/QuadcastRGB), written in C
and licensed **GPL-2.0-only** — with no "or later" clause, deliberately. GPLv2
code cannot be relicensed to AGPLv3 by anyone except its copyright holder, and
GPLv2 §6 forbids adding AGPL's §13 network clause on top. So this project is a
separate, independent implementation rather than a relicensed copy.

**Rules that follow from that:**

- **Do not read, copy, port, or translate any code from `../quadcastrgb`.**
  Not the C, not its structure, not its function decomposition. If you need to
  know something about the hardware, it is in `docs/PROTOCOL.md`, which was
  written from probing the device directly.
- **Do not add support for other microphones** (QuadCast S, QuadCast 2,
  DuoCast). Their protocol is only known here from having read the GPLv2
  source, so reimplementing it would undermine the whole point. This project is
  QuadCast 2 S only, on purpose. If someone wants the others, they must probe
  that hardware themselves and document it independently.
- Facts are fine. USB protocol details, packet layouts, LED positions and
  timings are facts about a piece of hardware, not copyrightable expression.
  Everything in `docs/PROTOCOL.md` was obtained by probing a physical unit.
- Keep the AGPL headers on source files.

If you are ever unsure whether something crosses the line, ask the user rather
than guessing.

---

## The hardware in one page

Full detail in `docs/PROTOCOL.md`. The short version, because these are the
things that trip people up:

The mic presents **two** USB devices. RGB lives on the **controller**,
`03f0:02b5` — not on `03f0:0d84`, which is the audio device.

Lighting is driven over **interrupt transfers on interface 1**, endpoints
`0x06` OUT and `0x85` IN. Claim interface 1 and nothing else.

A frame is 108 LEDs, sent as a `44 01 06` header followed by six
`44 02 <index> 00` packets of twenty RGB triples each.

**Two rules that are easy to get wrong and produce baffling symptoms:**

1. **The device never latches a frame.** Stop streaming and the firmware takes
   the LEDs back and resumes its own rainbow. This is why the program must run
   as a daemon. If the mic "reverts to rainbow", nothing is broken — the stream
   stopped.
2. **The reply to every packet must be read.** Writing without reading is
   accepted by the USB stack and reaches ~143 frames/sec, but the device
   *silently ignores every frame* and the lights never change. Reading the
   reply is what makes it work, and that handshake paces the stream at
   **~32 frames/sec**. If you ever "optimise" by skipping the read, everything
   will look fine in the logs and nothing will light up.

The LED index runs **around** the mic, not up it. Six angular blocks of
eighteen; inside a block the strip climbs one column, crosses the ring, then
comes back down the neighbouring column:

```
block b = indices 18b .. 18b+17
  18b +  0 .. 18b +  7   body column 2b,   ascending  (0 = bottom)
  18b +  8 .. 18b +  9   TOP RING segment b
  18b + 10 .. 18b + 17   body column 2b+1, descending (17 = bottom)
```

So the **ring is 12 LEDs** (`i % 18 in (8, 9)`) and the **body is 96**, as
twelve columns of eight. Effects are easiest to write against the unrolled
grid: 12 columns wide, 9 rows tall, where row 8 is the ring sitting on top.

**Report `0x10` resets the controller.** It re-enumerates and recovers fine,
but do not send it. The `0xf0`, `0xf1`, `0xfa`–`0xfd` block is numbered like a
firmware-update interface and has never been probed. Leave it alone.

---

## Commands

The package lives under `src/`, so either install it editable once:

```bash
pip install -e .            # then: quadcast2s solid ff0000
```

**On Arch the packaged route is `cd packaging && makepkg -si`** — pacman owns
every file, and it installs the udev rule, the desktop entry and the icon. Two
things about that PKGBUILD are deliberate:

- **It lives in `packaging/`, not the repository root.** makepkg sets
  `$srcdir="$startdir/src"` and deletes it on `--clean`. This project's own
  source tree is `src/`, so a root PKGBUILD makes those the same directory and
  one `makepkg -C` would delete the whole project.
- **The udev rule uses `TAG+="uaccess"`, not `GROUP="plugdev"`.** There is no
  `plugdev` group on Arch, so the old rule was inert. Access on this machine
  was in fact coming from OpenRGB's rule, which also matches `03f0:02b5` — so
  the device appeared to work while our own rule did nothing.

PEP 668 blocks pip, so a from-source install must be a virtualenv:
`python3 -m venv --system-site-packages .venv` then
`.venv/bin/pip install -e '.[gui]'`. The flag matters — it picks up the
distribution's `pyusb` and `PySide6` rather than downloading copies.

`scripts/install-local.sh` is the no-virtualenv route: wrappers in
`~/.local/bin` that run the source tree in place with `PYTHONPATH` set. Nothing
enters Python's site-packages, so PEP 668 never applies. Takeover still works
through those wrappers — the cmdline is `python3 -m quadcast2s ...`, which
`_looks_like_us` matches on the `-m` adjacency, and the daemon sets its own
`comm`, so `pkill -x` finds it too.

Or set `PYTHONPATH=src` for ad-hoc runs. The tools do the latter:

```bash
cd tools
PYTHONPATH=../src python3 probe.py info      # firmware banner
PYTHONPATH=../src python3 probe.py reports   # which HID report IDs answer
PYTHONPATH=../src python3 paint.py '0xffffff if i%18 in (8,9) else 0'
```

Run the test suite with `python3 -m unittest discover -s tests`; it needs no
hardware.

The GUI is `quadcast2s-gui` (`src/quadcast2s/gui/`), PySide6, an optional
extra, documented in `docs/GUI.md`. Three rules it is built on, worth keeping:

- **It never opens the device.** Applying a preset runs the CLI and lets
  takeover do the rest. The GUI is therefore not a second opinion about what
  any option means.
- **`presets.py`, `autostart.py` and `runner.py` contain no Qt**, so they are
  unit-tested without a display, the same way effects are tested without
  hardware. Only `app.py`, `controls.py` and `preview.py` import PySide6.
- **The preview builds real frames** through `daemon.compose`, so it cannot
  drift from the hardware.

Recovery after suspend is in the **daemon**, not in a systemd unit: the user
manager has no `sleep.target`, and the daemon is as often started from a
terminal anyway. It compares `CLOCK_MONOTONIC` with `CLOCK_BOOTTIME` to spot a
resume and reopens the device — necessary because this microphone sets
`power/persist`, so the handle can still look valid while the firmware has
taken the LEDs back. See `docs/GUI.md`.

To check the GUI's appearance without a display, render it offscreen rather
than screenshotting the desktop:

```python
os.environ["QT_QPA_PLATFORM"] = "offscreen"     # and XDG_CONFIG_HOME to a tmpdir
window.grab().save("shot.png")
```

Always point `XDG_CONFIG_HOME` at a temporary directory when testing, or the
tests will overwrite the user's real presets.

Only one process can hold the interface. Stop whatever is running first.

**Killing it: use `pkill -x quadcast2s`, never `pkill -f quadcast2s`.** The
`-f` flag matches whole command lines, and this project's own path contains the
string, so `-f` will kill your own shell — including the agent's shell, which
shows up as a tool call dying with exit code 143/144 and no output.

---

## Working with the user

- **Never capture from the webcam.** There is a camera on this machine. Do not
  read `/dev/video*`, do not shell out to ffmpeg for it. This was asked for
  explicitly. When visual confirmation is needed, drive the hardware into a
  self-describing state and *ask* what they see.
- Visual feedback is the bottleneck. Every question costs the user real
  attention, so make each one count — see `docs/TESTING.md` for patterns that
  answer several questions at once, and for the traps that produced conflicting
  answers before.
- Hold a pattern in a **loop** while asking. A one-shot frame is gone before
  they look, and the firmware rainbow returns, which reads as "it's broken".
- The user gives precise, useful feedback on how effects *look* ("reads as
  random flicker", "like a slinky", "a black column circling"). Take it
  literally — each of those turned out to be a real bug with a specific cause.

---

## Verification without eyes

You cannot see the LEDs, but you do not have to guess. Generate frames and
inspect them numerically before ever asking the user. `docs/TESTING.md` has the
methodology; the short form is that every effect should be checked for:

- lit-LED counts per frame (density)
- brightness distribution bottom-to-top (for anything with a vertical gradient)
- distinct colours around the circumference (for anything angular)
- **loop seam**: the delta from the last frame to the first must be no worse
  than the typical frame-to-frame delta, or the animation visibly jumps
- **monotonic response to `--speed`**: measure mean per-LED change per frame at
  several speeds and confirm it actually increases

Effects that use randomness (`fire`, `rain`, and `blink` with no colours)
differ between runs.
Comparing output hashes across runs will produce **false positives** — control
for it by running the same arguments twice first.

---

## Status

Implemented and working: all ten effects, both zones, the CLI and the
daemon. `docs/PLAN.md` has the architecture. `python3 -m unittest discover -s
tests` runs the whole suite with the microphone unplugged, because every effect
is a pure function from options to frames.

Two things about process handling that are easy to get wrong and were:

- **Take over before forking, never from the child.** The launching process is
  itself `quadcast2s`, so a takeover scan run in the child matches its own
  waiting parent and kills it — every launch then exits 143 instead of 0.
- **Installed as a console script, the process is really `python3
  /usr/bin/quadcast2s`.** Our name is in `argv[1]`, not `argv[0]`, and `comm`
  reads `python3`. Missing that made an installed instance invisible to the
  takeover scan, so a second run claimed the device *alongside* the first. The
  daemon now sets its own `comm` via `prctl`, which is what makes the
  documented `pkill -x quadcast2s` work at all.

`docs/EFFECTS.md` specifies all ten effects with their tuned constants and,
more importantly, *why* each constant has the value it does. Those numbers were
arrived at by iterating against the real hardware with the user watching. Do
not casually retune them.
