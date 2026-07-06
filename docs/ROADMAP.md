# Kivun Terminal — roadmap

Ideas accepted but not yet scheduled. Not a commitment; order is not priority.

## Terminal color — live apply for a running Kivun window
**Status:** planned, not started.

Today the folder picker's **Terminal color** control writes `TERMINAL_COLOR` to
`config.txt`, and the color takes effect on the **next launch** (Konsole only
repaints on a new window; a running window keeps its color). This matches
Konsole's own behavior and is honest, but an "Apply now" that recolors *without*
relaunching would be nicer.

**Sketch of the work:**
- Add a small WSL-side helper (or a sourced color-lib shared with
  `kivun-launch.sh`) that regenerates `~/.local/share/konsole/ColorSchemeNoam.colorscheme`
  and adjusts the profile's `ColorScheme=` line from a given `TERMINAL_COLOR`
  value — so a **new tab** (Ctrl+Shift+T) immediately shows the new color.
- Have the picker's "Apply" run it via `wsl -d <distro>`. Two gotchas to handle:
  the helper must be CRLF-safe when run straight from `/mnt/c` (the launch-time
  `sed -i 's/\r$//'` strip doesn't cover a picker-triggered run), and the distro
  isn't always literally `Ubuntu` (reuse the real detected distro, not the
  hardcoded `SND_DISTRO`).
- Optional stretch: use Konsole D-Bus to reload the scheme on the *current*
  session so even the open window recolors, not just new tabs.

**Why deferred (v1.6.1):** it adds new, hard-to-test-here WSL surface (a helper
script + HTA WSL wiring). The config-write + "relaunch to apply" path we shipped
is low-risk and already gives the picker a discoverable color control. Pick this
up once there's a machine to click-test the live path on.
