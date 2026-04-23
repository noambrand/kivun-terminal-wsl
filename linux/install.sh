#!/bin/bash
# Kivun Terminal - Linux installer
# Usage: ./linux/install.sh
# Supports: Ubuntu/Debian (apt), Fedora/RHEL (dnf), Arch/Manjaro (pacman),
#           openSUSE (zypper).
#
# Installs: konsole, nodejs, git, Claude Code, emoji fonts, BiDi deps.
# Deploys : Konsole profile, statusline, config, desktop entry, launcher,
#           Nautilus + Dolphin right-click integration.

set -u
set -o pipefail
# pipefail is required because every package-install call is piped through
# `tee -a $LOG_FILE` - without pipefail, the pipeline returns tee's exit
# code (always 0) and `|| err "..."` error branches would never fire.

LOG_FILE="${KIVUN_LOG:-/tmp/kivun_install.log}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PAYLOAD_DIR="$(cd "$SCRIPT_DIR/../payload" 2>/dev/null && pwd || echo "$SCRIPT_DIR/../payload")"

log() { echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"; }
err() { echo "[$(date '+%H:%M:%S')] ERROR: $1" | tee -a "$LOG_FILE" >&2; }

log "=== Kivun Terminal Linux Installer ==="
log "User: $USER | Home: $HOME"
log "Distro: $(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-unknown}")"
log "Arch: $(uname -m)"

# Refuse to run as root - we need $HOME to be the user's real home so the
# Konsole profile and config files land in the right place. Use sudo only
# for the package-manager step (handled internally below).
if [ "$(id -u)" -eq 0 ]; then
    err "Do not run this installer as root. Run as your normal user; sudo will be requested for package installation."
    exit 1
fi

# --- Detect package manager ---
PKG_MGR=""
if command -v apt-get >/dev/null 2>&1; then PKG_MGR="apt"
elif command -v dnf >/dev/null 2>&1; then PKG_MGR="dnf"
elif command -v pacman >/dev/null 2>&1; then PKG_MGR="pacman"
elif command -v zypper >/dev/null 2>&1; then PKG_MGR="zypper"
else
    err "No supported package manager found (apt/dnf/pacman/zypper). Install konsole, nodejs, git manually and re-run."
    exit 1
fi
log "Package manager: $PKG_MGR"

# --- Prompt for sudo upfront so later calls don't keep asking ---
log "Requesting sudo for package installation..."
if ! sudo -v; then
    err "sudo failed. Cannot install system packages."
    exit 1
fi
# Keep sudo alive in the background while this script runs.
# Check parent-alive BEFORE sleeping so a script that exits in the first
# 60s doesn't leave a keepalive spinning for another ~60s. (SIGKILL of
# the parent is still uncatchable - the keepalive ends on the next wake.)
( while kill -0 "$$" 2>/dev/null; do sudo -n true; sleep 60; done ) 2>/dev/null &
SUDO_KEEPALIVE_PID=$!
trap 'kill $SUDO_KEEPALIVE_PID 2>/dev/null || true' EXIT

install_pkgs() {
    case "$PKG_MGR" in
        apt)
            sudo apt-get update -y 2>&1 | tee -a "$LOG_FILE"
            sudo apt-get install -y "$@" 2>&1 | tee -a "$LOG_FILE"
            ;;
        dnf)    sudo dnf install -y "$@"    2>&1 | tee -a "$LOG_FILE" ;;
        pacman) sudo pacman -Sy --noconfirm --needed "$@" 2>&1 | tee -a "$LOG_FILE" ;;
        zypper) sudo zypper --non-interactive install "$@" 2>&1 | tee -a "$LOG_FILE" ;;
    esac
}

# --- Konsole (primary terminal - best BiDi on Linux) ---
log "Checking Konsole..."
if command -v konsole >/dev/null 2>&1; then
    log "Konsole already installed: $(konsole --version 2>/dev/null | head -1)"
else
    log "Installing Konsole..."
    install_pkgs konsole || err "Konsole install failed - continuing anyway"
fi

# --- Git ---
log "Checking Git..."
if command -v git >/dev/null 2>&1; then
    log "Git already installed: $(git --version)"
else
    log "Installing Git..."
    install_pkgs git || err "Git install failed"
fi

