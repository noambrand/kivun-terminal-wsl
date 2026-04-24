# Kivun Terminal - macOS Quickstart

A macOS `.pkg` installer that bundles Claude Code with a Kivun-themed Terminal.app configuration and an Automator right-click entry in Finder.

## What the installer does

1. Installs Xcode Command Line Tools (if missing).
2. Installs Homebrew (if missing) - in `.pkg` non-TTY context, uses a self-cleaning temporary passwordless-sudo entry for the install only.
3. Installs Node.js, Git, and Claude Code CLI (each skipped if already present).
4. Copies `statusline.mjs` to `/usr/local/share/kivun-terminal/statusline.mjs` and registers it in Claude Code's `~/.claude/settings.json`.
5. Creates a config file at `~/Library/Application Support/Kivun-Terminal/config.txt` with 23-language and MAC_TERMINAL preferences.
6. Deploys the **`kivun-claude-bidi` wrapper** to `/usr/local/share/kivun-terminal/kivun-claude-bidi/` and runs `npm install --production` once during postinstall (as the real user, so `node-pty` builds against your actual arch - Intel vs Apple Silicon). The desktop launcher pipes Claude through this wrapper to fix the Hebrew bullet-line direction bug. Default-on; disable via `KIVUN_BIDI_WRAPPER=off` in config.
7. Creates a desktop launcher `~/Desktop/Kivun Terminal.command` that pops a Finder folder picker, applies the light-blue Kivun color theme to Terminal.app via AppleScript, and launches the wrapper (or plain `claude`) in the chosen folder.
8. Installs a Finder Quick Action at `~/Library/Services/Open with Kivun Terminal.workflow` so you can right-click any folder → Services → "Open with Kivun Terminal".

## Install

Download `Kivun_Terminal_Setup_mac.pkg` from the latest GitHub release and double-click it. macOS will ask for your admin password; that's normal (the installer needs to install Homebrew and Claude Code system-wide).

Install log lives at `/tmp/kivun_install.log` - check there if something goes wrong.

## Config file

`~/Library/Application Support/Kivun-Terminal/config.txt`:

- `RESPONSE_LANGUAGE` - one of 23 values (english, hebrew, arabic, persian, urdu, kurdish, pashto, sindhi, yiddish, syriac, dhivehi, nko, adlam, mandaic, samaritan, dari, uyghur, balochi, kashmiri, shahmukhi, azeri-south, jawi, turoyo)
- `MAC_TERMINAL` - `terminal` (default), `iterm2`, or `wezterm`. Terminal.app has weaker BiDi than Konsole; install iTerm2 or WezTerm and set this to match for better RTL rendering.
- `TERMINAL_COLOR` - `kivun` (light-blue theme applied via osascript) or `default`
- `TEXT_DIRECTION` - `rtl` or `ltr`
- `FOLDER_PICKER` - `true` (default on macOS; shortcut pops a folder picker) or `false`
- `CLAUDE_FLAGS` - optional flags passed to every `claude` invocation (e.g. `--continue`)
- `KIVUN_BIDI_WRAPPER` - `on` (default) / `off`. Pipe Claude through the BiDi wrapper for correct Hebrew/Arabic rendering.

## Build from source

Requires macOS with Xcode Command Line Tools.

```bash
chmod +x mac/build.sh
./mac/build.sh            # uses version from VERSION file
./mac/build.sh 1.0.6      # explicit version
```

Output: `build/Kivun_Terminal_Setup_mac.pkg`.

## Uninstall

```bash
sudo /usr/local/share/kivun-terminal/uninstall.sh
```

Or from the source repo:

```bash
./mac/uninstall.sh
```

Removes the desktop shortcut, the Finder Quick Action, the shell-rc `CLAUDE_CODE_STATUSLINE` export, the Kivun statusLine entry from `~/.claude/settings.json`, the `/usr/local/share/kivun-terminal/` tree, and the `com.kivun.terminal` pkg receipt. Prompts before removing the config file. Leaves Homebrew, Node, Git, and Claude Code in place - remove those yourself if desired.

## CI build

`.github/workflows/build-mac.yml` builds the `.pkg` on `macos-latest` on every tag push (`v*`) and on manual workflow dispatch. It uploads the `.pkg` as a workflow artifact, and on tag push also attaches it to the GitHub Release.

## Known limitations

- **Hebrew RTL first line** - fixed in v1.1.0 by the bundled `kivun-claude-bidi` wrapper (default-on), which injects an RLM at line start when the first strong char is RTL. iTerm2 and WezTerm still have stronger native BiDi than Terminal.app, so switching via `MAC_TERMINAL` is recommended for heavy RTL workflows. Upstream tracking issue: [anthropics/claude-code#39881](https://github.com/anthropics/claude-code/issues/39881).
- **Code-signing / notarization** - the `.pkg` is currently unsigned. macOS Gatekeeper will warn on first launch; right-click → Open to bypass. A signed+notarized build is planned for v1.1.
- **Intel vs Apple Silicon** - the postinstall auto-detects `uname -m` and installs Homebrew at `/opt/homebrew` (arm64) or `/usr/local/Homebrew` (x86_64).
