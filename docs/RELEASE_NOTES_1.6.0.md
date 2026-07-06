**Pick your own terminal color, and `exit` no longer closes the window.** 🎨

Two things people kept asking for, both done in this release.

### Choose your background color 🎨

The light-blue Kivun background is lovely, but it is a lot of blue for a long
work day. Now you choose. Open your `config.txt` and set `TERMINAL_COLOR=` to:

- `kivun` — the light blue (the default, nothing changes if you leave it)
- `dark` — a soft dark gray
- `black` — near black
- `white` — clean white
- `default` — keep your own terminal's colors, Kivun won't touch them
- or **any color you like** as a hex code, for example `TERMINAL_COLOR=#1e1e2e`

The **text color is picked for you** so it always stays readable — dark text on a
light background, light text on a dark one. A change takes effect the next time you
launch; close any open Kivun windows first so the new color is picked up.

### Type `exit` to run something, then `claude` to come back ↩️

Before, if you typed `exit` inside Claude to run a quick command, the whole window
closed and you had to start over. Not any more. When Claude ends, the window
**stays open at a normal command prompt**. Run your update, a `git` command,
anything you like — then just type **`claude`** to jump right back into Claude with
all your settings (your language, the Hebrew fix, your flags), or **`exit`** to
close the window. It works in the main window and in the fallback mode.

### Updating

Install v1.6.0 over your current version and reopen Kivun. Your `config.txt` is
kept as-is; if it has no `TERMINAL_COLOR` line yet, Kivun stays on the light blue,
exactly as before. Nothing else to set up.
