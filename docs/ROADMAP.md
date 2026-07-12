# Kivun Terminal — roadmap

Ideas accepted but not yet scheduled. Not a commitment; order is not priority.

## Terminal color — recolor the ALREADY-OPEN Kivun window live
**Status:** planned, not started. (The new-tab half shipped in v1.6.2 — see below.)

**Shipped in v1.6.2:** the picker's **Apply now** regenerates the Konsole scheme
inside WSL (`kivun-apply-color.cmd` + `kivun-apply-color.sh`) so a **new tab**
(Ctrl+Shift+T) shows a color change immediately, without a full relaunch (which
would kill the running Claude session). The helper detects the real distro (via
`kivun-detect-distro.cmd`, not a hardcoded name) and the WSLg user the same way
the launcher does, and CR-strips itself so a picker-triggered run from `/mnt/c`
is safe. Verified end-to-end in real WSL (color matrix, BiDi preserved, distro +
WSLg-user detection, resolver parity with `kivun-launch.sh`); the only piece not
testable on the dev box is that a new Konsole tab visually repaints, which is
stock Konsole behavior.

**Still open — the harder half:** recolor the window that is ALREADY open, not
just tabs opened afterwards. Konsole loads a color scheme into memory when a
session starts and will not re-read it from a file edit, so this needs Konsole
**D-Bus** (re-apply the profile / reload the scheme on the current session).

**Why it stays deferred:**
- Under WSLg, Konsole is Qt6/Wayland and *forks* by default, so there may be no
  usable D-Bus session bus, and the visible window can be an unmanaged daemon
  instance — the D-Bus surface is genuinely uncertain and can't be exercised here.
- This repo's hard-won rule (it burned three releases on speculative WSLg fixes)
  is: don't ship a WSLg change you can't test. A live D-Bus repaint can't be
  verified on the dev box (no way to see the window paint), so it waits for a
  real-machine click-test.
- The obvious non-D-Bus alternative — injecting an OSC 11/10 background/foreground
  escape into the running PTY — is unsafe while Claude's TUI is drawing, so it is
  not a drop-in substitute.

**Pick this up** once there's a machine to click-test the live path on: confirm a
D-Bus session bus exists under WSLg, find the right konsole instance, re-apply the
profile on the active session, and **degrade silently** to the shipped new-tab
behavior whenever the bus isn't reachable.
