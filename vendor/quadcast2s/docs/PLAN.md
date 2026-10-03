# Implementation plan

**Built.** This was the intended shape and the order it was built in; it is kept
as the architectural record. The one departure from the layout below is
`effects/base.py`, which holds `Scheme`, the speed mappings, `cycles()` and the
per-zone `Rng` — they cannot live in `effects/__init__.py` without the effect
modules and the registry importing each other in a circle.

Read `CLAUDE.md` (licensing boundary), `PROTOCOL.md` (the hardware) and
`EFFECTS.md` (what to build) first.

---

## Constraints that drive the design

- **32 fps ceiling**, set by the required per-packet handshake. Not negotiable.
- **Must stream continuously** — the device never latches a frame.
- **Frames are precomputed** into a loop of 1200 frames and replayed. Effects
  are pure functions of frame index, which makes them testable without hardware.
- **Python.** `pyusb` is already proven against this device and comfortably
  exceeds 32 fps. Keep runtime dependencies to `pyusb` alone.

---

## Module layout

```
src/quadcast2s/
    __init__.py
    __main__.py     entry point: python3 -m quadcast2s
    usb.py          device I/O                      [DONE - carried over]
    geometry.py     LED index <-> grid mapping
    colour.py       scale, lerp, add, distance, gamma, palettes
    effects/
        __init__.py registry: name -> builder
        base.py     Scheme, speed mapping, cycles(), Rng
        simple.py   solid, blink, cycle, wave, vertical, lightning, pulse
        spin.py
        fire.py
        rain.py
    cli.py          argument parsing
    daemon.py       single-instance handling, signals, streaming loop
    gui/            optional PySide6 front end
        presets.py  named setups, saved as JSON     (no Qt)
        autostart.py XDG desktop entry              (no Qt)
        runner.py   starting and stopping the daemon (no Qt)
        preview.py  the live LED view
        controls.py one zone's controls
        app.py      the main window
tools/
    probe.py        protocol exploration           [DONE - carried over]
    paint.py        light LEDs by expression       [DONE - carried over]
```

### The core contract

Every effect is a function from a colour scheme to a list of frames, where a
frame is 108 `(r, g, b)` tuples:

```python
def build(scheme: Scheme, frames: int) -> list[list[tuple[int, int, int]]]
```

Pure, no device access. That is what makes `docs/TESTING.md` possible — the
whole test suite runs with the mic unplugged.

Most effects are far easier to write against the **12×9 unrolled grid** (row 8
is the ring) and then sample the requested zone. `geometry.py` owns that
mapping in both directions.

---

## Build order

Each step should be verifiable before moving on.

### 1. `geometry.py`
Index ↔ `(column, row)` mapping, `is_ring`, and the grid helpers from
`PROTOCOL.md` §4. Pure logic, so unit-test it: ring must be exactly the 12
indices where `i % 18 in (8, 9)`; the 96 body indices must cover 12 columns × 8
rows with no gaps or duplicates.

### 2. `colour.py`
`scale`, `lerp` (divide by `total`, **not** `total-1`), saturating `add`,
Manhattan `distance` and `gamma`. Small and heavily used;
get it right early.

### 3. `daemon.py` + `solid`
The first end-to-end path. Streams one frame forever. Once solid works, the
transport is proven and everything else is content.

Must handle: single-instance takeover, signals, and clean release.

### 4. The simple effects
`blink`, `cycle`, `wave`, `vertical`, `lightning`, `pulse`. All share one
mechanism — a per-frame colour sequence, optionally phase-shifted per LED by
angular position (`wave`) or row (`vertical`).

Get the **distance-proportional transition budgeting** right here; `cycle`,
`wave` and `vertical` all depend on it.

### 5. `spin`, `fire`
Per-LED effects. `spin` needs the plateau head; `fire` needs the heat palette
and sub-frame interpolation.

### 6. `rain`
A grid effect. It needs the shared-RNG-per-zone arrangement so the two zones
draw the same scene rather than two independent ones.

### 7. CLI, packaging, udev rule, README

---

## Single-instance handling

Only one process can hold the interface, so **a new run must take over from the
old one** rather than refusing. Otherwise every change of mode needs a manual
kill, which is genuinely annoying in practice.

**A pid file alone is not enough.** A replaced instance removes the file on its
way out, so any run whose pid never made it back into the file becomes
invisible and is never handed over — leaving two instances fighting over the
device. That failure reproduced on essentially every attempt.

Ask the kernel instead: scan `/proc` for processes of the same name and user,
signal them, and **wait for them to actually exit** before claiming the
interface. Keep a pid file only as a portable fallback.

**Signal handling must not depend on the main loop noticing a flag.** libusb's
synchronous transfers can block in `futex_wait` when the device is contended,
so the loop may never get to look. In Python, make sure the handler terminates
the process itself rather than setting a flag some blocked call will never
return from. Verify by killing an instance while it is streaming.

---

## CLI

Keep it close to what already exists, since the user is used to it, but the
zone flags should say what they mean — this hardware has a ring and a body, not
an "upper" and "lower":

```
quadcast2s [--ring | --body] [-b N] [-s N] [-d N] MODE [COLOURS...]
```

- `--ring` / `--body` select a zone; default is both. Each zone can run a
  different mode in one invocation.
- `-b` brightness 0–100, `-s` speed 1–100 (default 81), `-d` delay (blink only)
- colours are hex, `#rrggbb` or `rrggbb`
- the literal word `random` in place of colours asks the mode to choose

Consider accepting `--upper`/`--lower` as hidden aliases.

`-s` must do something in **every** animated mode. In the C version `fire`
silently ignored it, which went unnoticed because the effect is random enough
that it looked like it was responding.

---

## Testing

`docs/TESTING.md` is the methodology. Since effects are pure functions, the
suite needs no hardware:

```
tests/
    test_geometry.py    ring/body partition, grid round-trip
    test_colour.py      lerp endpoints, gamma monotonic, saturating add
    test_effects.py     density, seam, speed monotonicity, zone isolation
```

The seam and speed-monotonicity checks are the valuable ones — they catch the
bugs that are invisible in code review and expensive to catch by eye.

---

## Deliberately out of scope

- **Other microphones.** See the licensing boundary in `CLAUDE.md`.
- **`44 03` / `44 04`.** Unidentified; see `PROTOCOL.md` §6. Worth
  investigating, not worth blocking on.
- **A VU meter.** The obvious showcase — the body is a 12×8 grid and the mic's
  audio device is right there — but it needs live audio capture rather than
  precomputed frames, so it does not fit the current architecture. Design the
  frame source so a live producer could be slotted in later, but do not build
  it now.
