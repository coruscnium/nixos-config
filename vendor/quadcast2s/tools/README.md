# Probe tools

Used to work out the protocol and the LED layout, and kept because they are the
quickest way to check a guess against real hardware. Not needed to run the
program.

Requires `pyusb`. Stop anything else driving the mic first — only one process
can hold the interface.

```bash
PYTHONPATH=../src python3 probe.py info      # firmware banner
PYTHONPATH=../src python3 probe.py reports   # which HID report IDs answer
PYTHONPATH=../src python3 probe.py sub 0x44  # subcommands of a report

# light LEDs by index; the expression gets `i` and returns 0xRRGGBB
PYTHONPATH=../src python3 paint.py '0xffffff if i%18 in (8,9) else 0'
```

`probe.py reports` deliberately skips `0x10` (resets the controller) and the
`0xf0`/`0xf1`/`0xfa`-`0xfd` block, whose numbering suggests firmware update.
See `../docs/PROTOCOL.md`.
