# Kivun Terminal — native Windows launcher (C++)

A ~100 KB Win32 executable that double-click-launches Kivun Terminal with **zero console flash** and no `.vbs`/`.bat` interpreter.

## Why this exists

The default install ships a `Kivun Terminal.lnk` Start Menu shortcut that calls `kivun-terminal.bat`. On launch, Windows briefly flashes a black `cmd.exe` window before WSL takes over. A `.vbs` workaround eliminates the flash but is sometimes flagged by SmartScreen/AV, can't carry a custom icon natively, and silences errors.

This native exe:

- Is a Windows GUI-subsystem binary → **no console window ever appears**
- Spawns `wsl.exe -d Ubuntu-24.04` via `CreateProcessW` with `DETACHED_PROCESS | CREATE_NO_WINDOW`
- Returns immediately → desktop shortcut feels instant
- Calls a fixed-path bash launcher (`~/.local/bin/kivun-start.sh`) inside WSL, which `exec`s into Konsole. wsl.exe stays alive (hidden) parenting Konsole until the user closes the window
- Shows a `MessageBoxW` if `wsl.exe` fails to start (Ubuntu missing, WSL broken, etc.) — better than `.vbs`'s silent failure

## Build

Requires Visual Studio 2022 (any edition with MSVC C++ workload). Run from a normal cmd prompt:

```cmd
build.bat
```

Produces `KivunTerminal.exe` (~100 KB).

To build on Linux/WSL with mingw-w64 instead:

```bash
x86_64-w64-mingw32-g++ -O2 -static -mwindows kivun-launcher.cpp \
    -o KivunTerminal.exe -lkernel32 -luser32
```

## Wiring it into the install

Two ways to use this:

1. **Manual** — copy `KivunTerminal.exe` to your desktop, create a one-line shell wrapper at `~/.local/bin/kivun-start.sh`:
   ```bash
   #!/bin/bash
   exec bash /mnt/c/path/to/kivun-terminal-wsl/linux/kivun-launch.sh
   ```
2. **Integrated** — replace the NSIS-generated `.lnk` target in `installer/Kivun_Terminal_Setup.nsi` with this exe. The `.exe` would need to be either committed (binary in repo, not great) or built as part of the NSIS workflow on tag push (better — VS 2022 build tools are available on `windows-latest` GitHub Actions runners).

## Why the bash hop?

The `wsl.exe -d Ubuntu-24.04 -- bash -lc "..."` pattern is brittle when invoked from `CreateProcessW` because nested double quotes in the command line get re-parsed by both `wsl.exe` and `bash`. Using a fixed-path script (`~/.local/bin/kivun-start.sh`) sidesteps the quoting problem entirely.

## Limitations

- Hardcoded distro name `Ubuntu-24.04` — change at the top of `kivun-launcher.cpp` if you use a different distro. A future version could read this from `%LOCALAPPDATA%\Kivun-WSL\config.txt` via `GetPrivateProfileStringW`.
- Hardcoded user home path inside `kivun-start.sh` — same fix applies.
- No icon embedded; add via `windres` (`.rc` file pointing to `installer/kivun_icon.ico`) for a branded taskbar icon. Currently relies on the existing WSLg `.desktop` registration to set the Konsole window's icon (see `linux/kivun-launch.sh` for the `--name kivun-terminal` argument that drives this).

## Status

This is a **community-contributed alternative launcher**, not the default installer path. Submit issues with the `tools/kivun-launcher` label.