# --- Node.js ---
log "Checking Node.js..."
if command -v node >/dev/null 2>&1; then
    log "Node.js already installed: $(node --version)"
else
    log "Installing Node.js..."
    case "$PKG_MGR" in
        apt)    install_pkgs nodejs npm ;;
        dnf)    install_pkgs nodejs npm ;;
        pacman) install_pkgs nodejs npm ;;
        zypper) install_pkgs nodejs npm ;;
    esac
fi

# --- Folder-picker helper (kdialog on KDE, zenity elsewhere) ---
# The launcher tries kdialog first, then zenity. Install whichever is
# native to the current DE - zenity pulls ~30MB of GTK on KDE systems
# for something kdialog already does natively. Our target audience
# (RTL users on Konsole) is mostly on KDE Plasma.
log "Installing folder-picker helper..."
PICKER_PKG=""
if command -v kdialog >/dev/null 2>&1 || command -v zenity >/dev/null 2>&1; then
    log "  folder-picker already installed - skipping"
elif [[ "${XDG_CURRENT_DESKTOP:-}" =~ (KDE|Plasma) ]]; then
    PICKER_PKG="kdialog"
else
    PICKER_PKG="zenity"
fi
if [ -n "$PICKER_PKG" ]; then
    log "  installing $PICKER_PKG (matches detected desktop: ${XDG_CURRENT_DESKTOP:-unknown})"
    install_pkgs "$PICKER_PKG" || true
fi

# --- Emoji font (prevents tofu squares for emoji in output) ---
log "Installing emoji font..."
case "$PKG_MGR" in
    apt)    install_pkgs fonts-noto-color-emoji || true ;;
    dnf)    install_pkgs google-noto-emoji-color-fonts || true ;;
    pacman) install_pkgs noto-fonts-emoji || true ;;
    zypper) install_pkgs noto-coloremoji-fonts || true ;;
esac

# --- Claude Code (via official installer) ---
# Download to a file *first*, then execute. A `curl | bash` pipeline
# starts executing bytes as they arrive, so a mid-download network drop
# can leave the system in a half-installed state. Downloading to a
# completed file lets us refuse execution if curl didn't finish cleanly.
log "Checking Claude Code..."
if command -v claude >/dev/null 2>&1; then
    log "Claude Code already installed: $(claude --version 2>/dev/null | head -1)"
else
    log "Installing Claude Code via Anthropic installer..."
    CLAUDE_INSTALL_SCRIPT=$(mktemp "${TMPDIR:-/tmp}/claude-install-XXXXXX.sh")
    if curl -fsSL -o "$CLAUDE_INSTALL_SCRIPT" https://claude.ai/install.sh 2>&1 | tee -a "$LOG_FILE" \
       && [ -s "$CLAUDE_INSTALL_SCRIPT" ]; then
        chmod +x "$CLAUDE_INSTALL_SCRIPT"
        if bash "$CLAUDE_INSTALL_SCRIPT" 2>&1 | tee -a "$LOG_FILE"; then
            log "Claude Code installed"
        else
            err "Claude Code installer ran but exited non-zero - install may be incomplete"
        fi
    else
        err "Failed to download Claude Code installer. Retry later with:  curl -fsSL https://claude.ai/install.sh -o /tmp/c.sh && bash /tmp/c.sh"
    fi
    rm -f "$CLAUDE_INSTALL_SCRIPT"
fi

# --- Deploy payload files ---
log "Deploying Kivun payload files..."
KT_SHARE="$HOME/.local/share/kivun-terminal"
KT_BIN="$HOME/.local/bin"
KT_CONFIG_DIR="$HOME/.config/kivun-terminal"
mkdir -p "$KT_SHARE" "$KT_BIN" "$KT_CONFIG_DIR"

if [ ! -d "$PAYLOAD_DIR" ]; then
    err "Payload directory not found: $PAYLOAD_DIR"
    err "Run this installer from the repository root so payload/ is a sibling of linux/"
    exit 1
fi

