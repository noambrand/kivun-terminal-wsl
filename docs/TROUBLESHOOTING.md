# Kivun Terminal v1.0.6 - Troubleshooting

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

**Cause:** The Claude Code CLI isn't installed inside Ubuntu (installer section failed or was skipped).

**Fix - inside Kivun Terminal or any WSL shell:**

```bash
curl -fsSL https://claude.ai/install.sh | bash
# or, if that fails:
sudo apt-get install -y nodejs npm
sudo npm install -g @anthropic-ai/claude-code
```

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
