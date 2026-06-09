# Kivun Terminal v1.4.19

[![Latest release](https://img.shields.io/github/v/release/noambrand/kivun-terminal-wsl?label=version&color=brightgreen)](https://github.com/noambrand/kivun-terminal-wsl/releases/latest)
[![Platform](https://img.shields.io/badge/platform-Windows%2010%2F11-lightgrey)]()
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](../LICENSE)

**Claude Code on Windows with real RTL.** Hebrew, Arabic, Persian, Urdu and 8 more right-to-left languages render correctly inside a Linux Konsole (WSL2 + Ubuntu) - something Windows Terminal cannot do.

---

## How to use

### Open Kivun Terminal

- **Desktop shortcut**: double-click **Kivun Terminal** on your desktop. A folder picker dialog opens with two clearly labeled options:
  - **Type or paste a Windows path** (e.g. `C:\Users\you\projects\my-app`) and click **Launch**.
  - **Browse Folder Tree** to pick a folder visually.
  - The dialog also has an **Edit Default Flags** button that opens `config.txt` so you can change Claude flags, response language, etc.
- **From any folder**: right-click → **Open with Kivun Terminal** (opens that folder directly, skipping the picker)

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
| `CLAUDE_FLAGS` | space-separated flags appended to every `claude` invocation (e.g. `--continue`, `--model opus`); see the full reference list inside `config.txt` | *(empty)* |
| `FOLDER_PICKER` | `true` shows the picker dialog from the desktop shortcut; `false` skips it and opens in `%USERPROFILE%` | `true` |
| `RESPONSE_LANGUAGE` | language Claude replies in | `english` |
| `PRIMARY_LANGUAGE` | keyboard layout paired with `us` for Alt+Shift | `hebrew` |
| `TEXT_DIRECTION` | `rtl` or `ltr` input alignment | `rtl` |
| `USE_VCXSRV` | `true` to use VcXsrv X server (needed for Alt+Shift on most setups) | `true` |
| `AUTO_INSTALL_CLAUDE` | `true` auto-installs Claude Code on first launch if missing | `true` |
| `KIVUN_BIDI_WRAPPER` | master switch for the wrapper (the BiDi fix); `off` falls back to plain Claude | `on` |
| `KIVUN_BIDI_STRIP_BULLET` | `on` strips the leading `●` from Hebrew bullet lines (workaround for Konsole 23.x where the bullet anchors lines LTR); usually only needed on Ubuntu 24.04 (v1.1.8+) | `on` |
| `KIVUN_BIDI_STRIP_INCOMING` | strips upstream-emitted bidi controls (`U+202A–U+202E`, `U+2066–U+2069`) from Claude's stream; preserves LRM/RLM. Modes: `off` / `auto` (count + log first detection) / `on` (count + log every chunk). v1.1.9+ | `auto` |
| `KIVUN_BIDI_FLATTEN_COLORS_RTL` | strips ANSI SGR (`\x1b[...m`) AND replaces cursor-forward CSI (`\x1b[NC`) with literal spaces on Hebrew lines. The combination is what makes `React`, `src/components/Button.tsx`, numbers, etc. land at their correct logical position inside Hebrew sentences. Trade-off: lose syntax color on Hebrew lines. v1.1.10 (SGR) + v1.1.16 (cursor-forward, **user-confirmed working** April 2026) | `on` |
| `KIVUN_BIDI_BRACKET_RTL_RUNS` | per-run RLE/PDF bracketing of Hebrew runs INSIDE RTL paragraphs. v1.1.11 default off because per-run brackets themselves split Konsole's BiDi run. Set to `on` if you want the legacy v1.1.0–v1.1.10 behavior | `off` |
| `KIVUN_BIDI_DUMP_RAW` | debug-only: capture every chunk Claude sends BEFORE the wrapper processes it, to `~/.local/state/kivun-terminal/bidi-raw-dump.bin`. Auto-rotates at 5 MiB. Useful for finding new invisible CSI splitters; see [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for the full debugging recipe | `off` |

See [README_INSTALLATION.md](README_INSTALLATION.md) for full options and [TROUBLESHOOTING.md](TROUBLESHOOTING.md) when something breaks.

---

## Technical

### What's installed

- Ubuntu in WSL2 (if not already there)
- Konsole (KDE terminal emulator) inside Ubuntu
- Claude Code (via the official curl installer) inside Ubuntu
- The `kivun-claude-bidi` Node wrapper that does seven complementary BiDi fixes: line-start RLM injection, conditional RLE/PDF bracketing (LTR paragraphs only), bullet-strip on Hebrew lines (Konsole 23.x workaround), upstream bidi-control strip, SGR-color flatten on RTL lines, no-per-run-bracket on RTL lines, and **CSI cursor-forward → literal-space replacement on RTL lines (v1.1.16, user-confirmed working April 2026)**. See the [README.md BiDi Wrapper section](https://github.com/noambrand/kivun-terminal-wsl#bidi-wrapper) for the full table of what each fix solves
- Custom Konsole profile + color scheme (`KivunTerminal`, `ColorSchemeNoam`) - light-blue background, dark text
- Right-click Windows Explorer integration ("Open with Kivun Terminal")
- `python3-xlib` + `python3-pil` (used to set the Konsole window icon over VcXsrv)

### How it's different from the LTR sister project

| | Launchpad CLI v2.6.5 | Kivun Terminal v1.4.19 |
|---|---|---|
| **Runtime** | Windows Terminal (native) | WSL2 + Ubuntu + Konsole |
| **RTL/BiDi rendering** | LTR only | Full RTL + line-start RLM fix for Claude's bullet-line direction bug ([anthropics/claude-code#39881](https://github.com/anthropics/claude-code/issues/39881)) |
| **Supported RTL languages** | 0 | 11 (hebrew, arabic, persian, urdu, pashto, kurdish, dari, uyghur, sindhi, azerbaijani, +) |
| **Linux + macOS** | macOS only (Linux planned) | Linux (apt/dnf/pacman/zypper). macOS deprecated as of v1.2.4 — see [`mac/README.md`](../mac/README.md). |
| **Startup time** | ~2 s | ~6 s (Konsole launch) |
| **Statusline** | Yes | Yes (model, context %, session/weekly limits) |
| **Install footprint** | ~150 MB | ~2 GB (WSL + Ubuntu) |

> Looking for the LTR-only sister project? See [ClaudeCode Launchpad CLI](https://github.com/noambrand/kivun-terminal) - faster startup, no WSL needed.

### What's new in v1.4.10

- **Statusline shows reasoning effort level (v1.4.10).** The bottom-of-session statusline now renders `effort:<level>` (low/medium/high/max) in magenta on line 1, right after the model name, whenever an effort override is active. Three resolution sources are tried in order: the JSON Claude Code pipes in (forward-compat for [Anthropic issue #40261](https://github.com/anthropics/claude-code/issues/40261)), `CLAUDE_CODE_EFFORT_LEVEL` env var, then `effortLevel` in `~/.claude/settings.json`. Hidden if nothing resolves. Three opt-in extras — session cost (`KIVUN_SL_COST=1`), cache tokens (`KIVUN_SL_CACHE=1`), and tokens/minute (`KIVUN_SL_TPM=1`) — stay off by default so the bar stays clean. See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for the env-var reference.
- **In-picker update check (v1.4.6+).** The folder picker now hits the GitHub Releases API on launch and shows a yellow *"🆕 Update available"* banner with a one-click `Download` button when newer than the installed `VERSION`. Errors (offline, GitHub down, antivirus) are swallowed silently — the banner just doesn't appear.
- **Collapsible Advanced section in the picker (v1.4.4+).** Model / flags / startup-cmds / env-vars now hide behind a single `Advanced options` toggle, so first-time users see only folder selection. Window opens at 690 px and grows to fit content when expanded.
- **Sticky `--continue` fix (v1.4.4+).** Picking *Continue last* in the picker no longer writes `--continue` into `config.txt`'s `CLAUDE_FLAGS` line; that bug used to crash right-click *Open with Kivun Terminal* launches on folders with no prior session ("No conversation found to continue").
- **HTA folder picker dialog (v1.3.0+).** The desktop shortcut now opens a single dialog with two clearly numbered options — type/paste a Windows path or browse the folder tree — plus an **Edit Default Flags** button that opens `config.txt`. Replaces the v1.2.5–v1.2.6 native `BrowseForFolder` dialog because users couldn't find where to type a path. Cancel still falls back silently to `%USERPROFILE%`.
- **`CLAUDE_FLAGS=` in `config.txt` (v1.2.7+).** Set default Claude flags applied to every launch (e.g. `CLAUDE_FLAGS=--model opus --continue`). The reference list at the bottom of `config.txt` enumerates ~25 supported flags from `claude --help`. No temp files involved — flags are passed straight from `kivun-terminal.bat` → `kivun-launch.sh` → the `claude` invocation.
- **Reorganized `config.txt` (v1.2.8+).** Quick settings (CLAUDE_FLAGS, FOLDER_PICKER, RESPONSE_LANGUAGE, PRIMARY_LANGUAGE) now appear at the top; display/install settings in the middle; BiDi wrapper tunables and the full 23-language reference list at the bottom. Optimised for the user who just wants to flip 1–2 settings and close the file.
- **No more duplicate Claude window (v1.2.6).** Removed the racy 13-second `pgrep -x konsole` polling that on slower machines spawned a SECOND Claude in the parent cmd window while Konsole eventually started its own. `kivun-terminal.bat` now spawns `kivun-launch.sh` async and exits cleanly; `BASH_LAUNCH_LOG.txt` is the source of truth for diagnostics.
- **Statusline renders both rows (v1.2.5).** Per-session settings file is now minimal `{statusLine: {type, command, lines: 2}}` — Claude Code 2.1.x needs the explicit `lines: N` key; `padding` is horizontal-only and won't reserve vertical space.
- Inherits all v1.1.x BiDi wrapper fixes: line-start RLM injection, conditional RLE/PDF bracketing, bullet-strip on Konsole 23.x, upstream bidi-control strip, SGR-color flatten on RTL lines, CSI cursor-forward → literal-space replacement (user-confirmed working).
- Test coverage: 87 injector unit fixtures + smoke test against fake-claude via node-pty, all green on Linux + Windows. (macOS test coverage deprecated alongside the platform in v1.2.4.)

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
