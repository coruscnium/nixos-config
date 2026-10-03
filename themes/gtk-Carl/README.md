# Carl for GTK

A port of the Kvantum theme **Carl** (by jomada, based on *KvAdaptaDark* by Tsu Jan)
to GTK 4 / libadwaita and GTK 3.

The source theme is a Qt style: `Carl.kvconfig` (a Kvantum config) plus `Carl.svg`
(an SVG sprite sheet that Kvantum slices for widget frames). Nothing in that format
transfers mechanically to GTK, so this is a re-implementation from Carl's extracted
design tokens rather than a file conversion.

---

## What Carl actually is

Three traits define it, and all three survived the port:

1. **Aggressively flat.** `window.color`, `base.color`, `alt.base.color`,
   `button.color` and the menu fill are all the *same* `#111216`. There is no
   elevation anywhere — separation comes from hairline borders. Because
   `alt.base.color` equals `base.color`, there is also no row striping.
2. **One gradient, everywhere.** Every single state gradient in `Carl.svg` is the
   identical violet→cyan ramp `#7040ff → #05b5ff` — check boxes, radios, slider
   handles, progress fill, selected rows, menu highlights, focused entry
   underlines, active tab markers. Its midpoint computes to `#3a7aff`, which is
   essentially the `#3c78ff` the author set as the flat Qt `highlight.color`; the
   flat value was clearly derived from the gradient.
3. **Underlined entries.** `[LineEdit]` sets `interior=false` and the SVG only
   paints the `lineedit-*-bottom` slices, so text fields are bottom-border only,
   and the border becomes the gradient on focus. Pure Adapta heritage.

## Palette

| Role | Colour | Source |
|---|---|---|
| All surfaces | `#111216` | `window/base/alt.base/button.color` |
| Raised (buttons, cards) | `#16181d` | see deviations |
| Text | `#cfd8dc` | `text.color` |
| Disabled text | `#556064` | `disabled.text.color` |
| Tooltip text | `#eefcff` | `tooltip.text.color` |
| Accent gradient | `#7040ff → #05b5ff` | every gradient in `Carl.svg` |
| Accent flat | `#3c78ff` | `highlight.color` |
| Accent standalone | `#6d9aff` | lightened for 6.9:1 on `#111216` |
| Frame border | `#29353b` / `#212c31` | `common-*` slices |
| Entry underline | `#47535a` | `light.color` |
| Check/radio outline | `#717b81`, hover `#7f898f` | `checkbox-normal` |
| Scrollbar | `#556165`, hover `#6c787d` | `scrollbarslider-*` |
| Trough | `#4db6ac` @ 20% | `progress-normal` |
| Hover wash | white @ 5% | `itemview-focused` |
| Red | `#f04a50` | `mdi-close-focused` |
| Links | `#009dff` / `#b172ff` | `link.color` / `link.visited.color` |
| Corner radius | 2px | checkbox `rx=2` |

---

## Installing

```sh
# theme package (both toolkits)
cp -r Carl-GTK ~/.local/share/themes/Carl

# libadwaita apps — the ONLY route that reaches them
cp Carl-GTK/gtk-4.0/carl.css ~/.config/gtk-4.0/carl.css
printf "\n@import 'carl.css';\n" >> ~/.config/gtk-4.0/gtk.css

# GTK3 — needed too if anything already defines colours there (see below)
cp Carl-GTK/gtk-3.0/carl.css ~/.config/gtk-3.0/carl.css
printf "\n@import 'carl.css';\n" >> ~/.config/gtk-3.0/gtk.css
```

Then set the GTK theme to `Carl` (System Settings → Colours & Themes →
Application Style → GNOME/GTK Application Style, or `gtk-theme-name=Carl` in
`~/.config/gtk-{3,4}.0/settings.ini`).

### Why GTK3 needs the config-directory copy as well

A theme directory loads at `GTK_STYLE_PROVIDER_PRIORITY_SETTINGS`, but
`~/.config/gtk-3.0/gtk.css` loads at `PRIORITY_USER`, which is **higher**. So any
`@define-color` already sitting in that user file silently overrides the theme's
own definitions — the theme is installed and active, and its named colours still
lose.

This bites in practice because kde-gtk-config and the Material-You palette
generators both write colour definitions there. On the machine this was developed
against, the user file redefined `accent_bg_color`, `window_bg_color` and
`theme_selected_bg_color` (the last as `alpha(@accent_color, 0.15)`), which is
exactly what produced pale-lavender selections and stray accent colours with
Carl otherwise correctly installed. Loading `carl.css` from that same file, last,
puts Carl's definitions at the winning priority.

`carl.css` is therefore split out from `gtk.css` in both toolkits: `gtk.css` is
the theme entry point (base import + layer), `carl.css` is the standalone layer
you can load from anywhere.

### Why libadwaita needs the extra step

libadwaita **ignores `gtk-theme-name` entirely** — a theme directory does nothing
for it. The only supported customisation point is `~/.config/gtk-4.0/gtk.css`,
which GTK loads as user CSS on top of libadwaita's own stylesheet. That is why
`carl.css` is written as a self-contained recolour layer: it works both as a user
override and as the payload of the theme directory.