# statusline
if [ -f "$PAYLOAD_DIR/statusline.mjs" ]; then
    # Integrity check against the shipped SHA256. If the payload got
    # corrupted between build and here, we log and refuse to install the
    # bad file rather than silently ship something unexpected.
    if [ -f "$PAYLOAD_DIR/statusline.mjs.sha256" ]; then
        EXPECTED=$(awk '{print $1}' "$PAYLOAD_DIR/statusline.mjs.sha256")
        ACTUAL=$(sha256sum "$PAYLOAD_DIR/statusline.mjs" 2>/dev/null | awk '{print $1}')
        if [ -n "$EXPECTED" ] && [ "$EXPECTED" != "$ACTUAL" ]; then
            err "statusline.mjs SHA256 mismatch (expected $EXPECTED got $ACTUAL) - skipping install"
        else
            cp "$PAYLOAD_DIR/statusline.mjs" "$KT_SHARE/statusline.mjs"
            sed -i 's/\r$//' "$KT_SHARE/statusline.mjs" 2>/dev/null || true
            chmod 644 "$KT_SHARE/statusline.mjs"
            log "Statusline copied to $KT_SHARE/statusline.mjs (SHA256 verified)"
        fi
    else
        cp "$PAYLOAD_DIR/statusline.mjs" "$KT_SHARE/statusline.mjs"
        sed -i 's/\r$//' "$KT_SHARE/statusline.mjs" 2>/dev/null || true
        chmod 644 "$KT_SHARE/statusline.mjs"
        log "Statusline copied to $KT_SHARE/statusline.mjs (no SHA file shipped)"
    fi
fi

# languages.sh - shared prompt map sourced by the launcher
if [ -f "$PAYLOAD_DIR/languages.sh" ]; then
    cp "$PAYLOAD_DIR/languages.sh" "$KT_SHARE/languages.sh"
    sed -i 's/\r$//' "$KT_SHARE/languages.sh" 2>/dev/null || true
    chmod 644 "$KT_SHARE/languages.sh"
    log "Language map copied to $KT_SHARE/languages.sh"
fi

# configure-statusline.js helper (writes ~/.claude/settings.json)
if [ -f "$PAYLOAD_DIR/configure-statusline.js" ] && command -v node >/dev/null 2>&1; then
    node "$PAYLOAD_DIR/configure-statusline.js" "$KT_SHARE/statusline.mjs" 2>&1 | tee -a "$LOG_FILE" \
        && log "Statusline registered in ~/.claude/settings.json" \
        || err "configure-statusline.js failed"
fi

# --- BiDi wrapper (kivun-claude-bidi) ---
# Bundled the same way Windows does: ship the wrapper source under the
# user's local share dir and run `npm install --production` once at install
# time so first launch is instant. If npm or node is missing right now,
# we skip the install - the launcher's first-launch fallback will retry
# (see linux/kivun-launch.sh deploy_bidi_wrapper).
WRAPPER_SRC="$(cd "$SCRIPT_DIR/../kivun-claude-bidi" 2>/dev/null && pwd || echo "")"
WRAPPER_DST="$KT_SHARE/kivun-claude-bidi"
if [ -n "$WRAPPER_SRC" ] && [ -d "$WRAPPER_SRC" ]; then
    log "Deploying BiDi wrapper from $WRAPPER_SRC -> $WRAPPER_DST"
    # Nuke the wrapper subdir before extracting so files removed upstream
    # don't linger and get picked up by node's require() resolution. Scope
    # is the wrapper subdir only - never $KT_SHARE itself, which holds the
    # statusline, settings.json, languages.sh that we want to preserve.
    # node_modules goes too; npm install below rebuilds it from package.json.
    rm -rf "$WRAPPER_DST"
    mkdir -p "$WRAPPER_DST"
    # Excludes match the Windows installer's `File /r /x node_modules /x .git`.
    # node_modules will be (re)built by `npm install --production` below so we
    # don't ship a host-built copy that may be wrong-arch / wrong-libc.
    (cd "$WRAPPER_SRC" && tar --exclude=node_modules --exclude=.git -cf - .) \
        | (cd "$WRAPPER_DST" && tar xf -) 2>&1 | tee -a "$LOG_FILE"
    sed -i 's/\r$//' "$WRAPPER_DST/bin/kivun-claude-bidi" 2>/dev/null || true
    chmod +x "$WRAPPER_DST/bin/kivun-claude-bidi" 2>/dev/null || true

    if command -v npm >/dev/null 2>&1; then
        log "Running npm install --production for wrapper (one-time, ~5-15s)..."
        if (cd "$WRAPPER_DST" && npm install --production --no-audit --no-fund) 2>&1 | tee -a "$LOG_FILE"; then
            mkdir -p "$WRAPPER_DST/node_modules"
            touch "$WRAPPER_DST/node_modules/.kivun-install-stamp"
            log "BiDi wrapper installed at $WRAPPER_DST/bin/kivun-claude-bidi"
        else
            err "npm install failed for wrapper - first launch will retry"
        fi
    else
        log "npm not on PATH yet - skipping wrapper npm install (launcher will retry on first run)"
    fi
