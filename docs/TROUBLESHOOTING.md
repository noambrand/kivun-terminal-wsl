# Kivun Terminal v1.1.27 - Troubleshooting

## First: collect the logs

Every launch writes two log files:

- `%LOCALAPPDATA%\Kivun-WSL\LAUNCH_LOG.txt` - Windows batch launcher steps
- `%LOCALAPPDATA%\Kivun-WSL\BASH_LAUNCH_LOG.txt` - WSL-side bash launcher steps

Open both in Notepad. Scan from the bottom up for lines starting with `ERROR` or `WARNING`.

## Symptom: "WSL not found or not working"

**Cause:** WSL2 isn't enabled, or the Windows optional features aren't installed.

**Fix:**

```cmd
wsl --install
```

Reboot. Run the Kivun Terminal installer again - it will detect WSL is now present and continue.

## Symptom: "Ubuntu not available"

**Cause:** WSL is working but the Ubuntu distribution wasn't registered.

**Fix:**

```cmd
wsl --install -d Ubuntu
```

Wait for the one-time user setup to finish, set your Ubuntu username and password, then close and re-run Kivun Terminal.

## Symptom: "Claude Code: NOT FOUND"

**Cause:** The Claude Code CLI isn't installed inside Ubuntu (installer section failed or was skipped). **Windows-side Claude Code does not help here** — Kivun Terminal runs Konsole through WSL and only sees the Ubuntu PATH.

**v1.1.1 and newer:** the launcher itself now offers to install Claude Code when it detects it's missing. Answer `Y` at the prompt and the launcher runs the official installer. Pre-v1.1.1 the launcher would claim to "fall back to direct Claude execution" and then crash with `bash: claude: command not found` — the fallback was a lie; fixed in v1.1.1.

**Manual fix (one-shot, matches what v1.1.1 does automatically):**

```cmd
wsl -d Ubuntu -u root -- bash -lc "curl -fsSL https://claude.ai/install.sh | bash"
```

If the curl installer fails (offline mirror, network block, etc.), fall back to the npm install:

```cmd
wsl -d Ubuntu -u root -- bash -lc "apt-get install -y nodejs npm && npm install -g @anthropic-ai/claude-code"
```

Note: `npm install -g @anthropic-ai/claude-code` is the deprecated path per Anthropic's current docs; the launcher and installer both prefer the curl script. The npm route is a fallback for environments where the curl script can't reach `claude.ai`.

After install, verify: `wsl -d Ubuntu -- claude --version`. Then relaunch Kivun Terminal.

## Symptom: Konsole window never appears (WSLg mode)

The launcher log says Konsole started (a PID is reported, `wmctrl` / `xdotool` both "found" a window) but no window is visible on your desktop.

**Cause A - Qt runtime-dir security checks.** Konsole is a Qt app and Qt's `QStandardPaths` rejects `XDG_RUNTIME_DIR` in two cases:

1. The directory is not owned by the current UID.
2. The directory's permissions are not `0700`.

WSLg ships `/mnt/wslg/runtime-dir` owned by the first Linux user created (e.g. `noam` / UID 1000) with permissions `0777`. If the launcher runs as a different WSL user (e.g. `username` / UID 1001), both checks fail. Konsole launches but fails to locate its Wayland/D-Bus sockets, so the window never renders visibly - look for `QStandardPaths: runtime directory '...' is not owned by UID ...` or `wrong permissions ... 0777 instead of 0700` in `BASH_LAUNCH_LOG.txt`.

The launcher handles both now: it detects the WSLg runtime-dir owner and runs as that user (`wsl --user <owner>`), and tightens permissions to `0700` at startup. If you still hit this after an old install, force it manually:

```cmd
wsl -d Ubuntu --user root -- chmod 700 /mnt/wslg/runtime-dir
wsl -d Ubuntu --user root -- chown $(stat -c '%U' /mnt/wslg/runtime-dir) /mnt/wslg/runtime-dir
```

**Cause B - stale Konsole zombie.** A prior failed launch left a hidden Konsole process, and `xdotool search --class konsole` matches *that* stale window instead of the new one (telltale: the same window ID on every run). Kill it:

```cmd
wsl -d Ubuntu -- pkill -x konsole
```

