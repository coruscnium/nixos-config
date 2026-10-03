# HyperX QuadCast 2 S — lighting protocol

Everything here was obtained by probing a physical unit over USB. There is no
vendor documentation involved, and none of it was taken from another
implementation. Facts about how a piece of hardware behaves are not
copyrightable; this document is original writing and is covered by the
project's AGPL-3.0-only licence.

Firmware the work was done against:

```
APP: 6.1.1.3 Date: Aug 16 2024 Time: 11:50:53
```

Read that back at any time with `tools/probe.py info`.

---

## 1. USB layout

The microphone enumerates as **two separate USB devices**:

| VID:PID     | What it is                                       |
|-------------|--------------------------------------------------|
| `03f0:0d84` | the audio device (UAC). Nothing to do with lighting |
| `03f0:02b5` | the controller. **This is the RGB device**       |

A udev rule must match the **controller**, `03f0:02b5`. Matching the audio
device is a common mistake and silently achieves nothing.

Grant access with `TAG+="uaccess"` rather than a group. logind then puts an ACL
on the device node for whoever is logged in at the seat, which needs no group
membership and no re-login. `GROUP="plugdev"` is a Debian convention and does
nothing at all on a distribution where that group does not exist — Arch, for
one, where it silently left the rule inert.

The controller exposes three HID interfaces:

| Interface | Endpoints (IN/OUT) | Purpose                                     |
|-----------|--------------------|---------------------------------------------|
| 0         | `0x83` / `0x04`    | vendor page `0xFF13`, 64-byte reports       |
| **1**     | **`0x85` / `0x06`**| **lighting** (vendor page `0xFF13`)         |
| 2         | `0x81` / `0x02`    | vendor page `0xFF59`, microphone settings   |

**Claim interface 1 only.** Claiming others gains nothing and makes the program
collide with anything else holding the device's HID interfaces — Wine grabs
them while a game runs, for instance, which produces a spurious "device is
busy" failure.

Interface 2 is where gain, mute, monitoring and so on live. Its Feature
reports do respond (`GET_FEATURE` on report IDs 1 and 3 return data), so it is
a possible future direction, but it is entirely unexplored and out of scope.

---

## 2. Command set

Byte 0 of every 64-byte packet is a **HID report ID**, not an ad-hoc opcode.
The report descriptor on interface 1 declares exactly these:

```
01 07 10 11 14 15 40 41 42 43 44 45 62 63 64 65 db f0 f1 fa fb fc fd ff
```

Read it yourself from sysfs — it is the fastest way to learn what a device
accepts, and it needs no writes at all:

```bash
cat /sys/class/hidraw/hidrawN/device/report_descriptor | xxd
```

Every one of those IDs also declares a Feature report, but **`GET_FEATURE`
stalls on all of them** on interface 1. The interrupt endpoints are the only
working channel.

What is known:

| Report | Meaning                                                         |
|--------|-----------------------------------------------------------------|
| `0x01` | device info. `01 00` returns the ASCII firmware banner; `01 02` returns an incrementing byte pattern, evidently a loopback self-test |
| `0x07` | answers, but with an empty payload. Unidentified                 |
| `0x10` | **device reset.** The controller re-enumerates. Recovers cleanly, but do not send it |
| `0x44` | the lighting family (below)                                      |
| `0x45` | reply channel for `44 05` and `44 06`                            |
| `0xff` | generic acknowledgement                                          |
| `0xf0` `0xf1` `0xfa`–`0xfd` | **never probed.** The numbering pattern suggests a firmware-update interface, and the risk was not worth taking |

### Acknowledgement format

Writes are answered on `0x85` with:

```
ff 01 00 00 00 00 00 00 00 00 00 00 00 00 <cmd[0]> <cmd[1]>
```

`rsp[0]` is `0xff`, and `rsp[14:16]` echoes the command. **The device
acknowledges anything**, including nonsense arguments and out-of-range values,
so a successful ACK proves only that the packet arrived — never that the
command was understood or had any effect. This is why probing alone could not
map the protocol, and the LED layout had to be established visually.

### Report `0x44` — lighting

Six subcommands exist. `0x00` and everything from `0x07` up return nothing at
all:

| Command                     | Meaning                                          |
|-----------------------------|--------------------------------------------------|
| `44 01 <n> 00`              | announce that `<n>` RGB packets follow            |
| `44 02 <i> 00` + 60 bytes   | RGB payload, packet index `<i>`, twenty `RGB` triples |
| `44 03 ...`                 | acknowledges; effect unidentified                 |
| `44 04 ...`                 | acknowledges; effect unidentified                 |
| `44 05 ...`                 | a read. Answers on report `0x45`, payload empty   |
| `44 06 ...`                 | a read. Answers on report `0x45` with a constant `44 04` at offset 4 |

`44 03` and `44 04` are the most interesting loose ends. They acknowledge but
produced no visible change in any test. `44 06` returning a constant `44 04`
hints they are related — possibly an on-device effect or brightness facility
that would remove the need to stream. Worth revisiting; not required.

### A frame

One header plus six data packets:

```
44 01 06 00  00 * 60                     <- six packets follow
44 02 00 00  <20 x RGB>                  <- LEDs   0.. 19
44 02 01 00  <20 x RGB>                  <- LEDs  20.. 39
44 02 02 00  <20 x RGB>                  <- LEDs  40.. 59
44 02 03 00  <20 x RGB>                  <- LEDs  60.. 79
44 02 04 00  <20 x RGB>                  <- LEDs  80.. 99
44 02 05 00  <20 x RGB>                  <- LEDs 100..119
```