else
    log "WARNING: kivun-claude-bidi source not found at $SCRIPT_DIR/../kivun-claude-bidi - wrapper will not be available"
fi

# Linux-only settings file that the launcher passes via --settings
cat > "$KT_SHARE/settings.json" <<EOF
{
  "statusLine": {
    "type": "command",
    "command": "node \"$KT_SHARE/statusline.mjs\""
  },
  "outputStyle": "minimal",
  "transcriptVerbosity": "minimal",
  "showToolCalls": false,
  "showCommandOutput": false,
  "showCommand": false,
  "showCode": false
}
EOF
log "Wrote $KT_SHARE/settings.json"

# --- Launcher ---
LAUNCHER="$KT_BIN/kivun-terminal"
if [ -f "$SCRIPT_DIR/kivun-launch.sh" ]; then
    cp "$SCRIPT_DIR/kivun-launch.sh" "$LAUNCHER"
    chmod +x "$LAUNCHER"
    log "Launcher copied to $LAUNCHER"
else
    err "kivun-launch.sh not found in $SCRIPT_DIR"
    exit 1
fi

# Ensure $HOME/.local/bin is on PATH - add to shell rc if missing
SHELL_RC="$HOME/.bashrc"
[ -f "$HOME/.zshrc" ] && SHELL_RC="$HOME/.zshrc"
# Match the specific export line we write (or a close-enough variant),
# not just any comment/log mentioning .local/bin. Previously the grep
# matched fuzzy and skipped users who had never actually exported it.
PATH_EXPORT='export PATH="$HOME/.local/bin:$PATH"'
if ! echo ":$PATH:" | grep -q ":$HOME/.local/bin:"; then
    if ! grep -qF "$PATH_EXPORT" "$SHELL_RC" 2>/dev/null \
       && ! grep -qE '^[[:space:]]*export[[:space:]]+PATH=.*\$HOME/\.local/bin' "$SHELL_RC" 2>/dev/null; then
        {
            echo ''
            echo '# Kivun Terminal launcher path'
            echo "$PATH_EXPORT"
        } >> "$SHELL_RC"
        log "Added \$HOME/.local/bin to PATH in $SHELL_RC"
    fi
fi

# --- Config file ---
CONFIG_FILE="$KT_CONFIG_DIR/config.txt"
if [ -f "$CONFIG_FILE" ]; then
    log "Config already exists at $CONFIG_FILE - keeping user edits"
else
    cat > "$CONFIG_FILE" <<'CONFIG'
# Kivun Terminal Configuration (Linux)
# Schema is shared with Windows/macOS builds where applicable.

# =================================================================
# CLAUDE RESPONSE LANGUAGE
# =================================================================
# Options: english, hebrew, arabic, persian, urdu, kurdish, pashto,
# sindhi, yiddish, syriac, dhivehi, nko, adlam, mandaic, samaritan,
# dari, uyghur, balochi, kashmiri, shahmukhi, azeri-south, jawi,
# turoyo
# Default: english
RESPONSE_LANGUAGE=english

# =================================================================
# TEXT DIRECTION
# =================================================================
# rtl - Hebrew/Arabic input aligns to the right edge (Konsole BiDi on)
# ltr - default terminal behavior
# Default: rtl
TEXT_DIRECTION=rtl

# =================================================================
# TERMINAL COLOR THEME
# =================================================================
# kivun   - light-blue Kivun theme (Konsole profile + color scheme)
# default - keep your terminal's existing theme
# Default: kivun
TERMINAL_COLOR=kivun

# =================================================================
# KEYBOARD LAYOUT TOGGLE
# =================================================================
# When true, Alt+Shift toggles between your primary RTL language and
# US English inside the terminal. Uses setxkbmap; requires X11 (not
# Wayland). On Wayland, use your desktop environment's keyboard
# settings to set up layout switching.
# Default: true
KEYBOARD_TOGGLE=true