The launcher now does this automatically on startup.

**Cause C - WSLg is actually missing** (older WSL builds) or the GPU pass-through isn't healthy.

```cmd
wsl --update
wsl --shutdown
```

**Fallback - fall back to text mode:** The launcher falls back to running Claude directly in the CMD window when Konsole won't start. You'll lose the blue background and BiDi rendering, but Claude will still work.

**Fallback - use VcXsrv instead of WSLg:**

1. Install VcXsrv from https://sourceforge.net/projects/vcxsrv/
2. Edit `%LOCALAPPDATA%\Kivun-WSL\config.txt`: set `USE_VCXSRV=true`
3. Re-launch.

## Symptom: Installer appears frozen on "Installing Konsole..." for 10+ minutes

**Cause:** The launcher was using `sudo apt-get ...` inside `wsl -d Ubuntu -- bash -c "..."`. When the Ubuntu user doesn't have passwordless sudo configured, sudo waits for a password with no TTY to read from - the install hangs forever.

Secondary cause: NSIS's `nsExec::ExecToLog` can deadlock when the child produces a lot of output (apt-get during a 300-500 MB Konsole download), because the output-capture pipe buffer fills up and blocks the child.

The installer now:

- Runs apt as root (`wsl -d Ubuntu -u root`) - no sudo, no password prompt.
- Redirects apt output into `/tmp/kivun-apt.log` and uses `nsExec::Exec` (no output capture) - no buffer deadlock.
- Splits the install into 6 small steps so Cancel stays usable between steps.

If you still hit it after old builds, kill the stuck job and the installer:

```cmd
wsl -d Ubuntu --user root -- pkill -9 -f apt-get
```

Then re-run the installer.

## Symptom: Launcher batch exits silently mid-run / shortcut seems to do nothing

If `LAUNCH_LOG.txt` shows the script reaching a certain point and then stopping (no `ERROR`, just truncated), the most common cause is **CRLF line endings lost in transit**. CMD batch files require CRLF. Files edited on Linux/WSL or copied via `cp` from WSL will often end up with LF-only, and CMD's parser silently fails in complex nested `if (...)` / `for (...)` blocks.

**Fix:** Convert to DOS line endings:

```cmd
wsl -d Ubuntu -- unix2dos "/mnt/c/Users/%USERNAME%/AppData/Local/Kivun-WSL/kivun-terminal.bat"
```

