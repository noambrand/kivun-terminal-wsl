**A steadier cold start, plus color and a memory cap right in the picker.** 🧠🎨

### The window no longer flakes when it's been idle ⏳

A field report showed the real "it got stuck" story: on a cold or long‑idle WSLg,
the terminal would open and then close again within about 30 seconds on the first
few launches, and only stay open after the 4th or 5th try. Nothing was actually
broken — WSLg just needed a moment to warm up.

Now the launcher rides that out for you:

- It waits briefly for the display to be ready before opening the window.
- If a window still dies within 45 seconds (a cold‑start flake — a healthy Kivun
  window never closes on its own since v1.6.0), it **relaunches automatically**,
  up to 3 times, instead of leaving you to keep retrying.

### Set the color and cap WSL's memory from the picker 🎛️

Open **Advanced options** in the folder picker and you'll find two new controls:

- **Terminal color** — choose light blue (Kivun), dark, black, white, keep
  Konsole's own theme, or type any custom color like `#1e1e2e`. No more digging
  in `config.txt`. Konsole repaints on a fresh window, so it applies the next
  time you launch Kivun.
- **WSL memory limit** — WSL2 runs a small Linux machine in the background that
  can hold a lot of RAM. Set a cap (for example, 3 GB) and it's saved to your
  `.wslconfig`. It kicks in after WSL fully restarts (close all Kivun/WSL windows,
  or restart your PC) — Kivun won't restart WSL for you.

### Updating

Install v1.6.1 over your current version. Your `config.txt` and settings are kept.
Nothing to configure.
