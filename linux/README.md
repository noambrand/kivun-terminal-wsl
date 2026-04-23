# Kivun Terminal — Linux Quickstart

A shell-script installer that installs Claude Code with a Kivun-themed Konsole profile and file-manager integrations for Hebrew/Arabic/Persian and other RTL languages.

## Supported distros

| Family        | Package manager | Tested on                      |
|---------------|-----------------|--------------------------------|
| Debian/Ubuntu | `apt`           | Ubuntu 22.04 / 24.04, Debian 12 |
| Fedora/RHEL   | `dnf`           | Fedora 40                       |
| Arch/Manjaro  | `pacman`        | Arch Linux, Manjaro             |
| openSUSE      | `zypper`        | openSUSE Tumbleweed             |

Other distros work if you install `konsole`, `nodejs`, `git`, and `zenity` (or `kdialog`) manually, then run the installer — it will skip the package step.

## What the installer does

1. Detects your package manager and desktop environment and installs: `konsole`, `nodejs`, `git`, a color-emoji font, and a folder-picker helper — `kdialog` on KDE/Plasma (avoids pulling GTK dependencies), `zenity` elsewhere.
2. Installs the Claude Code CLI via Anthropic's official installer (skipped if `claude` is already on PATH).
3. Deploys `statusline.mjs` to `~/.local/share/kivun-terminal/` and registers it in `~/.claude/settings.json`.
4. Writes a Konsole profile `KivunTerminal` with `BidiEnabled=true` + a light-blue color scheme `ColorSchemeNoam`.
5. Installs the launcher at `~/.local/bin/kivun-terminal` and adds `~/.local/bin` to your `$PATH` (in `.bashrc` / `.zshrc`).
6. Creates an app-menu entry `~/.local/share/applications/kivun-terminal.desktop` and a desktop launcher at `~/Desktop/Kivun Terminal.desktop`.
7. Installs right-click integrations for GNOME Files (Nautilus scripts) and KDE Dolphin (service menu).
8. Deploys the **`kivun-claude-bidi` wrapper** to `~/.local/share/kivun-terminal/kivun-claude-bidi/` and runs `npm install --production` once. The launcher pipes Claude Code through this wrapper to fix the Hebrew bullet-line direction bug regardless of Konsole BiDi settings (default-on; toggle via `KIVUN_BIDI_WRAPPER`). If `npm` isn't on PATH at install time, the launcher retries on first launch.
9. Creates `~/.config/kivun-terminal/config.txt` with default settings (RTL, Kivun colors, English response, Alt+Shift keyboard toggle, BiDi wrapper on).

System packages are installed as root via `sudo`; everything else lands in your user home — no system-wide files.

## Install

```bash
git clone https://github.com/noambrand/Kivun-Terminal_website.git
cd Kivun-Terminal_website/kivun-terminal-wsl
chmod +x linux/install.sh
./linux/install.sh
```

You'll be prompted for your sudo password once (for the package install step). After the installer finishes, either:

- Start a new shell (so `~/.local/bin` is on `$PATH`), then run `kivun-terminal`, or
- Search your app menu for **Kivun Terminal**, or
- Double-click the **Kivun Terminal.desktop** file on your desktop, or
- Right-click any folder → **Scripts → Open with Kivun Terminal** (Nautilus) / **Open with Kivun Terminal** (Dolphin).

Install log: `/tmp/kivun_install.log`

## Config file

`~/.config/kivun-terminal/config.txt`:

| Key | Values | Default | Notes |
|---|---|---|---|
| `RESPONSE_LANGUAGE` | 23 values (see below) | `english` | Appended as `--append-system-prompt "Always respond in …"` |
| `TEXT_DIRECTION` | `rtl` / `ltr` | `rtl` | Toggles Konsole `BidiEnabled` |
| `TERMINAL_COLOR` | `kivun` / `default` | `kivun` | Light-blue profile vs Konsole defaults |
| `KEYBOARD_TOGGLE` | `true` / `false` | `true` | Sets up Alt+Shift US ↔ primary-script layout via setxkbmap (X11 only) |
| `FOLDER_PICKER` | `true` / `false` | `false` | Pop a zenity/kdialog folder picker before launching |
| `CLAUDE_FLAGS` | — | empty | Extra flags passed to every `claude` call (e.g. `--continue`) |
| `KIVUN_BIDI_WRAPPER` | `on` / `off` | `on` | Pipe Claude through the BiDi wrapper for correct Hebrew/Arabic rendering |

Supported `RESPONSE_LANGUAGE` values: `english, hebrew, arabic, persian, urdu, kurdish, pashto, sindhi, yiddish, syriac, dhivehi, nko, adlam, mandaic, samaritan, dari, uyghur, balochi, kashmiri, shahmukhi, azeri-south, jawi, turoyo`.

Changes take effect on next launch — no reinstall needed.

## Uninstall

```bash
./linux/uninstall.sh
```

Removes the launcher, config, Konsole profile, desktop entries, and file-manager integrations. System packages (konsole, nodejs, git, claude) are **not** removed — do that yourself if desired.

## Keyboard switching on Wayland

`setxkbmap` only works on X11. On Wayland sessions (GNOME Wayland, KDE Plasma Wayland on recent versions), use your desktop environment's keyboard-settings panel to add a second layout and bind Alt+Shift as the toggle — the installer will log a warning and skip automatic layout setup in that case.

## Known limitations

- **Hebrew/Arabic first-line direction**: fixed in v1.1.0 by the bundled `kivun-claude-bidi` wrapper (default-on). The wrapper injects an RLM at line start when the first strong char is RTL, forcing paragraph direction. Disable with `KIVUN_BIDI_WRAPPER=off` if you need a clean copy-paste experience. Upstream tracking issue: [anthropics/claude-code#39881](https://github.com/anthropics/claude-code/issues/39881).
- **Wayland keyboard toggle**: `setxkbmap` is X11-only. See the section above.
- **Emoji font on older distros**: On Ubuntu < 22.04 or Fedora < 38, `fonts-noto-color-emoji` may not exist; install `noto-fonts-emoji` or similar manually.

## Build from source

There's no "build" step on Linux — `install.sh` copies files directly from `payload/` and `linux/` into `~/.local/`. If you want a distributable archive, tar up the repo:

```bash
tar -czf kivun-terminal-linux-$(cat VERSION).tar.gz \
    linux/ payload/ LICENSE VERSION
```

## CI build

`.github/workflows/build-linux.yml` runs `install.sh` against a clean Ubuntu runner on every tag push and uploads the resulting tarball as a workflow artifact + GitHub Release asset.
