# Kivun Terminal v1.1.26

[![Version](https://img.shields.io/badge/version-1.1.26-brightgreen)](https://github.com/noambrand/kivun-terminal-wsl/releases/latest)
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

| | Launchpad CLI v2.4.2 | Kivun Terminal v1.1.18 |
|---|---|---|
| **Runtime** | Windows Terminal (native) | WSL2 + Ubuntu + Konsole |
| **RTL/BiDi rendering** | LTR only | Full RTL + line-start RLM fix for Claude's bullet-line direction bug ([anthropics/claude-code#39881](https://github.com/anthropics/claude-code/issues/39881)) |
| **Supported RTL languages** | 0 | 11 (hebrew, arabic, persian, urdu, pashto, kurdish, dari, uyghur, sindhi, azerbaijani, +) |
| **Linux + macOS** | macOS only (Linux planned) | Linux (apt/dnf/pacman/zypper) + macOS (.pkg) |
| **Startup time** | ~2 s | ~6 s (Konsole launch) |
| **Statusline** | Yes | Yes (model, context %, session/weekly limits) |
| **Install footprint** | ~150 MB | ~2 GB (WSL + Ubuntu) |

> Looking for the LTR-only sister project? See [ClaudeCode Launchpad CLI](https://github.com/noambrand/kivun-terminal) - faster startup, no WSL needed.

### What's new in v1.1.23

- **Auto-install runs detached via setsid + a static script.** v1.1.21's `( ... ) & disown` returned 0 from wsl but the install never executed — WSL's interop relay kills its cgroup descendants when wsl.exe exits, and `& disown` only manages the bash job table, not cgroup membership. v1.1.23 ships `payload/kivun-install-claude.sh` and runs it via `wsl -d Ubuntu -- setsid -f bash <script>`. `setsid -f` forks AND creates a new session — the install becomes a session leader, fully orphaned from wsl.exe's session, so it survives wsl.exe's exit cleanly. Output → `/tmp/kivun-claude.log`, exit code → `/tmp/kivun-install-rc` (cmd polls every 5s for the marker file, cap 660s).
- Inherits v1.1.21 (detach + cmd-side poll architecture), v1.1.20 (no `tee` pipe), v1.1.19 (`timeout 600` bound), v1.1.18 (Konsole-install-fail-fallback bulletproofing — path conversion + WSLg-user detection now happen BEFORE the Konsole check).

### What's new in v1.1.18

- **Bulletproof Konsole-install-fail fallback.** When `apt-get install konsole` failed inside WSL (no GUI on a CI runner, flaky apt mirror, network outage, missing sudo cache), the launcher logged `Falling back to direct Claude execution` and `COMPLETE - Claude session ended`, but no Claude window actually appeared — the `goto :run_direct` jumped over the path-conversion and WSLg-user-detection blocks, leaving `WSL_PATH` / `INST_WSL` / `WSL_USER_FLAG` empty, so the fallback ran `wsl bash kivun-direct.sh` with no path prefix, bash couldn't find the script, and the wsl exit code wasn't checked. v1.1.18 reorders the .bat so all three variables are set before the Konsole check, so both the Konsole-launch path and the direct-fallback path work end-to-end. The new CI jobs in `validate-launcher-windows.yml` (PR #60) caught this and assert it stays fixed.
- Inherits v1.1.17 (`%USERPROFILE%` upstream substitution + WSLg taskbar icon via `.desktop` + `--name`), v1.1.16 (cursor-forward → literal-space replacement on RTL lines, USER-CONFIRMED), v1.1.11 (no per-run RLE/PDF on RTL lines), v1.1.10 (SGR color flatten on RTL lines), v1.1.9 (strip-incoming bidi controls + diagnostic side log), v1.1.8 (bullet-strip workaround for Konsole 23.x), v1.1.7 (branded Konsole window icon over VcXsrv + `setsid` detach), v1.1.6 (active Claude PATH discovery for nvm/pnpm/snap/corp installs).
- Test coverage: 87 injector unit fixtures + smoke test against fake-claude via node-pty, all green on Linux + macOS + Windows.

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
