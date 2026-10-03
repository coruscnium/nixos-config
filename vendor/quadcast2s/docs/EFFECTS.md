# Effects

Specifications for all ten effects, with the tuned constants and — more
importantly — *why* each constant has the value it does.

Every number here was arrived at by iterating against the real hardware with
the user watching and giving feedback. Rediscovering them costs a lot of the
user's attention. **Do not casually retune them.** If you do change one,
re-verify with the methods in `docs/TESTING.md`.

---

## Display physics: four lessons that matter more than the algorithms

Three separate effects looked wrong on first attempt, and in every case the
cause was one of these rather than a bug in the effect itself. Read this
section before writing any effect.

### 1. Gamma — linear fades look stepped

LEDs are linear in PWM; the eye is not. A linear brightness ramp appears to
drop off a cliff and then crawl. Square the level before writing it:

```python
def gamma(level):            # level 0..255
    return level * level // 255
```

This was the fix for `spin`'s tail looking "un-smooth", and for the faint end
of the since-removed starfield banding.

### 2. Peak plateaus — a one-cell-wide highlight pulses

There are only **twelve angular positions**. A comet head one column wide is at
full brightness when it lines up with a column and dimmer when it falls between
two, so the peak visibly throbs as it travels. The user described this exactly:
"head has stepping still, but tail fades smoothly".

Fix: give the head a **plateau wider than half the column spacing** (128 in
1/256 units), so at least one column is always at full brightness. With a
plateau radius of 160, measured peak brightness went from a standard deviation
of 11.65 to **exactly 0.00**.

The same applies to any moving highlight, including a future VU meter.

### 3. The diffuser already blooms — do not paint your own halo

A single lit LED spreads into a soft blob through the mic's diffuser. Drawing a
software halo around a "big" star on top of that double-blurs and smears
neighbours together. The user reported it as "everything blends together,
especially neighboring LEDs".

Fix: **size should be brightness, not spatial spread.** A brighter star blooms
wider optically, all by itself. The painted halo was removed entirely.

### 4. Perceived speed depends on colour distance

Splitting an animation loop evenly between colour transitions makes short hops
crawl and long ones race, because colours are not equally far apart in RGB. The
default rainbow is badly uneven, and the result reads as the animation
repeatedly speeding up and slowing down — the user called it "like a slinky".

Fix: allocate frames to each transition **in proportion to the RGB distance**
between its endpoints. Per-frame delta went from 3–10 (stdev 1.5) to 4–6
(stdev 0.53).

And a related trap: interpolate with `step / total`, **never `step / (total-1)`**.
With `total-1` each segment ends on the next colour and the following segment
starts on it, so every boundary holds one value for two frames and the motion
visibly hitches.

---

## Seamless looping

Frames are precomputed into a loop of **1200 frames** (37.5 s at 32 fps) and
replayed. A visible jump at the wrap is very noticeable.

It was 300 frames — 9.4 s — and the user could see it come round. Only `fire`
and `rain` use this number at all; every other effect has a natural length of
its own. At 1200 it costs about a megabyte and a tenth of a second to build,
which is nothing next to being able to watch the seam arrive. 1200 is also far
more composite than 300 (30 divisors against 18), so the periods `cycles()` can
choose land closer to the speed actually asked for.

**A long loop is not on its own enough.** See the note under `rain`: an
animation can repeat every two seconds inside a loop that is forty seconds
long, and that is the repetition people notice.

**The good approach**, used by `rain`: give every element a period
that **divides the frame count exactly**, so it meets itself where it started.
Pick the *nearest* divisor, not the next one up — always rounding up shortens
every period and drags the whole speed range toward the fast end.

```python
def cycles(frames, want):
    """Repeats that divide `frames` exactly, nearest to `want`."""
    up   = next(k for k in range(max(1, want), frames + 1) if frames % k == 0)
    down = next(k for k in range(min(want, frames), 0, -1) if frames % k == 0)
    return up if (up - want) <= (want - down) else down
```

**The fallback**, used by `fire` because a chaotic simulation has no natural
period: cross-fade the last 24 frames into the first.