# =================================================================
# FOLDER PICKER ON LAUNCH
# =================================================================
# When true, a native file-manager folder picker pops before Konsole
# opens (zenity or kdialog, whichever is installed).
# Default: false (launch in $HOME)
FOLDER_PICKER=false

# =================================================================
# CLAUDE STARTUP FLAGS
# =================================================================
# Optional flags applied on every launch.
# Example: CLAUDE_FLAGS=--continue
CLAUDE_FLAGS=

# =================================================================
# BIDI WRAPPER (Hebrew rendering for Claude Code output)
# =================================================================
# When "on" (default), Claude Code output is piped through the
# kivun-claude-bidi wrapper, which injects Unicode RLE/PDF bracket
# pairs (U+202B / U+202C) around Hebrew runs and an RLM (U+200F) at
# line start when the first strong char is RTL - fixing the Hebrew
# bullet-line direction bug regardless of Konsole BiDi settings.
#
# The installer deploys the wrapper to
# ~/.local/share/kivun-terminal/kivun-claude-bidi/ and runs npm install
# once. If install was skipped (no npm at install time), the launcher
# retries on first launch. Set to "off" to fall back to unwrapped claude.
# Default: on
KIVUN_BIDI_WRAPPER=on
CONFIG
    log "Config created at $CONFIG_FILE"
fi

# --- Konsole profile + color scheme ---
KONSOLE_DIR="$HOME/.local/share/konsole"
mkdir -p "$KONSOLE_DIR"
cat > "$KONSOLE_DIR/KivunTerminal.profile" <<'PROF'
[Appearance]
ColorScheme=ColorSchemeNoam
Font=DejaVu Sans Mono,11,-1,5,50,0,0,0,0,0

[Cursor Options]
CursorShape=0
CustomCursorColor=0,80,200
UseCustomCursorColor=true

[General]
Name=Kivun Terminal
Parent=FALLBACK/
LocalTabTitleFormat=Kivun Terminal
RemoteTabTitleFormat=Kivun Terminal

[Scrolling]
HistorySize=10000
ScrollBarPosition=1

[Terminal Features]
BlinkingCursorEnabled=true
BidiEnabled=true
BidiLineLTR=false
PROF

cat > "$KONSOLE_DIR/ColorSchemeNoam.colorscheme" <<'CS'
[Background]
Color=200,230,255

[BackgroundFaint]
Color=200,230,255

[BackgroundIntense]
Color=200,230,255

[Color0]
Color=12,12,12

[Color0Faint]
Color=12,12,12

[Color0Intense]
Color=0,0,0

[Color1]
Color=197,15,31

[Color1Faint]
Color=197,15,31

[Color1Intense]
Color=255,19,40

[Color2]
Color=19,161,14

[Color2Faint]
Color=19,161,14

[Color2Intense]
Color=15,128,11

[Color3]
Color=193,156,0

[Color3Faint]
Color=193,156,0

[Color3Intense]
Color=171,138,0

[Color4]
Color=0,0,160

[Color4Faint]
Color=0,0,160

[Color4Intense]
Color=0,0,120

[Color5]
Color=136,23,152

[Color5Faint]
Color=136,23,152

[Color5Intense]
Color=105,18,117

[Color6]
Color=0,90,160

[Color6Faint]
Color=0,90,160

[Color6Intense]
Color=0,60,140

[Color7]
Color=204,204,204

[Color7Faint]
Color=204,204,204

[Color7Intense]
Color=94,94,94

[Foreground]
Color=12,12,12

[ForegroundFaint]
Color=12,12,12

[ForegroundIntense]
Color=12,12,12

[General]
Anchor=0.5,0.5
Blur=false
ColorRandomization=false
Description=Color Scheme Noam
FillStyle=Tile
Opacity=1
Wallpaper=
WallpaperFlipType=NoFlip
WallpaperOpacity=1

[Selection]
Color=50,255,241
CS
log "Konsole profile + color scheme deployed to $KONSOLE_DIR"

