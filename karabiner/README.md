# Karabiner configs — shared across Macs

These complex-modification JSON files apply to **both** mba13-mac and
mbp16-mac. Machine-specific configs (e.g. mba13's UK-keyboard remap)
live under that machine's own folder instead — see `../mba13/karabiner/`.

## Files

- `caps_lock_to_hyper.json` — remaps Caps Lock to a "Hyper key" (sends
  Command+Control+Option+Shift). It's implemented as Caps Lock →
  Left Shift held together with Command+Control+Option, rather than a
  bare modifier combo, because Karabiner's `to` event needs a `key_code`
  to attach the modifiers to — this is the standard workaround. The
  effective result is a single physical key you can bind other tools
  (Raycast, Hammerspoon, etc.) to as a chord no normal typing will ever
  produce by accident.

## Installing a rule

Complex modifications are picked up from
`~/.config/karabiner/assets/complex_modifications/`. `basic_setup.sh`'s
Karabiner section copies the relevant file(s) there for you and prints
the path — from there, open **Karabiner-Elements → Complex
Modifications → Add rule** and enable it (enabling isn't scriptable;
it's a one-time manual step per rule).

## Finding a keyboard's vendor/product ID

Needed if you're adding a `device_if`/`device_unless` condition scoped
to a specific keyboard (see `../mba13/karabiner/README.md` for why
mba13's UK keyboard needed one). Easiest source: Karabiner-Elements
ships with a **Karabiner-EventViewer** app — open it, go to the
"Devices" tab, and it lists every connected keyboard's vendor_id and
product_id directly. (Alternative: `system_profiler SPUSBDataType` from
Terminal, though built-in keyboards don't always show up there since
they're not on the USB bus — EventViewer is more reliable.)
