**"Apply now" for the terminal color — see it without a full relaunch.** 🎨⚡

### Change the color and see it in a new tab right away

Since v1.6.1 you could pick a terminal color in the folder picker's **Advanced
options**, but it only took effect the next time you launched Kivun. Now the
**Apply now** button does the work immediately:

- It regenerates Konsole's color scheme in the background, so a **new tab**
  (Ctrl+Shift+T) shows the new color right away — no need to close Kivun and lose
  your running Claude session.
- The window that's already open keeps its current color. Konsole can't repaint a
  session that's already running, so the honest rule is simply: **open a new tab
  to see the change** (or relaunch to recolor everything).

It just works in the background: Kivun finds your real Ubuntu and the right user
account on its own, exactly like the launcher does. If WSL happens to be off, the
button still saves your choice and the color appears on your next launch.

### Updating

Install v1.6.2 over your current version. Your `config.txt` and settings are kept.
Nothing to configure.