Always verify: the last-frame-to-first-frame delta must be no larger than the
typical frame-to-frame delta.

---

## Zones

`--ring` (12 LEDs) and `--body` (96) can each run a different effect at once.
Build each effect against the **12×9 unrolled grid** (row 8 = ring) and then
sample whichever zone is being filled — that way rain falls *through* the ring
into the body instead of the zones animating independently.

**Both zones must draw the same randomness.** They are filled in separate
passes, so sharing the global RNG gives each zone its own drops.
Use a private generator reseeded identically per pass, from a seed drawn once
per run:

```python
class Rng:                      # deterministic per run, identical per zone
    def __init__(self, seed): self.s = seed or 1
    def __call__(self, n):
        self.s = (self.s * 1103515245 + 12345) & 0xFFFFFFFF
        return (self.s >> 16) % n if n > 0 else 0
```

---

## Speed mapping

Two shapes, and the distinction matters:

```python
# higher speed -> SMALLER result (a duration)
def speed_range(lo, hi, spd):  return lo + (hi - lo) * (100 - spd) // 100
# higher speed -> LARGER result (a rate)
def speed_scale(lo, hi, spd):  return lo + (hi - lo) * spd // 100
```

Default speed is **81**, which is high on a 1–100 scale — so with a linear
mapping the default sits near the fast end. Always sanity-check what the
*default* produces, not just the extremes. `rain` was originally specified by
repeats-per-loop rather than fall duration, and the default came out at ~0.2 s
per drop: the user said "WAY too fast to tell".

**Drive durations directly.** For rain, `-s` sets the fall time in frames.

---

## The effects

Defaults: colour `#f20000` (red) unless noted, speed 81, brightness 100.

### solid
Constant colour. Uses only the first colour given. Speed is meaningless.

### blink
Steps through the colour list, on then off. `-s` sets on-time
(`speed_range(3, 60)`), `-d` sets off-time. With no colours, picks random ones.
**This is the only effect that uses `-d`.**

### cycle
Whole mic sweeps through the colour list as one gradient loop. Transition
length `speed_range(8, 96)`, frames allocated by colour distance (see above).
Defaults to a 9-colour rainbow.

### wave
`cycle` with the phase offset by **angular position**, so the colour travels
around the mic. Use **12 columns** of resolution, not the 6 blocks — twice as
smooth, and it is free.

### vertical
`cycle` with the phase offset by **row**, so colour travels up the mic. Spread
the 8 rows over exactly one full loop of the sequence, so the gradient is
continuous, and **subtract** the offset so it travels upward. The ring
continues the top row's phase.

### lightning / pulse
Per colour: ramp black→colour over `speed_range(2, 12)`, decay colour→black
over `speed_range(8, 80)`, then blank for `speed_range(2, 30)`. Ramps must
reach their endpoint, so index them `step+1` out of `total`.

The two share this envelope exactly. The only difference is the order the
colour list is walked in: `lightning` shuffles it, `pulse` keeps it as given.
So with a single colour — which is the default — they produce identical output,
and that is intended rather than an oversight. Confirmed deliberately; do not
"fix" it by inventing a spatial component for `lightning`.

### spin
A comet circling the twelve columns.

| Constant | Value | Why |
|---|---|---|
| revolution | `speed_range(16, 160)` | frames for one full circuit |
| tail | 7 columns | trails **behind the head only** |
| lead-in | 2 columns | ramp *ahead* of the head |
| plateau radius | 160 (1/256 col) | > half the 128 column spacing, so the peak never throbs |

Two bugs worth not repeating. Measuring the *nearest* distance around the
circle fades to **both** sides at once — with a 5-column tail that lit 10 of 12
columns and read as a dark gap orbiting the mic, not a comet. And with no
lead-in the column ahead stays black until the head crosses it and then snaps
to full, so the head jumps between columns.

Apply `gamma()` to the level.

### fire
Heat simulation over the 12×8 body grid.

