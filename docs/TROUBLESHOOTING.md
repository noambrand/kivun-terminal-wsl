# Kivun Terminal v1.0.6 — Troubleshooting

## First: collect the logs

Every launch writes two log files:

- `%LOCALAPPDATA%\Kivun-WSL\LAUNCH_LOG.txt` — Windows batch launcher steps
- `%LOCALAPPDATA%\Kivun-WSL\BASH_LAUNCH_LOG.txt` — WSL-side bash launcher steps

Open both in Notepad. Scan from the bottom up for lines starting with `ERROR` or `WARNING`.

## Symptom: "WSL not found or not working"

**Cause:** WSL2 isn't enabled, or the Windows optional features aren't installed.

**Fix:**

```cmd
wsl --install
```

Reboot. Run the Kivun Terminal installer again — it will detect WSL is now present and continue.

## Symptom: "Ubuntu not available"

**Cause:** WSL is working but the Ubuntu distribution wasn't registered.

**Fix:**

```cmd
wsl --install -d Ubuntu
```

Wait for the one-time user setup to finish, set your Ubuntu username and password, then close and re-run Kivun Terminal.

## Symptom: "Claude Code: NOT FOUND"

**Cause:** The Claude Code CLI isn't installed inside Ubuntu (installer section failed or was skipped).

**Fix — inside Kivun Terminal or any WSL shell:**

```bash
curl -fsSL https://claude.ai/install.sh | bash
# or, if that fails:
sudo apt-get install -y nodejs npm
sudo npm install -g @anthropic-ai/claude-code
```

## Symptom: Konsole window never appears (WSLg mode)

The launcher log says Konsole started (a PID is reported, `wmctrl` / `xdotool` both "found" a window) but no window is visible on your desktop.

**Cause A — Qt runtime-dir security checks.** Konsole is a Qt app and Qt's `QStandardPaths` rejects `XDG_RUNTIME_DIR` in two cases:

1. The directory is not owned by the current UID.
2. The directory's permissions are not `0700`.

WSLg ships `/mnt/wslg/runtime-dir` owned by the first Linux user created (e.g. `noam` / UID 1000) with permissions `0777`. If the launcher runs as a different WSL user (e.g. `username` / UID 1001), both checks fail. Konsole launches but fails to locate its Wayland/D-Bus sockets, so the window never renders visibly — look for `QStandardPaths: runtime directory '...' is not owned by UID ...` or `wrong permissions ... 0777 instead of 0700` in `BASH_LAUNCH_LOG.txt`.

The launcher handles both now: it detects the WSLg runtime-dir owner and runs as that user (`wsl --user <owner>`), and tightens permissions to `0700` at startup. If you still hit this after an old install, force it manually:

```cmd
wsl -d Ubuntu --user root -- chmod 700 /mnt/wslg/runtime-dir
wsl -d Ubuntu --user root -- chown $(stat -c '%U' /mnt/wslg/runtime-dir) /mnt/wslg/runtime-dir
```

**Cause B — stale Konsole zombie.** A prior failed launch left a hidden Konsole process, and `xdotool search --class konsole` matches *that* stale window instead of the new one (telltale: the same window ID on every run). Kill it:

```cmd
wsl -d Ubuntu -- pkill -x konsole
```

The launcher now does this automatically on startup.

**Cause C — WSLg is actually missing** (older WSL builds) or the GPU pass-through isn't healthy.

```cmd
wsl --update
wsl --shutdown
```

**Fallback — fall back to text mode:** The launcher falls back to running Claude directly in the CMD window when Konsole won't start. You'll lose the blue background and BiDi rendering, but Claude will still work.

**Fallback — use VcXsrv instead of WSLg:**

1. Install VcXsrv from https://sourceforge.net/projects/vcxsrv/
2. Edit `%LOCALAPPDATA%\Kivun-WSL\config.txt`: set `USE_VCXSRV=true`
3. Re-launch.

## Symptom: Installer appears frozen on "Installing Konsole..." for 10+ minutes

**Cause:** The launcher was using `sudo apt-get ...` inside `wsl -d Ubuntu -- bash -c "..."`. When the Ubuntu user doesn't have passwordless sudo configured, sudo waits for a password with no TTY to read from — the install hangs forever.

Secondary cause: NSIS's `nsExec::ExecToLog` can deadlock when the child produces a lot of output (apt-get during a 300-500 MB Konsole download), because the output-capture pipe buffer fills up and blocks the child.

The installer now:

- Runs apt as root (`wsl -d Ubuntu -u root`) — no sudo, no password prompt.
- Redirects apt output into `/tmp/kivun-apt.log` and uses `nsExec::Exec` (no output capture) — no buffer deadlock.
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

