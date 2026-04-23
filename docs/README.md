# Kivun Terminal v1.0.6

[![Version](https://img.shields.io/badge/version-1.0.6-brightgreen)](https://github.com/noambrand/kivun-terminal-wsl/releases/latest)
[![Platform](https://img.shields.io/badge/platform-Windows%2010%2F11-lightgrey)]()
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](../LICENSE)

**Claude Code on Windows with real RTL.** Kivun Terminal runs Claude Code inside a Linux Konsole (WSL2 + Ubuntu) so Hebrew, Arabic, Persian, Urdu and eight other RTL languages render correctly — something Windows Terminal cannot do.

> **Looking for a Windows-native launcher without WSL?** See the sister project [ClaudeCode Launchpad CLI](https://github.com/noambrand/kivun-terminal) — faster startup, but LTR only.

## How it's different from Launchpad CLI

| | Launchpad CLI v2.4.2 | Kivun Terminal v1.0.6 |
|---|---|---|
| **Runtime** | Windows Terminal (native) | WSL2 + Ubuntu + Konsole |
| **RTL/BiDi rendering** | Broken (Windows Terminal limitation) | Full support (Konsole BiDi engine) |
| **Supported RTL languages** | 0 | 11 (hebrew, arabic, persian, urdu, pashto, kurdish, dari, uyghur, sindhi, azerbaijani, +) |
| **Keyboard Alt+Shift toggle** | N/A | Yes (via optional VcXsrv) |
| **Startup time** | ~2 s | ~6 s (Konsole launch) |
| **Statusline** | Yes | No (planned v1.1) |
| **Install footprint** | ~150 MB | ~2 GB (WSL + Ubuntu) |

## Quick Start

1. **One-time WSL setup** (if you don't already have WSL2): open **Terminal (Admin)**, run `wsl --install`, reboot. Skip this step if `wsl --status` already prints WSL info.
2. **Download** `Kivun_Terminal_Setup.exe` from the [latest release](https://github.com/noambrand/kivun-terminal-wsl/releases/latest).
3. **Double-click** to run it — no admin rights needed. The wizard installs Ubuntu (if missing), Konsole, and Claude Code into your user profile.
4. Double-click the **Kivun Terminal** shortcut on your desktop, or right-click any folder → **Open with Kivun Terminal**.

The installer also has macOS (`.pkg`) and Linux (shell-script) variants — see `mac/README.md` and `linux/README.md`.

First run requires a Claude Pro/Max subscription or an [Anthropic API key](https://console.anthropic.com).

## Configuration

Edit `%LOCALAPPDATA%\Kivun-WSL\config.txt` to change:

- `RESPONSE_LANGUAGE` — language Claude responds in (default: `english`)
- `PRIMARY_LANGUAGE` — keyboard layout paired with `us` for Alt+Shift toggle (default: `hebrew`)
- `TEXT_DIRECTION` — `rtl` or `ltr` input alignment
- `USE_VCXSRV` — `true` to use VcXsrv X server (enables working Alt+Shift)
- `KIVUN_BIDI_WRAPPER` — `on` (the default) routes Claude Code output through the `kivun-claude-bidi` wrapper which injects explicit RLE/PDF bracket pairs around Hebrew runs. Set to `off` to fall back to unwrapped claude if the wrapper causes rendering issues on your setup.

See [README_INSTALLATION.md](README_INSTALLATION.md) for full setup details and [SECURITY.txt](SECURITY.txt) for credential notes.

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md). Common first checks:

- Logs: `%LOCALAPPDATA%\Kivun-WSL\LAUNCH_LOG.txt` (Windows side) and `BASH_LAUNCH_LOG.txt` (WSL side).
- `wsl --status` must show WSL2 default.
- `wsl -d Ubuntu -- command -v claude` must return a path.

## License

MIT — see [LICENSE](../LICENSE).
