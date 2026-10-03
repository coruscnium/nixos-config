# The GUI

An optional PySide6 front end: pick a mode and colours, watch a live preview,
save the result as a named preset, and optionally start a preset at login.

It is optional in the real sense — the command line has one dependency,
`pyusb`, and installing the GUI is the only thing that adds Qt.

---

## Three rules it is built on

These are worth keeping. Each one is load-bearing.

### 1. It never opens the device

Only one process can claim interface 1. The daemon already knows how to take
over from a previous instance, so **applying a preset runs the same command
line you could have typed** and lets that machinery do its job.

The consequences are all good ones. There is no IPC and no daemon protocol. The
GUI cannot drift away from the CLI's idea of what an option means, because it
is the CLI doing the work. Running the GUI does not lock a terminal out, and a
terminal does not lock the GUI out. And the status bar can report what is
*actually* streaming by reading `/proc`, so it stays correct even when
something else started the daemon.

### 2. Three of its six modules contain no Qt

`presets.py`, `autostart.py` and `runner.py` import no Qt at all, so they are
unit-tested without a display — the same split that lets the effects be tested
without hardware. Only `app.py`, `controls.py` and `preview.py` need PySide6.

Keep new logic on the Qt-free side of that line wherever it will go.

### 3. The preview builds real frames

Because every effect is a pure function from options to frames, the preview
runs the real thing: it builds the frames the daemon would send, composites
them through `daemon.compose`, and steps at the device's own 32 fps. It is not
a mock, so it cannot drift, and it works with the microphone unplugged.

It draws the **unrolled grid** rather than a picture of a microphone: twelve
columns around, eight rows up, and the ring as a strip on top. That is the
shape the LEDs actually make, and the shape effects are written against. Ring
LEDs are drawn round and body LEDs square, which says which zone you are
looking at without a label. Each cell gets a soft halo, because the real
diffuser blooms and a preview of hard-edged squares makes effects look tidier
than they are.

---

## Layout

```
src/quadcast2s/gui/
    __main__.py     entry point: quadcast2s-gui
    presets.py      named setups, saved as JSON      (no Qt)
    autostart.py    the XDG desktop entry            (no Qt)
    runner.py       starting and stopping the daemon (no Qt)
    preview.py      the live LED view
    controls.py     one zone's controls
    app.py          the main window
```

A **preset** is a name plus one or more `Zone`s, and a `Zone` is exactly one
section of the command line. `Preset.args()` turns it back into argv. Keeping
argv as the interchange format is what stops the GUI becoming a second source
of truth: the string in a preset is a string you could have typed.

Presets live in `$XDG_CONFIG_HOME/quadcast2s/presets.json`, written to a
temporary file and renamed, so an interrupted save cannot leave a half-written
one. A missing or corrupt file falls back to the built-in defaults rather than
failing.

## Which controls a mode ignores

`effects.TRAITS` says, per mode, how many colours it uses, whether `-s` and
`-d` mean anything, whether it does something with the literal word `random`,
and what palette it falls back on when given no colours. The GUI greys out
whatever a mode ignores rather than leaving it looking functional.

That table lives in the registry rather than in the GUI on purpose — it is the
sort of thing that silently rots when it is kept in two places.

`palette` exists because a front end showing colour swatches has nowhere to put
"no colours given". Naming a mode's own defaults explicitly must produce
identical frames to naming none, and `test_effects` asserts exactly that.

## Applying is a button, not live

Every apply spawns a process that takes the USB interface away from the one
already streaming, so doing it on each slider tick would thrash the device for
no benefit. The **preview** updates live instead — that is the part you want to
be immediate, and it costs nothing because it never touches hardware.

The rebuild is debounced by 120 ms. `fire` takes about 100 ms to build a full
loop and is the slowest.

## Starting automatically, and coming back

Three independent switches on the Settings tab. Each one *is* a mechanism
rather than a preference this program has to remember and act on later:

| Switch | What it actually does |
|---|---|
| I log in | `systemctl --user enable --now quadcast2s.service` |
| The microphone is connected | touches `~/.config/quadcast2s/start-on-connect` |
| Keep it running | writes a drop-in setting `Restart=always` |

The service takes its arguments from `~/.config/quadcast2s/service.env`, which
the GUI writes as `QUADCAST2S_ARGS=...`. The unit references it unquoted so
systemd splits it back into separate arguments.

**Why the connect switch is a flag file.** The udev rule always asks for
`quadcast2s-hotplug.service` through `SYSTEMD_USER_WANTS`, and that unit
carries `ConditionPathExists=%h/.config/quadcast2s/start-on-connect`. systemd
skips it silently when the file is absent. The alternative -- editing a udev
rule whenever the box is ticked -- would need root every time.

