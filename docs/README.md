# Kivun Terminal v1.1.7

[![Version](https://img.shields.io/badge/version-1.1.7-brightgreen)](https://github.com/noambrand/kivun-terminal-wsl/releases/latest)
[![Platform](https://img.shields.io/badge/platform-Windows%2010%2F11-lightgrey)]()
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](../LICENSE)

**Claude Code on Windows with real RTL.** Hebrew, Arabic, Persian, Urdu and 8 more right-to-left languages render correctly inside a Linux Konsole (WSL2 + Ubuntu) - something Windows Terminal cannot do.

---

## How to use

### Open Kivun Terminal

- **Desktop shortcut**: double-click **Kivun Terminal** on your desktop, **or**
- **From any folder**: right-click → **Open with Kivun Terminal** (opens that folder as Claude's working directory)

### First run

You'll need a **Claude Pro/Max subscription** or an [Anthropic API key](https://console.anthropic.com). The first launch walks you through login.

### Once Claude is open

- Hebrew / Arabic / etc. just work - type and read RTL normally.
- **Alt+Shift** toggles between Hebrew and English keyboard layouts (with VcXsrv on, which is the default).
- The small **launcher cmd window** that appears alongside Konsole can be safely closed - as of v1.1.7 it no longer takes the Konsole session down with it.
- The **statusline** at the bottom of every Claude session shows the active model, context %, and weekly/session usage limits.

### Where things live

- Logs (when something breaks): `%LOCALAPPDATA%\Kivun-WSL\LAUNCH_LOG.txt` (Windows side) and `BASH_LAUNCH_LOG.txt` (WSL side).
- Settings: `%LOCALAPPDATA%\Kivun-WSL\config.txt` (see below).

### Configuration

Edit `%LOCALAPPDATA%\Kivun-WSL\config.txt`:

| Setting | What it does | Default |
|---|---|---|
| `RESPONSE_LANGUAGE` | language Claude replies in | `english` |
| `PRIMARY_LANGUAGE` | keyboard layout paired with `us` for Alt+Shift | `hebrew` |
| `TEXT_DIRECTION` | `rtl` or `ltr` input alignment | `rtl` |
| `USE_VCXSRV` | `true` to use VcXsrv X server (needed for Alt+Shift on most setups) | `true` |
| `KIVUN_BIDI_WRAPPER` | `on` injects RLE/PDF brackets around Hebrew runs (the BiDi fix); `off` falls back to plain Claude | `on` |
| `KIVUN_BIDI_STRIP_BULLET` | `on` strips the leading `●` from Hebrew bullet lines (workaround for Konsole 23.x where the bullet anchors lines LTR); usually only needed on Ubuntu 24.04. See [TROUBLESHOOTING.md](TROUBLESHOOTING.md#symptom-hebrew-bullet-lines-render-with-the-bullet-on-the-left-instead-of-the-right) | `off` |

See [README_INSTALLATION.md](README_INSTALLATION.md) for full options and [TROUBLESHOOTING.md](TROUBLESHOOTING.md) when something breaks.

---

## Technical

### What's installed

- Ubuntu in WSL2 (if not already there)
- Konsole (KDE terminal emulator) inside Ubuntu
- Claude Code (via the official curl installer) inside Ubuntu
- The `kivun-claude-bidi` Node wrapper that brackets Hebrew runs with U+202B / U+202C and inserts a line-start RLM where Claude's output would otherwise render LTR
- Custom Konsole profile + color scheme (`KivunTerminal`, `ColorSchemeNoam`) - light-blue background, dark text
- Right-click Windows Explorer integration ("Open with Kivun Terminal")
- `python3-xlib` + `python3-pil` (used to set the Konsole window icon over VcXsrv)

### How it's different from the LTR sister project

| | Launchpad CLI v2.4.2 | Kivun Terminal v1.1.7 |
|---|---|---|
| **Runtime** | Windows Terminal (native) | WSL2 + Ubuntu + Konsole |
| **RTL/BiDi rendering** | LTR only | Full RTL + line-start RLM fix for Claude's bullet-line direction bug ([anthropics/claude-code#39881](https://github.com/anthropics/claude-code/issues/39881)) |
| **Supported RTL languages** | 0 | 11 (hebrew, arabic, persian, urdu, pashto, kurdish, dari, uyghur, sindhi, azerbaijani, +) |
| **Linux + macOS** | macOS only (Linux planned) | Linux (apt/dnf/pacman/zypper) + macOS (.pkg) |
| **Startup time** | ~2 s | ~6 s (Konsole launch) |
| **Statusline** | Yes | Yes (model, context %, session/weekly limits) |
| **Install footprint** | ~150 MB | ~2 GB (WSL + Ubuntu) |

> Looking for the LTR-only sister project? See [ClaudeCode Launchpad CLI](https://github.com/noambrand/kivun-terminal) - faster startup, no WSL needed.

### What's new in v1.1.7

- **Branded window icon** - the Konsole window shows the orange Claude figure instead of VcXsrv's default X. Done by writing `_NET_WM_ICON` directly via python-xlib after the window appears (Konsole doesn't set its own, and VcXsrv falls back to the X otherwise).
- **`setsid` detach** - closing the launcher cmd window no longer SIGHUPs Konsole; the live Claude session stays running.
- Inherits v1.1.6: active discovery of Claude in non-standard PATHs (nvm, pnpm, yarn-global, snap, corp installs) so the launcher doesn't reinstall on every launch.

### Common first checks (when something's wrong)

- `wsl --status` must show WSL2 default.
- `wsl -d Ubuntu -- command -v claude` must return a path.
- Logs: `%LOCALAPPDATA%\Kivun-WSL\LAUNCH_LOG.txt` and `BASH_LAUNCH_LOG.txt`.

Full troubleshooting in [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

### Contributor guides

- [HEBREW_RTL_GITHUB.md](HEBREW_RTL_GITHUB.md) - how to write Hebrew (or any RTL language) in this repo's README and docs without breaking GitHub's rendering.

---

## License

MIT - see [LICENSE](../LICENSE).