# --- Desktop entry (app menu) ---
APPS_DIR="$HOME/.local/share/applications"
mkdir -p "$APPS_DIR"
DESKTOP_FILE="$APPS_DIR/kivun-terminal.desktop"
if [ -f "$SCRIPT_DIR/kivun-terminal.desktop" ]; then
    # Uses sh -c "$HOME/..." at runtime so we don't need to expand install-
    # time paths here (survives users with spaces in their home path).
    cp "$SCRIPT_DIR/kivun-terminal.desktop" "$DESKTOP_FILE"
    chmod +x "$DESKTOP_FILE"
    log "Desktop entry installed at $DESKTOP_FILE"
fi

# Also drop a launchable copy on the desktop if $XDG_DESKTOP_DIR exists.
DESKTOP_DIR="$HOME/Desktop"
if command -v xdg-user-dir >/dev/null 2>&1; then
    _d=$(xdg-user-dir DESKTOP 2>/dev/null)
    [ -n "$_d" ] && DESKTOP_DIR="$_d"
fi
if [ -d "$DESKTOP_DIR" ] && [ -f "$DESKTOP_FILE" ]; then
    cp "$DESKTOP_FILE" "$DESKTOP_DIR/Kivun Terminal.desktop"
    chmod +x "$DESKTOP_DIR/Kivun Terminal.desktop"
    # Mark as trusted on GNOME (requires gio)
    if command -v gio >/dev/null 2>&1; then
        gio set "$DESKTOP_DIR/Kivun Terminal.desktop" metadata::trusted true 2>/dev/null || true
    fi
    log "Desktop launcher placed at $DESKTOP_DIR/Kivun Terminal.desktop"
fi

# Update the .desktop database so the app menu picks it up
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$APPS_DIR" 2>/dev/null || true
fi

# --- Nautilus (GNOME Files) right-click script ---
NAUTILUS_DIR="$HOME/.local/share/nautilus/scripts"
mkdir -p "$NAUTILUS_DIR"
if [ -f "$SCRIPT_DIR/nautilus-script" ]; then
    cp "$SCRIPT_DIR/nautilus-script" "$NAUTILUS_DIR/Open with Kivun Terminal"
    chmod +x "$NAUTILUS_DIR/Open with Kivun Terminal"
    log "Nautilus script installed at $NAUTILUS_DIR/Open with Kivun Terminal"
fi

# --- Dolphin (KDE Files) service menu ---
DOLPHIN_DIR="$HOME/.local/share/kio/servicemenus"
mkdir -p "$DOLPHIN_DIR"
if [ -f "$SCRIPT_DIR/dolphin-servicemenu.desktop" ]; then
    cp "$SCRIPT_DIR/dolphin-servicemenu.desktop" "$DOLPHIN_DIR/open-with-kivun-terminal.desktop"
    chmod +x "$DOLPHIN_DIR/open-with-kivun-terminal.desktop"
    log "Dolphin service menu installed at $DOLPHIN_DIR/open-with-kivun-terminal.desktop"
    # Rebuild KDE's service cache so the entry appears without a logout.
    # Name changed to kbuildsycoca6 in Plasma 6; try both.
    if command -v kbuildsycoca6 >/dev/null 2>&1; then
        kbuildsycoca6 2>/dev/null || true
    elif command -v kbuildsycoca5 >/dev/null 2>&1; then
        kbuildsycoca5 2>/dev/null || true
    fi
fi

# --- Summary ---
log ""
log "=== Installation Complete ==="
log "Node.js:  $(node --version 2>/dev/null || echo 'not installed')"
log "Git:      $(git --version 2>/dev/null || echo 'not installed')"
log "Claude:   $(claude --version 2>/dev/null | head -1 || echo 'not installed - run: curl -fsSL https://claude.ai/install.sh | bash')"
log "Konsole:  $(konsole --version 2>/dev/null | head -1 || echo 'not installed')"
log ""
log "To launch:"
log "  * App menu   : search for 'Kivun Terminal'"
log "  * Desktop    : double-click 'Kivun Terminal.desktop'"
log "  * Terminal   : kivun-terminal    (after restarting your shell, or: export PATH=\"\$HOME/.local/bin:\$PATH\")"
log "  * Right-click: in Nautilus → Scripts → Open with Kivun Terminal"
log "                 in Dolphin  → Open with Kivun Terminal"
log ""
log "Config:  $CONFIG_FILE"
log "Log:     $LOG_FILE"
log ""
log "Uninstall: ./linux/uninstall.sh"

exit 0