These are **user** units, not system ones. The lighting belongs to whoever is
logged in, and the `uaccess` ACL means it needs no privileges.

**`enable` must be `enable --now`.** On its own, `enable` only takes effect at
the next login: the unit is wired into `default.target.wants` and then sits
there, `inactive (dead)`, with nothing in the journal at all. Ticking the box
looks like it did nothing, which reads as broken rather than as deferred.
Unticking only disables — stopping the lighting because an autostart preference
changed would be a surprise; that is what Stop is for.

**The GUI must go through the service, not around it.** When the service is
running, Apply writes `service.env` and restarts the unit; Stop stops the unit
before killing anything. Spawning a daemon directly would take the interface
off the service's process, systemd would restart that process, and the restart
would take the interface straight back — so a change appeared to work for about
two seconds and then silently reverted. Stop had the same problem in reverse:
killing the process only prompted a restart.

Enabling the login switch deletes any leftover
`~/.config/autostart/quadcast2s.desktop` from the older XDG approach, since both
at once would start two daemons fighting over the interface.

Two details that break a service quietly: `Exec` must be an absolute path,
because it runs in a login session rather than a shell -- `autostart.command()`
prefers the console script beside `sys.executable`, which `PATH` alone would
miss in a virtualenv. And this project's own directory has a space in its path,
so quoting is not theoretical.

## Recovering after sleep

**Not a switch, and not a systemd hook.** The daemon notices a resume by
itself: `CLOCK_MONOTONIC` stops while the machine is suspended and
`CLOCK_BOOTTIME` does not, so time the second accounts for and the first does
not is time spent asleep. On seeing that, the daemon drops its handle and
reopens the device.

Three reasons it lives there rather than in a unit:

- The systemd **user** manager has no `sleep.target` to be `WantedBy=`. Only
  the system manager has one, and reaching from there into a user session is
  awkward.
- The daemon is just as often started from a terminal or by the GUI's Apply
  button, and those should recover too.
- This microphone sets `power/persist`, so after a resume the USB handle can
  still look perfectly valid while the firmware has quietly taken the LEDs
  back. Waiting for an I/O error would never catch that case.

The same loop reopens the device on any `USBError`, so unplugging the
microphone -- or another process seizing the interface -- is survivable rather
than fatal. `Restart=` is only the backstop for something killing the process
outright.

`--wait` makes the daemon come up before the hardware exists instead of
failing. The service uses it; interactive runs do not, so typing
`quadcast2s solid ff0000` with no microphone still fails immediately rather
than hanging.

## Running it as a desktop application

The Arch package installs `usr/share/applications/quadcast2s-gui.desktop` and a
scalable icon into the hicolor theme, so it appears in the application menu
like anything else. Installing into `.../icons/hicolor/` means the package must
depend on `hicolor-icon-theme`; namcap treats a missing dependency there as an
error, not a warning.

`desktop/quadcast2s-gui.desktop` is the same file for hand installation into
`~/.local/share/applications/`, where it expects `quadcast2s-gui` on `PATH`.

## Testing it without a display

Render it offscreen. Do not screenshot the desktop.

```python
os.environ["XDG_CONFIG_HOME"] = tempfile.mkdtemp()   # never the real config
os.environ["QT_QPA_PLATFORM"] = "offscreen"
...
window.grab().save("shot.png")
```

**Always point `XDG_CONFIG_HOME` at a temporary directory**, or a test run will
overwrite real presets and real autostart settings.

Qt tests in `tests/test_gui.py` are guarded with `skipUnless(HAVE_QT)`, so the
suite still passes where PySide6 is not installed.

---

## Bugs already found here, and why they happened

Worth reading before changing this code; three of the four were invisible until
something was actually rendered or measured.

| Symptom | Cause |
|---|---|
| the window would not start at all | loading a preset asks for a preview rebuild, and that ran before the timer it uses existed |
| "Rainbow wave" rendered solid red | the colour list fell back to one red swatch when a preset named no colours, so the GUI could not express "use the mode's own palette" — and saving would have baked red in permanently |
| the colour picker was painted in the colour being picked, unreadably | Qt style sheets **cascade into child widgets**, and a dialog is a child. A bare `background-color` on the swatch, plus parenting the dialog to that swatch, flooded every label and button in `QColorDialog` |
| `rain` shipped only as half of "Rain over fire" | a stock preset that combined two zones made an effect look as though it existed only as part of something else. Defaults are one effect each now |

The style sheet one is the easiest to reintroduce. The rule is scoped with an
object name — `QPushButton#swatch { … }` — and the dialog is parented on the
window, either of which is sufficient. Two tests cover it, one asserting the
rule is scoped and one rendering the dialog offscreen and failing if the swatch
colour floods more than a quarter of the pixels.