Six packets address 120 slots; **108 LEDs are real**. Writing past 108 is
accepted and ignored — verified by lighting indices 108–159 white and seeing
nothing.

---

## 3. Two rules that are easy to get wrong

These caused the most confusion during the original work, and both fail in ways
that look like something else entirely.

### Frames do not latch

The moment the host stops streaming, the firmware takes the LEDs back and
resumes its own default rainbow. There is no "set and forget". This is why the
program has to run continuously as a daemon.

Practical consequence: if the mic shows a rainbow, the usual cause is that the
stream stopped, not that a command failed.

### Every packet's reply must be read

Writing without reading the reply from `0x85` is accepted by the USB stack and
runs much faster — measured **~143 frames/sec versus ~32** — but **the device
silently ignores every frame** and the LEDs never change.

This was verified directly by showing three handshake variants as three
distinct colours in sequence: reading after every packet worked, reading only
after the header did not, and not reading at all did not.

The handshake is therefore what paces the animation, at roughly **32 frames per
second** (seven round trips per frame). Inter-packet sleeps only make it
slower; the round trip is the entire bottleneck. Any future "optimisation" that
drops the read will appear to work perfectly in logs and produce a dark mic.

---

## 4. LED geometry

108 LEDs. **The index runs around the microphone, not up it.**

Six angular blocks of eighteen. Within a block the strip climbs one body
column, crosses the top ring, then comes back down the neighbouring column —
serpentine:

```
block b  =  indices 18b .. 18b+17          (b = 0..5)

  18b +  0 .. 18b +  7   body column 2b,   ascending   (index  0 = bottom)
  18b +  8 .. 18b +  9   TOP RING segment b
  18b + 10 .. 18b + 17   body column 2b+1, descending  (index 17 = bottom)
```

Therefore:

- **ring = 12 LEDs**, exactly where `i % 18` is 8 or 9
- **body = 96 LEDs**, twelve columns of eight
- `ring` and `body` are the two natural zones for a CLI (`--ring` / `--body`)

Helper mappings:

```python
def is_ring(i):  return i % 18 in (8, 9)
def column(i):   return 2*(i//18) + (0 if i % 18 < 8 else 1)   # 0..11
def row(i):      r = i % 18; return r if r < 8 else 17 - r      # 0=bottom..7
```

### The unrolled grid

Every effect is far easier to write against a **12 wide × 9 tall** grid, where
column 0..11 goes around the mic, rows 0..7 are the body bottom-to-top, and
**row 8 is the ring**. Rain then genuinely falls *through* the ring into the
body, rather than the two zones animating independently.

```python
def cell(i):
    r, b = i % 18, i // 18
    if r == 8: return (2*b,     8)
    if r == 9: return (2*b + 1, 8)
    return (column(i), row(i))
```

### How this was established

Worth recording, because the layout is genuinely counter-intuitive and the
first three guesses were all wrong:

- Lighting indices 0,1,2 in red/green/blue showed three stacked horizontal
  stripes on one face — so consecutive indices climb, they do not go around.
- A full hue sweep across all 108 showed the **ring** displaying a complete
  rainbow while each **body column** was a single colour — so the index visits
  every angular position, and a column is a run of consecutive indices.
- Colour-coding offsets 6..11 individually revealed a mirror pairing: the ring
  showed offsets 8 and 9, while (7,10) sat at one height and (6,11) at the next
  height down. Mirror symmetry about the ring is the signature of a serpentine
  run — up one column, across, back down the next.
- Confirmed by lighting only `i % 18 in (8,9)` (whole ring lit, body dark) and
  then only the body columns (ring dark, twelve alternating columns).

**The diffuser bleeds.** A lit ring visibly glows into the top rows of the
body. This is optical, not addressing, and it caused a false "the ring set is
wrong" conclusion at one point. When a test seems to show light where no LED is
driven, suspect bleed and confirm by turning the suspected driver off.

---

## 5. Timing

| What                                    | Measured                    |
|-----------------------------------------|-----------------------------|
| frame with reply read after every packet | ~31 ms (**~32 fps**)        |
| frame, no replies read (does not work)   | ~7 ms (~143 fps)            |
| effect of inter-packet sleeps            | none; the round trip dominates |

**32 fps is the ceiling.** Design animations around it. It is entirely
sufficient for smooth motion — the effects were all tuned at this rate.

---

## 6. Loose ends

Things a future session could usefully pick up:

- **`44 03` / `44 04`** — acknowledged, effect unknown. If either sets an
  on-device effect or a hardware brightness, it could remove the need to stream
  continuously. The most valuable unknown.
- **Interface 2 (`0xFF59`)** — microphone settings: gain, mute, monitoring.
  Feature reports respond. Entirely unexplored.
- **Hardware brightness** — currently brightness is applied host-side by
  scaling RGB, which loses colour resolution at low settings. If the firmware
  has a real brightness command, it is probably in the `0x44` family.
- **A VU meter** — the body is literally a 12×8 grid and the mic's own audio
  device is right there at `03f0:0d84`. This is the obvious showcase effect and
  needs live audio capture rather than precomputed frames.

Do **not** explore `0xf0`, `0xf1`, `0xfa`–`0xfd` without a strong reason and
the user's explicit agreement. The numbering suggests firmware update, and
bricking the mic is a real outcome.