**This is a known upstream limitation in Claude Code, not a Kivun bug.**

Claude Code prepends every assistant message with a `●` bullet character (defined in `cli.js`). Per Unicode BiDi rule UAX #9 P2, neutral characters like `●` should be skipped when detecting paragraph direction, but all tested terminal emulators (Konsole, GNOME Terminal, Windows Terminal) use the simpler "first visible character wins" approach and pick LTR — so the single first line of Claude's RTL-language reply renders left-aligned.

- Your own Hebrew **input** is right-aligned correctly ✓
- Claude's Hebrew response **lines 2+** (no bullet) are right-aligned correctly ✓
- Only Claude's response **line 1** (with the `●` bullet) renders LTR ✗

Workarounds we tried and why they don't work:

- Teaching Claude via system prompt to start responses with a blank / dash / header line: Claude ignores these on ~50% of replies.
- Patching `cli.js` to remove the bullet: works, but modifying a signed npm package triggers Windows SmartScreen and antivirus heuristics — can't ship in an installer.

Clean fix must come from Anthropic. **Tracked upstream at [anthropics/claude-code#39881](https://github.com/anthropics/claude-code/issues/39881)** — please 👍 that issue to help prioritize the fix. The technical BiDi analysis (root cause in `cli.js`, two proposed fixes including an RLM-prefix option that preserves the visual bullet while fixing BiDi) is posted as a comment: [#39881 (comment)](https://github.com/anthropics/claude-code/issues/39881#issuecomment-4281323284). Full internal analysis kept at `docs/FEATURE_REQUEST_ANTHROPIC.md`.

## Symptom: `KIVUN_BIDI_WRAPPER=on` but Hebrew still renders reversed

**Cause:** The BiDi wrapper (`kivun-claude-bidi`) is opt-in as of v1.1.0 and requires a one-time first-run install before it can be used. If something in that flow failed, the launcher falls back to unwrapped `claude` silently from the user's perspective — but the launch log records the reason.

**Diagnose:** open `%LOCALAPPDATA%\Kivun-WSL\BASH_LAUNCH_LOG.txt` and search for `BiDi` or `wrapper`. Three possible states:

1. `BiDi wrapper active: /home/<user>/.local/share/kivun-terminal/kivun-claude-bidi/bin/kivun-claude-bidi` — wrapper is running. If Hebrew still looks wrong, the issue is not the wrapper; see the Konsole BiDi engine section below.
2. `WARNING - Wrapper deploy failed` — `npm install` failed inside WSL. See the next symptom.
3. `INFO - BiDi wrapper off (KIVUN_BIDI_WRAPPER=off)` — the key isn't set to `on`. Edit `%LOCALAPPDATA%\Kivun-WSL\config.txt`, add or change the line:

   ```
   KIVUN_BIDI_WRAPPER=on
   ```

   If the key is missing entirely (upgrading from pre-v1.1.0 preserves your old `config.txt`), add it manually. Relaunch.

## Symptom: Wrapper deploy fails with "npm install failed"

**Cause:** `npm` or `node` isn't installed in your Ubuntu WSL distribution, or the version is too old for `node-pty`'s native build.

**Fix:**

```bash
wsl -d Ubuntu -u root -- apt-get update
wsl -d Ubuntu -u root -- apt-get install -y nodejs npm build-essential python3
```

Then relaunch Kivun Terminal. The first launch with the wrapper enabled will retry `npm install`. Expect 5–15 s the first time; subsequent launches are instant (an `.kivun-install-stamp` file in `~/.local/share/kivun-terminal/kivun-claude-bidi/node_modules/` gates re-installation).

If you want to force a reinstall after updating Node/npm:

```bash
wsl -d Ubuntu -- rm -rf ~/.local/share/kivun-terminal/kivun-claude-bidi/node_modules
```

Check the tail of `BASH_LAUNCH_LOG.txt` for the specific npm error message — common culprits are offline WSL, expired apt cache, or missing `build-essential`.

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

**Fix (permanent, trades RTL correctness for clean copy-paste):** set `KIVUN_BIDI_WRAPPER=off` in `config.txt`. Relies on Konsole's native BiDi engine alone — works for most output but can fail on profile drift or custom Konsole profiles.

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

If missing, delete the profile file and relaunch — the launcher regenerates it.

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

**Fix:** If you see stale files at `%LOCALAPPDATA%\Kivun\` from mixed installs, it's safe to delete — but only after confirming Launchpad CLI is not installed (check *Apps & Features*).

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
