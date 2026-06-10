# KivunTerminal.exe — native no-console-flash launcher

**What:** a ~110-line Win32 GUI-subsystem exe that runs `kivun-terminal.bat`
in a windowless console (`CREATE_NO_WINDOW`). The desktop shortcut and the
Explorer context-menu entries target this exe, so launching Kivun Terminal
no longer flashes a black cmd window — Konsole is the only thing the user
ever sees. Continuation of PR #83 by @zuwasi; the architecture (thin hidden
shell over the bat, never a `wsl.exe` bypass) was settled in that PR's review.

**Why a shell over the bat:** `kivun-terminal.bat` is not a thin wrapper —
it does config parsing, the HTA folder picker, WSL health checks, Claude
auto-install, the root-user guard, and WSLENV passthrough. The exe adds
exactly three things: no window, `KIVUN_HIDDEN=1` (the bat suppresses
interactive prompts and keeps the WSL bridge off the taskbar), and a
MessageBox with the `LAUNCH_LOG.txt` tail when the bat exits non-zero —
failures stay visible, per this repo's hard rule.

**Build:** run `build.bat` (finds Visual Studio 2019+/Build Tools via
vswhere, any edition). Output: `out/KivunTerminal.exe` (~150 KB, static
CRT, no dependencies). CI builds it in `build-windows.yml` before
`makensis` packages it into the installer.

**Antivirus note:** the exe is unsigned, and "tiny GUI exe spawns hidden
cmd.exe" resembles dropper heuristics. Mitigations: honest VERSIONINFO +
embedded icon, no packing. If an AV quarantines it, the **"Kivun Terminal
(console)"** Start-menu shortcut launches the same bat with a visible
console — nothing else depends on the exe.