`kivun-launch.sh` must stay LF (it's a Unix shell script). `kivun-terminal.bat` must be CRLF.

## Symptom: "Permission denied" on `/tmp/kivun-claude-launch.sh`

**Cause:** A prior launch (as a different WSL user) created the temp script with its ownership. Your current user can't overwrite it.

The launcher now uses a per-UID path (`/tmp/kivun-claude-launch-<uid>.sh`) so this collision can't happen. For old installs, clean up manually:

```cmd
wsl -d Ubuntu --user root -- rm -f /tmp/kivun-claude-launch.sh
```

## Symptom: Claude's Hebrew/Arabic response is left-aligned on the first line

**Fixed in v1.1.0 on all three platforms** (Windows/WSL, Linux, macOS) when the BiDi wrapper is enabled (which is the default). If you're on v1.0.6 or have `KIVUN_BIDI_WRAPPER=off`, the bug is still there.

Per-platform launch log paths (search for `BiDi wrapper active` to confirm the wrapper is running):

- **Windows**: `%LOCALAPPDATA%\Kivun-WSL\BASH_LAUNCH_LOG.txt`
- **Linux**: `~/.local/share/kivun-terminal/launch.log`
- **macOS**: the `.command` shortcut prints to its own Terminal.app window; postinstall log lives at `/tmp/kivun_install.log`.

Root cause: Claude Code prepends every assistant message with a `●` bullet character. Konsole's BiDi auto-detect uses "first strong char wins" paragraph-direction detection, but empirically (see `docs/research/paragraph-direction-test.sh`) it only honors the first strong char if it appears **before any other visible char**. The `●` is a visible neutral, so Konsole falls back to LTR direction despite the Hebrew that follows.

How v1.1.0 fixes it: the wrapper injects a zero-width RLM (U+200F, strong-R) at position 0 of every line whose first strong char is RTL. That means the line always starts with strong-R from Konsole's perspective, paragraph direction becomes RTL, and the Hebrew (including the bullet line) renders right-aligned. English-first lines don't get RLM so Latin content stays LTR.

**If you see the bug in v1.1.0:**
1. Check `BASH_LAUNCH_LOG.txt`. You should see `SUCCESS - BiDi wrapper active`. If instead you see `BiDi wrapper off`, edit `%LOCALAPPDATA%\Kivun-WSL\config.txt`, set `KIVUN_BIDI_WRAPPER=on`, relaunch.
2. If log shows wrapper active but bullet line is still LTR, it's a new bug - please file an issue with a screenshot and your Konsole version (`wsl -d Ubuntu -- konsole --version`).

Upstream tracker (relevant if you want Anthropic to fix this at the source): [anthropics/claude-code#39881](https://github.com/anthropics/claude-code/issues/39881).

## Symptom: Hebrew bullet lines render with the bullet on the LEFT instead of the RIGHT

You have `KIVUN_BIDI_WRAPPER=on`, the launch log confirms the wrapper is active, the Hebrew text itself is shaped right-to-left correctly - but lines that start with `● ` followed by Hebrew anchor the bullet to the left edge of the line, with the Hebrew flowing leftward from there. You expected the bullet on the right edge with Hebrew flowing right-to-left into it.

**Cause:** Konsole 23.08 (the default in Ubuntu 24.04) classifies the `●` (U+25CF BLACK CIRCLE) as a *direction-anchoring neutral*. Once it appears at column 0, Konsole locks the line's paragraph direction to LTR and a line-start RLM (U+200F) is no longer enough to flip it - the RLM is treated as a weaker hint than the bullet's anchoring effect. Konsole 24.04 reportedly relaxes this and treats the bullet as a regular neutral (so the line-start RLM fix from v1.1.0 takes effect normally) - if you're on KDE Plasma 6 / Konsole 24.04+ you most likely don't need this workaround.

**Fix:** enable the opt-in bullet-strip workaround. Edit your platform's config:

- **Windows:** `%LOCALAPPDATA%\Kivun-WSL\config.txt`
- **Linux:** `~/.config/kivun-terminal/config.txt`
- **macOS:** `~/Library/Application Support/Kivun-Terminal/config.txt`

Set:

```ini
KIVUN_BIDI_STRIP_BULLET=on
```

Restart Kivun Terminal. The wrapper will now strip the leading `●` from any line whose first strong char is RTL before passing it to the terminal. Hebrew becomes the first visible char on the line, BiDi flips paragraph direction to RTL automatically, and the line renders right-aligned the way you'd expect.

**Trade-off:** the visible `●` marker disappears on Hebrew bullet lines (the indentation stays, so you still see lines as visually grouped). English bullet lines are not touched - their `●` continues to render normally. If you'd rather keep the bullet visible at the cost of the LTR layout on Konsole 23.x, leave `KIVUN_BIDI_STRIP_BULLET=off` (the default).

## Symptom: Konsole window opens with no icon (blank/white) in title bar and Windows taskbar

**Fixed in v1.1.17.** The v1.1.16 docs incorrectly called this a WSLg architectural limit — it isn't. WSLg DOES set the Windows taskbar icon, just via a different mechanism than X11's `_NET_WM_ICON`.

**How WSLg picks the taskbar icon:** WSLg matches a window's `WM_CLASS` (X11) or `app_id` (Wayland) against installed `.desktop` files' `StartupWMClass=` entry. The matched `.desktop`'s `Icon=` becomes the Windows taskbar icon. Konsole's default `WM_CLASS` is `konsole`, which matches `/usr/share/applications/org.kde.konsole.desktop` → its bundled icon → not ours.

**v1.1.17 fix in `kivun-launch.sh`:**
1. Generates `~/.local/share/applications/kivun-terminal.desktop` with `Icon=<absolute path to kivun-icon.png>` and `StartupWMClass=kivun-terminal`.
2. Launches Konsole as `konsole --name kivun-terminal ...` so its `WM_CLASS` becomes `kivun-terminal` (Qt's `--name` arg sets `WM_CLASS` res_name).
3. WSLg now matches the launched window to our `.desktop` and uses our icon.

**Why this didn't get caught earlier:** the v1.1.7 `python-xlib` path *did* set `_NET_WM_ICON` correctly, and the launcher's log line `SUCCESS - Window icon set` made it look like the icon was applied. Under VcXsrv (the original deployment target) it WAS applied — VcXsrv reads `_NET_WM_ICON`. Under WSLg (the v1.1+ default), the property is set but unused. The `.desktop` registration is the WSLg-native path that actually drives the Windows taskbar.

**The `_NET_WM_ICON` path still runs as a fallback** for users on `USE_VCXSRV=true` (VcXsrv reads it). The two paths complement each other — `.desktop` for WSLg, `_NET_WM_ICON` for VcXsrv. The cmd "Launch Log" window keeps its own icon from the Desktop shortcut's `kivun_icon.ico`.

## Symptom: launcher worked then suddenly behaves like half the .bat is missing — wrong working directory, no early log lines, missing config

**Cause (v1.1.16 updater regression, fixed in v1.1.17):** `Kivun-Update-To-V1116.bat` downloaded `kivun-terminal.bat` from GitHub raw via `curl -fsSL`, which preserves the repository's LF line endings. **cmd silently skips lines on LF-only `.bat` files** — many statements never execute, including the `WORK_DIR` setup. The launcher then falls through to the v1.1.16 path-conversion fallback and lands users at `~` (WSL home `/home/<user>`) instead of `%USERPROFILE%` (their Windows home `/mnt/c/Users/<user>`).

**Diagnosis pattern:** if `LAUNCH_LOG.txt` shows the header (`KIVUN TERMINAL v1.1.16 LAUNCH LOG`, Date, Working Directory) followed directly by `[hh:mm:ss] SUCCESS - python deps installed` — skipping ALL the early `START - Launching`, `INFO - Using default work directory`, `SUCCESS - Config loaded`, `INFO - Checking WSL installation` lines that should appear in between — the .bat has LF-only line endings and cmd is racing through it dropping commands.

**v1.1.17 fix:**
- The new updater (`Kivun-Update-To-V1117.bat`) explicitly normalizes the downloaded `.bat` to CRLF after `curl`, via `tr -d '\r' | sed 's/$/\r/'` inside WSL.
- Bonus belt-and-suspenders fix in `kivun-terminal.bat` itself: when `WORK_DIR` is empty or `.`, substitute `%USERPROFILE%` upstream so `wslpath` converts a real Windows path → `/mnt/c/Users/<user>` instead of cascading through the `~` (WSL home) fallback. So even if you somehow end up with an invalid WORK_DIR, the launcher lands in the Windows home — matching what the Desktop shortcut promises.

**Manual recovery (without re-running an updater):**

```cmd
wsl -d Ubuntu --user root -- bash -c "tr -d '\r' < /mnt/c/Users/<your-user>/AppData/Local/Kivun-WSL/kivun-terminal.bat | sed 's/\$/\r/' > /tmp/k.bat && mv /tmp/k.bat /mnt/c/Users/<your-user>/AppData/Local/Kivun-WSL/kivun-terminal.bat"
```

Or just download the v1.1.17 installer fresh from the [releases page](https://github.com/noambrand/kivun-terminal-wsl/releases/latest) — the NSIS installer always ships proper CRLF.

## Symptom: Working directory is `/mnt/c/Users/<you>/AppData/Local/Kivun-WSL` (the install dir) instead of your home or the right-clicked folder

**Cause (verified April 27, 2026 in WSL 2.6.3.0):** `wslpath ""` and `wslpath "."` both return the literal `.` string. The pre-v1.1.16 `kivun-terminal.bat` only checked for empty WSL_PATH; a `.` value slipped through, got passed to bash, and `cd .` kept whatever cwd bash inherited from cmd — typically the install dir when launched from the Desktop shortcut.

**v1.1.16 partial fix:** added `WSL_PATH=.` check, fell back to `~` (WSL home `/home/<user>`). User feedback: this was wrong direction — the Desktop shortcut implies `%USERPROFILE%` (the Windows home), not the WSL home.

**v1.1.17 correct fix:** when `WORK_DIR` is empty or `.`, substitute `%USERPROFILE%` upfront so `wslpath` converts a real Windows path → `/mnt/c/Users/<you>`. Belt-and-suspenders second `wslpath` call on the result if it still came back empty/`.`. So launching the Desktop shortcut now lands you at `/mnt/c/Users/<you>` (your Windows home), matching what the shortcut implies.

**Manual fix on v1.1.16 and earlier:** download the v1.1.17 installer or the v1.1.17 updater bat — both ship the corrected logic. Hand-editing this case is brittle because the v1.1.16 fallback still resolves to `~` and you have to fix it BEFORE wslpath is called.

## Symptom: Konsole opens, then Claude immediately exits with `--dangerously-skip-permissions cannot be used with root/sudo privileges`

**Cause:** Your WSL Ubuntu's default user is `root` (or WSLg's runtime-dir is owned by root, which usually means the same thing). Kivun detects the WSLg owner and runs as that user — when that user is `root`, Claude Code refuses to start because of its `--dangerously-skip-permissions` security guard. The launcher path you'll see in the error is `/root/.local/share/kivun-terminal/kivun-claude-bidi/...` — the `/root/` prefix confirms the diagnosis.

**Fixed in v1.1.14:** the launcher now auto-detects this case, looks up the first non-root user (UID 1000), and uses that user instead. If no non-root user exists, the launcher aborts before ever reaching Claude with copy-paste instructions for creating one.

**Manual fix on v1.1.13 and earlier** (or if v1.1.14's auto-detect doesn't find a UID-1000 user):

```cmd
wsl -d Ubuntu --user root -- adduser yourname
wsl -d Ubuntu --user root -- usermod -aG sudo yourname
ubuntu config --default-user yourname
wsl --terminate Ubuntu
```

Then re-launch Kivun Terminal.

If `ubuntu config` doesn't exist (older Ubuntu image), use:

```cmd
wsl -d Ubuntu --user root -- bash -c "echo -e '[user]\ndefault=yourname' >> /etc/wsl.conf"
wsl --terminate Ubuntu
```

## Symptom: Hebrew lines render right-aligned BUT English/code/numbers land at the wrong column inside Hebrew sentences

**E.g.** `אני משתמש ב-React כדי לרנדר את הקומפוננטות` renders with "React" stuck at the visual left edge instead of mid-sentence between `ב-` and `כדי`.

**Cause (USER-CONFIRMED via DUMP_RAW capture, April 2026):** Claude Code's TUI emits **CSI cursor-forward escapes (`\x1b[1C`) instead of literal space characters between every word.** Konsole's BiDi engine treats each invisible cursor-forward as an attribute-region boundary the same way it treats SGR color changes — splitting the BiDi run between every word, so each word fragment gets BiDi-resolved independently and Qt mispositions LTR fragments to the visual left edge.

**Fix shipped in v1.1.13:** the wrapper now intercepts CSI cursor-forwards on RTL lines and replaces each `\x1b[NC` with N literal space characters. Visually identical (cursor-forward moves over presumed-blank cells; spaces write to those same cells), but no attribute-region boundary so the entire RTL line is one BiDi run. Gated on the existing `KIVUN_BIDI_FLATTEN_COLORS_RTL=on` flag (default on).

**If you're still seeing it on v1.1.13+:** verify the wrapper deployed correctly — `grep cursorForwardReplacedCount ~/.local/share/kivun-terminal/kivun-claude-bidi/lib/injector.js` should print at least one match. If not, re-run the installer or use `Kivun-Update-To-V1113.bat` to pull the latest wrapper from `main`.

## Symptom: Hebrew rendering looks broken in a NEW way that doesn't match any symptom above

**General debugging recipe** (the one we used to find the v1.1.13 cursor-forward bug):

1. **Turn on raw stream capture.** Edit `%LOCALAPPDATA%\Kivun-WSL\config.txt` (Linux: `~/.config/kivun-terminal/config.txt`, macOS: `~/Library/Application Support/Kivun-Terminal/config.txt`) and set `KIVUN_BIDI_DUMP_RAW=on`. Save. Close + reopen Kivun.
2. **Reproduce the rendering bug.** Send Claude one prompt that triggers it. Close Kivun.
3. **Inspect the dump.** The wrapper has captured every byte Claude emitted to:
   ```
   ~/.local/state/kivun-terminal/bidi-raw-dump.bin
   ```
4. **Look for invisible CSI sequences acting as attribute-region boundaries.** Visible escapes (colors via `\x1b[...m`, cursor positioning via `\x1b[...H`, etc.) are obvious. The killers are sequences that LOOK like text in the dump but are actually escapes:
   - `\x1b[NC` — cursor-forward (was the v1.1.13 culprit)
   - `\x1b[ND` — cursor-back
   - `\x1b[NA` / `\x1b[NB` — cursor up / down
   - `\x1b[?Nh` / `\x1b[?Nl` — set / reset terminal modes
   - `\x1b]...\x1b\\` — OSC sequences (window title, hyperlinks, etc.)
5. **Quick frequency count via Python:**
   ```bash
   python3 -c "
   import re, collections
   data = open('/path/to/bidi-raw-dump.bin', 'rb').read()
   finals = collections.Counter(m.group(1) for m in re.finditer(rb'\x1b\[[\x30-\x3f]*[\x20-\x2f]*([\x40-\x7e])', data))
   for byte, count in finals.most_common(10):
       print(f'  CSI ending in {chr(byte[0])!r:8} ({byte.hex()}): {count} occurrences')
   "
   ```
6. **Whichever final byte has hundreds of occurrences inside the Hebrew text** is your suspect splitter. Pin its replacement in `kivun-claude-bidi/lib/injector.js` the same way v1.1.13 pinned cursor-forward.
7. **Turn off DUMP_RAW after diagnostic** to avoid filling disk: flip `KIVUN_BIDI_DUMP_RAW=on` back to `=off` in `config.txt`. (Auto-rotation at 5 MiB caps total use, but cleaner is off when not actively investigating.)

The pattern: when the wrapper-rendered output looks wrong even though all *visible* escapes are stripped, look for *invisible* CSI sequences that act as attribute-region boundaries. The DUMP_RAW side log makes them visible.

## Symptom: `KIVUN_BIDI_WRAPPER=on` but Hebrew still renders reversed

**Cause:** The BiDi wrapper (`kivun-claude-bidi`) is default-on as of v1.1.0 but requires a one-time first-run `npm install` before it can be used. If something in that flow failed, the launcher falls back to unwrapped `claude` silently from the user's perspective - but the launch log records the reason.

**Diagnose:** open the per-platform launch log (see paths in the previous symptom) and search for `BiDi` or `wrapper`. Three possible states:

1. `BiDi wrapper active: <path>/kivun-claude-bidi/bin/kivun-claude-bidi` - wrapper is running. If Hebrew still looks wrong, the issue is not the wrapper; see the BiDi engine section below.
2. `WARNING - Wrapper deploy failed` / `npm install failed` - see the next symptom.
3. `BiDi wrapper off` - the key isn't set to `on`. Edit your config and set `KIVUN_BIDI_WRAPPER=on`. Config paths:
   - **Windows:** `%LOCALAPPDATA%\Kivun-WSL\config.txt`
   - **Linux:** `~/.config/kivun-terminal/config.txt`
   - **macOS:** `~/Library/Application Support/Kivun-Terminal/config.txt`

   If the key is missing entirely (upgrading from pre-v1.1.0 preserves your old `config.txt`), add it manually. Relaunch.

## Symptom: Wrapper deploy fails with "npm install failed"

**Cause:** `npm` or `node` isn't installed (or the version is too old for `node-pty`'s native build), or the build toolchain (`build-essential`/Xcode CLT) is missing.

**Fix - Windows (WSL Ubuntu):**

```bash
wsl -d Ubuntu -u root -- apt-get update
wsl -d Ubuntu -u root -- apt-get install -y nodejs npm build-essential python3
```

**Fix - Linux:**

```bash
# Debian/Ubuntu
sudo apt-get install -y nodejs npm build-essential python3
# Fedora/RHEL
sudo dnf install -y nodejs npm gcc-c++ make python3
# Arch
sudo pacman -S --needed nodejs npm base-devel python
```

**Fix - macOS:**

```bash
brew install node
xcode-select --install   # if Xcode CLT isn't present (provides the C++ toolchain node-pty needs)
```

Then relaunch. On first launch with the wrapper enabled, `npm install` retries automatically. Expect 5–15 s the first time; subsequent launches are instant (an `.kivun-install-stamp` file in `<wrapper-dir>/node_modules/` gates re-installation).

If you want to force a reinstall after updating Node/npm, delete `node_modules` from the platform-specific wrapper directory:

- **Windows:** `wsl -d Ubuntu -- rm -rf ~/.local/share/kivun-terminal/kivun-claude-bidi/node_modules`
- **Linux:** `rm -rf ~/.local/share/kivun-terminal/kivun-claude-bidi/node_modules`
- **macOS:** `rm -rf /usr/local/share/kivun-terminal/kivun-claude-bidi/node_modules` (the postinstall chowns the wrapper subtree to your user, so no sudo needed)

Check the tail of the launch log for the specific npm error message - common culprits are offline networks, missing build toolchains, or a Node version too old for `node-pty`.

## Symptom: Pasted text from Konsole contains invisible characters that break shell commands

**Cause:** When `KIVUN_BIDI_WRAPPER=on`, the wrapper injects zero-width RLE (U+202B) and PDF (U+202C) direction marks around Hebrew runs in Claude's output. Most modern terminals hide them on copy, but some tools see them as literal bytes and your `paste` target may render them as boxes, `‫` / `‬`, or choke on them in parsing.

**Fix (one-off):** strip them at the receiving end:

```bash
tr -d '‫‬' < pasted.txt > clean.txt
```

Or pipe directly:

```bash
pbpaste | tr -d '‫‬'   # macOS
xclip -selection clipboard -o | tr -d '‫‬'   # Linux
```

**Fix (permanent, trades RTL correctness for clean copy-paste):** set `KIVUN_BIDI_WRAPPER=off` in `config.txt`. Relies on Konsole's native BiDi engine alone - works for most output but can fail on profile drift or custom Konsole profiles.

## Symptom: Hebrew/Arabic letters render left-to-right or look garbled

**Cause:** Konsole's BiDi engine is disabled or the installed Konsole is too old.

**Fix:**

```bash
wsl -d Ubuntu -- konsole --version
```

Require Konsole 22.04 or newer. If older:

```bash
wsl -d Ubuntu -- sudo apt-get update
wsl -d Ubuntu -- sudo apt-get install --only-upgrade konsole
```

Also verify the profile file contains `BidiEnabled=true`:

```bash
wsl -d Ubuntu -- grep -i bidi ~/.local/share/konsole/KivunTerminal.profile
```

If missing, delete the profile file and relaunch - the launcher regenerates it.

## Symptom: Alt+Shift doesn't switch keyboard layout

**Cause:** WSLg does not propagate Alt+Shift to the X server. This is a known WSLg limitation.

**Fix:** Enable VcXsrv mode. Edit `config.txt`:

```
USE_VCXSRV=true
```

Install VcXsrv if you haven't. Relaunch.

## Symptom: The window doesn't maximize

**Cause:** `wmctrl` or `xdotool` missing inside Ubuntu.

**Fix:**

```bash
wsl -d Ubuntu -- sudo apt-get install -y wmctrl xdotool
```

## Symptom: "Installation path conversion failed" in the log

**Cause:** The installer directory contains characters that `wslpath` can't translate (usually non-ASCII chars in your Windows username).

**Fix:** Reinstall to an ASCII-only path, e.g. `C:\Kivun-WSL`. Override the install dir on the *Directory* wizard page.

## Symptom: Conflicts with ClaudeCode Launchpad CLI

**Cause:** Both products used `%LOCALAPPDATA%\Kivun` in earlier versions. Kivun Terminal v1.0.6 uses `%LOCALAPPDATA%\Kivun-WSL` specifically to avoid this.

**Fix:** If you see stale files at `%LOCALAPPDATA%\Kivun\` from mixed installs, it's safe to delete - but only after confirming Launchpad CLI is not installed (check *Apps & Features*).

## Still stuck?

Open an issue at https://github.com/noambrand/kivun-terminal-wsl/issues with:

1. Both log files (redact any sensitive paths).
2. Output of:
   ```cmd
   wsl --version
   wsl --status
   wsl -l -v
   ```
3. Your `config.txt` contents (it's not sensitive).
