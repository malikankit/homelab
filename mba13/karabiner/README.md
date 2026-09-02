# Karabiner config — mba13 (UK keyboard)

**Model:** MacBook Air 13" M2 (2022), model number `MLY33ZS/A` (`ZS/A`
= India region code) — built-in keyboard, `is_built_in_keyboard: true`,
`transport: FIFO`, no `vendor_id`/`product_id` reported (Apple Silicon
internal keyboards aren't on the USB bus, so those fields are absent).
That's why `device_if`'s `is_built_in_keyboard: true` identifier is what
actually matches this device — the `vendor_id 1452`/`76` checks in the
store rule are there for other keyboards and don't apply here.

The mba13 has a **UK-style keyboard**, so the stock "UK→US Mac" complex
modification from the Karabiner store (originally 5 manipulators) needed
adjustment before it worked correctly.

## What was changed

Removed the first two manipulators from the original store rule — the
Shift+3 ↔ Option+3 swap (intended to swap `#` and `£`). On this specific
keyboard, the key above `3` already produces `#` on Shift+3 without any
remapping, so that swap was not needed and would have broken things if
applied. Kept the other three manipulators (grave/tilde ↔ left shift
relocation, and the product_id 592 exception).

`uk_to_us_keyboard.json` is the resulting 3-manipulator version actually
in use.

## Physical layout

Almost certainly a **British/ISO English** keyboard — the standard
physical layout Apple ships with India-region configs (matches the
`ZS/A` suffix), and consistent with what's observed directly: the extra
ISO key near left shift, a `§`/`±` key, and Shift+3 producing `#`.

`ioreg -c AppleHIDKeyboard | grep -i keyboardtype` (run on mba13 itself)
returned **no output** — didn't confirm the numeric `AppleKeyboardType`
ID this way. If it's needed later, try System Settings → Keyboard →
Input Sources → Edit → Change Keyboard Type... instead, which walks
through a manual key-press wizard and sets/reveals the type directly.

## Setup reminder

Still requires setting the correct keyboard type in System Preferences →
Keyboard → Change Keyboard Type, or the physical-key-to-key_code mapping
Karabiner sees won't match reality.
