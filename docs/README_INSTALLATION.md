# Kivun Terminal v1.1.12 - Full Installation Guide

## System Requirements

- Windows 10 version 2004+ (build 19041) or Windows 11
- 64-bit x86-64 CPU with virtualization enabled in BIOS/UEFI
- 4 GB RAM minimum (8 GB recommended)
- ~2 GB free disk space on the system drive

## Step 1 - Download

Go to the [releases page](https://github.com/noambrand/kivun-terminal-wsl/releases/latest) and download `Kivun_Terminal_Setup.exe`.

The installer is currently **unsigned**. You may hit one of two Windows protections:

- **Smart App Control (SAC)** on Windows 11: dialog says *"Smart App Control blocked an app that may be unsafe"* with only an **Ok** button - no override. SAC refuses unsigned apps entirely. To install, open **Start** → search **Smart App Control** → switch it **Off**. SAC cannot be turned back on without reinstalling Windows, so leave it off only if you're comfortable running other unsigned apps.
- **SmartScreen** (the milder warning): says *"Windows protected your PC"*. Click **More info** → **Run anyway**.

## Step 2 - Prerequisite: WSL2

Check whether WSL2 is already installed on your system:

```cmd
wsl --status
```

If the command prints WSL info, you're good - skip to Step 3. If it says WSL is not installed, do this one-time admin step:

1. Right-click Start → **Terminal (Admin)** (or "Windows PowerShell (Admin)" on Win10).
2. Run: `wsl --install`
3. Reboot when prompted.

Once WSL2 is set up, you do **not** need admin rights again.

## Step 3 - Run the installer (no admin required)

Double-click `Kivun_Terminal_Setup.exe`. The installer runs as your normal user and writes only to your profile (`%LOCALAPPDATA%\Kivun-WSL`).

Note: until the installer is code-signed, Windows SmartScreen may show "Windows protected your PC". Click *More info* → *Run anyway*. On Windows 11 with **Smart App Control** turned on, the installer is blocked outright - see Step 1 for how to turn SAC off.

The wizard steps:

1. **Welcome** - lists what will be installed.
2. **License** - MIT.
3. **Components** - all required sections are pre-selected. Optional:
   - *Open VcXsrv download page* - opens the official VcXsrv SourceForge page in your browser for manual install (we no longer auto-install third-party binaries). Only needed if you want Alt+Shift keyboard switching inside Konsole.
   - *Right-Click Menu Integration* - adds "Open with Kivun Terminal" to folder context menus.
4. **Directory** - default `%LOCALAPPDATA%\Kivun-WSL` is recommended. Do not reuse `%LOCALAPPDATA%\Kivun` (that belongs to Launchpad CLI v2.4.x).
5. **Install** - installs Ubuntu (if missing), Konsole, Claude Code. This can take 5–15 minutes on a fresh Ubuntu.
6. **Finish** - launch immediately or view this guide.

## Step 4 - First-run Ubuntu setup

On the first launch, Ubuntu prompts you in a terminal to create a username and password for the WSL Ubuntu account. Pick any values - these are local-only, used solely for `sudo` inside WSL, and never touch the Claude API or any network. See [SECURITY.txt](SECURITY.txt) for more.

## Step 5 - Launch

Three ways to start:

- **Desktop shortcut** - double-click `Kivun Terminal`. Opens in `%USERPROFILE%`.
- **Right-click a folder** - choose *Open with Kivun Terminal* (if you enabled this component). Opens in that folder.
- **From CMD** - `"%LOCALAPPDATA%\Kivun-WSL\kivun-terminal.bat" "C:\path\to\project"`.

On first launch, Claude Code will prompt you to authenticate with your Pro/Max subscription or paste an API key. This only happens once per Ubuntu user.

## Step 6 - Configure language and direction

Edit `%LOCALAPPDATA%\Kivun-WSL\config.txt`:

```ini
PRIMARY_LANGUAGE=hebrew        # or arabic, persian, urdu, pashto, kurdish, dari, uyghur, sindhi, azerbaijani
RESPONSE_LANGUAGE=english      # controls --append-system-prompt sent to Claude
TEXT_DIRECTION=rtl             # rtl = Hebrew/Arabic input hugs right edge; ltr = default
USE_VCXSRV=false               # true requires VcXsrv installed (manual install - see Step 3)
```

Save, then close and reopen Kivun Terminal for changes to take effect.

## Step 7 - Verify the install

Run these checks from CMD:

```cmd
wsl --status
wsl -d Ubuntu -- command -v claude
wsl -d Ubuntu -- command -v konsole
```

All three must succeed. If one fails, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

## Uninstalling

Use *Apps & Features* → **Kivun Terminal** → *Uninstall*, or run `%LOCALAPPDATA%\Kivun-WSL\Uninstall.exe`.

The uninstaller removes:
- Launcher scripts, config, docs
- Desktop shortcut, Start Menu entry, right-click menu

The uninstaller deliberately **leaves**:
- WSL2, Ubuntu distribution (shared with other tools)
- Konsole, Claude Code inside Ubuntu
- Launch logs at `%LOCALAPPDATA%\Kivun-WSL\*.txt`

To fully remove Ubuntu: `wsl --unregister Ubuntu` (this destroys all data in the distribution).
