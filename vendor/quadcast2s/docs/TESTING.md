# Testing and verification

You cannot see the LEDs. The user can, but every question costs them real
attention, and their time is the scarce resource here. This document is about
getting the most out of both channels.

---

## Verify numerically first

Never ask the user to check something you could have measured. Generate the
frame data and inspect it before involving them.

Structure the code so frames can be produced **without touching the device** —
a `--dump` flag, or an importable function returning the frames. That single
design choice is what makes everything below possible.

Things worth asserting automatically:

| Property | How | Catches |
|---|---|---|
| zone mapping | ring LEDs all colour A, body all colour B | `--ring`/`--body` wired wrong |
| density | count lit LEDs per frame | "too dense", "avalanche" |
| vertical gradient | mean brightness per row, bottom to top | fire with no falloff |
| angular spread | distinct colours per column | wave not actually travelling |
| loop seam | delta last→first vs max frame-to-frame delta | visible jump every loop |
| speed response | mean per-LED change per frame, at several speeds | `-s` doing nothing |
| motion smoothness | stdev of per-frame delta | the "slinky" stutter |
| colour fidelity | fraction of lit cells exactly matching a requested colour | unwanted blending |

The generic motion metric that caught several bugs:

```python
def motion(frames):
    """Mean per-LED luminance change between consecutive frames."""
    d = [sum(abs(lum(a) - lum(b)) for a, b in zip(f0, f1)) / len(f0)
         for f0, f1 in zip(frames, frames[1:])]
    return mean(d), pstdev(d), max(d)
```

- mean rising monotonically with `-s` ⇒ speed works
- large stdev ⇒ uneven motion, the "slinky"
- last→first delta above `max(d)` ⇒ the loop jumps

---

## Randomness produces false positives

`fire` and `rain` use random numbers and **differ between runs**.
Comparing output between two runs will show a difference no matter what you
changed, which reads as "the option works" when it does not.

This actually happened: an audit reported `fire` responding to `-s` and `-d`
when it ignored both.

**Always run the same arguments twice first.** If the two differ, the effect is
nondeterministic and you must compare *structural* metrics — frame counts,
density, motion — never raw output.

---

## Using the user's eyes well

### Hold the pattern in a loop

A one-shot frame is gone before they look, and the firmware rainbow returns —
which reads as "it's broken". Stream continuously for as long as they might
need, several minutes. If comparing variants, cycle them on a fixed schedule
and say what the schedule is.

### Make the pattern self-describing

The best test answers a question without the user having to interpret anything.
Ranked by how well they worked:

1. **Distinct colour per hypothesis.** Three handshake variants shown as green
   / blue / magenta settled in one question which one drove the LEDs — the
   answer was simply "which colours did you see".
2. **Hue sweep across the index range.** Instantly revealed that the ring
   showed a full rainbow while body columns were each one colour — that single
   observation cracked the layout.
3. **Colour-coded offsets.** Assigning a nameable colour to each of six offsets
   exposed the mirror pairing that identified the serpentine run.
4. **Turn things OFF.** Confirming the ring set by driving *only* the body
   (ring must go dark) is stronger than driving the ring, because it cannot be
   faked by diffuser bleed.

### Ask about one variable at a time

Questions mixing two variables produced contradictory answers that cost several
rounds. "Is it red or blue, and where" is two questions.

### Watch for optical effects

The diffuser bleeds. Light appearing where no LED is driven is usually bleed,
not an addressing error. Distinguish by turning the suspected source off —
bleed disappears with its source, a driven LED does not.

### Take literal descriptions literally

Every one of these turned out to be a real bug with a specific cause:

| What they said | What it actually was |
|---|---|
| "like a slinky, slows down and speeds up" | gradient boundary repeated a frame; transitions budgeted evenly across unequal colour distances |
| "a black column circling around" | comet faded on both sides, lighting 10 of 12 columns |
| "reads more like random flicker" | fire simulated at full frame rate with a flat palette |
| "WAY too fast to tell" | rain specified in repeats-per-loop, not fall duration |
| "everything blends together, especially neighboring LEDs" | painted halo on top of the diffuser's own bloom |

Resist explaining why it is fine. It generally is not.

---

## Never use the camera

There is a webcam on this machine. **Do not read `/dev/video*`, and do not
shell out to ffmpeg to capture from it.** This was asked for explicitly after
an attempt to get visual ground truth that way.

When visual confirmation is needed: drive the hardware into a self-describing
state and ask. Offering to let the user share a photo *they* choose to take is
fine; capturing one is not.

---

## Process hygiene

Stale daemons are the single biggest source of confusing results. At one point
**forty** instances were competing for the device while the user was being
asked what they saw, which is almost certainly why several early answers
conflicted.

**Before trusting any visual observation, check the process count.**

```bash
pgrep -x quadcast2s | wc -l      # must be exactly 1
```

- Use `pkill -x`, **never `pkill -f`**. `-f` matches whole command lines, and
  this project's own path contains the string, so it kills your own shell. In
  an agent session that appears as a tool call dying with exit code 143/144 and
  no output.
- For scripts whose names appear in your own command line, use the bracket
  trick (`pgrep -f "[q]uadcast2s"`) or track PIDs in a file.
- A new run should take the device over from the previous one. If instances
  ever accumulate, that logic has regressed — treat it as a bug, not a nuisance.

---

## Shell traps in this environment

- **zsh does not word-split unquoted expansions.** `$args` is passed as a
  single argument; use `${=args}`. This silently broke a regression harness and
  produced a screen of fake failures.
- `status` is read-only in zsh — do not use it as a variable name.
- Background a long demo and poll it; do not block a tool call for minutes.
- Redirect long output to a file and summarise. Debug dumps of 300 frames are
  enormous.

---

## A regression run worth keeping

Every mode, every zone combination, launched **while another instance is
already running**, asserting: exit code 0, no output, exactly one process
afterwards, and nothing left behind.

```
solid · blink · cycle · wave · lightning · pulse · vertical · spin · fire
rain · rain random · rain 3fa0ff -s 40
--ring cycle --body rain · --ring rain --body fire ff4000
solid 0 · cycle ff0000 00ff00 · blink ff0000 -d 90
```

Any unexpected output at all is a failure — a silent success is the contract.