Since libadwaita 1.6 the styling API is **CSS custom properties** (`--accent-bg-color`
and friends) rather than the old `@define-color` names. `carl.css` sets the
variables as the primary mechanism and mirrors the legacy names afterwards for
apps that still read them.

---

## Deviations from the source

Everything here is a judgement call, not an extraction. Each is a one-line change
if you disagree.

- **Raised surfaces `#16181d`.** Carl is literally flat — buttons and cards are the
  same `#111216` as the window. That reads as broken in libadwaita, whose
  preference windows rely on cards separating from the background. `#16181d` is
  barely lifted (and is the value kde-gtk-config already derives for buttons from
  this scheme). For a literal match, set `--carl-raised` to `#111216`.
- **Progress/level thickness 3px.** `progressbar_thickness=2` in the kvconfig, but
  GTK renders these at a different scale and 2px nearly vanishes. Three `min-height`
  values in the progressbar/levelbar sections.
- **Warning colour `#ffc107`.** Carl defines no warning colour at all — this is the
  only invented value in the theme. Material amber, checked against `#111216`.
- **Focus rings are left to the toolkit.** Carl's `[Focus]` element is a dashed
  pattern, and an earlier version of this theme reproduced it. That turned out to
  be a mistake worth recording: a bare `:focus-visible` (GTK4) or `*:focus` (GTK3)
  matches every widget in the focus chain, not just the focused control, so the
  first keypress outlined containers all the way up and the window filled with
  nested blue rectangles. Both rules are gone. libadwaita already draws a focus
  ring from `--accent-color`, which Carl sets, so the ring is Carl-coloured
  anyway. Commented-out scoped versions are left in place in both files if you
  want the dashed pattern back.
- **Gradient vs flat on toggles.** `button-toggled` in the SVG is flat `#3c78ff`,
  and that is preserved for toggle buttons. The gradient is reserved for
  `.suggested-action`, which has no Kvantum equivalent but is GTK's primary
  emphasis affordance.
- **No window translucency.** Carl sets `translucent_windows=true`,
  `reduce_window_opacity=30` and `blurring=true`. GTK does not set the KWin blur
  hint, so translucency without blur would just look muddy. Omitted deliberately.
- **Dark only.** Carl has no light variant, so the theme applies unconditionally
  rather than behind `prefers-color-scheme`.

## Known limits

- **GTK3 is a recolour layer, not a ground-up theme.** It imports Adwaita-dark for
  structural completeness and then restyles every surface Carl defines. Adwaita's
  compiled stylesheet inlines roughly 780 literal colours against only 36
  `@define-color` names, so the `@define-color` block alone is not sufficient — the
  explicit rules are what do the work. Widgets Carl never described keep
  Adwaita-dark's appearance.
- **Flatpak apps** need `--filesystem=xdg-config/gtk-4.0:ro` (and
  `xdg-config/gtk-3.0:ro`) to see these files.
- **kde-gtk-config** regenerates `~/.config/gtk-{3,4}.0/colors.css` whenever the
  Plasma colour scheme changes, and may rewrite `settings.ini`. It does not touch
  `carl.css`, and the `@import` sits at the end of `gtk.css` so Carl still wins.
  If it ever rewrites `gtk.css` itself and drops the import, re-append it.
- **Generic containers are never given an opaque background.** `box`, `grid`,
  `stack`, `overlay`, `viewport` and the bare `.background` class are left
  transparent on purpose. Filling them looks harmless on a plain window, but any
  such container sitting inside a selected row punches a dark rectangle through
  the row's highlight, framing the label in black. GTK3's `.view` class is
  excluded for the same reason — GTK3 puts it on sidebar rows, not just views.
- **Other stylesheets imported alongside** can still beat Carl on specificity.
  A `.thunar *` rule, for instance, outranks a bare `window` selector regardless
  of import order. Carl only guarantees it wins on equal specificity.

## Verification

Both stylesheets parse against the real toolkit parsers on GTK 4.22.4 /
libadwaita 1.9.2 / GTK 3.24.52 with zero errors. Computed-style probes confirm
`var()` resolves inside `alpha()` and `shade()`, that the libadwaita variable
overrides beat the defaults, and that the GTK3 layer overrides Adwaita's
baked-in literals.

Rendered and inspected on a virtual display (Xvfb) in Flatseal and NewsFlash
(libadwaita) and gedit and Seahorse (GTK3). Sampled pixels confirm the accent
gradient interpolates correctly end to end — a selected row runs
`(108,68,255) → (12,173,255)`, essentially exactly `#7040ff → #05b5ff` — that
header-bar buttons are flat `#111216`, and that selected rows show no container
fill punching through the highlight.

Visual checking mattered: it caught a specificity bug that no colour probe
could. `button.toggle` scores (0,1,1) and outranks a bare `headerbar button` at
(0,0,2), so every toggle button in a header bar — search toggles, menu buttons —
kept the raised fill and rendered as an empty box. All the named colours were
correct the whole time.