| Constant | Value | Why |
|---|---|---|
| cooling | 30 | per cell per simulation step |
| rise | 5 | upper rows cool `1 + row*5/8` times faster, so flames taper to dark tips |
| sparking | 150/255 | chance a column ignites at its base |
| sub-steps | `speed_range(1, 12)` | frames held per simulation step; `-s` drives this |
| warmup | 40 steps | discarded, so frame 0 already has flames |
| loop blend | 24 frames | cross-fade, since fire has no natural period |

Per step: cool every cell, drift heat upward
(`heat[r] = (heat[r-1] + 2*heat[r-2]) / 3` for `r >= 2`), then maybe spark at
the base. **Interpolate between simulation steps** — running the sim at the
full frame rate strobes; the user said it "reads more like random flicker".

The palette is what makes it read as fire. A flat brightness scale of one
colour does not:

```
heat <128 : black -> the chosen colour   (apply gamma)
heat <208 : colour -> that colour with green lifted toward yellow
heat >=208: -> white-hot
```

Measured result: base brightness 188, tips 23 — an 8:1 falloff. Without the
`rise` term the tips sat at 114 and the user said "the whole mic is orange".

### stars — removed

There was a starfield here: eight stars on the unrolled grid, each riding a
parabola on a brightness floor, drawn from a weighted stellar palette. It was
built, it worked, and it was **removed on purpose**.

The problem is the hardware, not the algorithm. Twelve by nine cells behind a
heavy diffuser cannot hold a starfield: individual points bloom into each other
however far apart they are placed and however carefully they are dimmed, so it
never reads as stars. Tuning had already been through 26 stars, then 12, then
8, and through dropping the painted halo — the remaining problem is the
diffuser itself.

Do not reimplement it. If a future effect wants isolated points of light, that
constraint applies to it too. The stellar palette went with it; recover both
from git history if they are ever wanted.

### rain
Slanting raindrops falling through the ring into the body.

| Constant | Value | Why |
|---|---|---|
| drops | 7 | 18 read as "an avalanche" |
| fall time | `speed_range(14, 170)` frames | **`-s` sets duration directly** — ~1.5 s at default |
| duty | 45–90% of cycle | each drop idles between falls, so the count on screen varies |
| trail | 2–4 cells | fading behind the head |
| drift | ±700 (1/256 col) | sideways travel per fall, so rain slants and no two drops match |
| peak | 150 + rand(106) | |
| per-fall redraw | column, slant, peak, trail and colour | drawn again for **every fall**, not once per drop |

That last row is the one that matters, and it was got wrong first time. Drawing
a drop's column, slant, brightness and colour once and reusing them for every
fall makes each drop repeat one identical fall every 1.6–3.1 s at the default
speed: seven metronomes rather than rain. The user spotted it immediately, and
it is far more visible than the loop point — a 37.5 s loop does not help if the
contents repeat every two seconds. Each drop now draws fresh parameters per
fall, which is roughly 139 distinct falls per loop instead of 7. The swap
happens as a fall begins, while the drop is still off the top of the grid, so
it is never seen changing.

Speed jitter must be **proportional** (`base/4`), not a fixed ±2 — a fixed
spread is as large as the whole range at the slow end and leaves `-s` doing
almost nothing.

Draw drops **anti-aliased** across the cells they fall between, in both axes.
With only 12×9 cells, snapping to whole cells makes drops jump.

---

## Colour helpers

```python
def scale(colour, level):        # level 0..255
def lerp(a, b, step, total):     # NOTE: divide by total, not total-1
def add(a, b):                   # saturating, for overlapping light
def distance(a, b):              # Manhattan in RGB, for transition budgeting
```

Overlapping light should **add** (rain drops crossing brighten). Not every
effect wants that: the removed starfield kept its points apart instead, because
with additive blending and 26 stars three requested colours produced 41
distinct hues.

Brightness (`-b`) is normally folded into the colour list up front. **Colours
invented at runtime** — random rain, `blink` with no colours, `fire`'s
white-hot end — never went through that, so
apply brightness to them explicitly or `-b` will silently do nothing.
