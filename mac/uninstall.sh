#!/bin/bash
# Kivun Terminal — macOS uninstaller
# Removes files installed by the .pkg / postinstall. System-wide tooling
# (Homebrew, Node, Git, Claude Code itself) is left in place — remove it
# yourself if desired.
#
# Run as your normal user. The script uses sudo only when removing the
# /usr/local/share/kivun-terminal/ tree and the pkg receipt.

set -u

if [ "$(id -u)" -eq 0 ]; then
    echo "Run this as your normal user, not as root. sudo is requested internally." >&2
    exit 1
fi

log() { echo "[$(date '+%H:%M:%S')] $1"; }

log "=== Kivun Terminal macOS Uninstaller ==="
log "User: $USER | Home: $HOME"

removed=0
remove_if_exists() {
    if [ -e "$1" ]; then
        rm -rf "$1"
        log "Removed: $1"
        removed=$((removed + 1))
    fi
}

# --- User-owned files ---
remove_if_exists "$HOME/Desktop/Kivun Terminal.command"
remove_if_exists "$HOME/Library/Services/Open with Kivun Terminal.workflow"

# Config file — prompt, since user may have custom settings.
CONFIG_DIR="$HOME/Library/Application Support/Kivun-Terminal"
if [ -f "$CONFIG_DIR/config.txt" ]; then
    read -p "Remove config at $CONFIG_DIR/config.txt? [y/N] " ans
    case "$ans" in
        [yY]|[yY][eE][sS]) remove_if_exists "$CONFIG_DIR" ;;
        *) log "Keeping $CONFIG_DIR/config.txt" ;;
    esac
fi

# --- Shell rc CLAUDE_CODE_STATUSLINE export ---
# Match the export line we actually wrote ('^export CLAUDE_CODE_STATUSLINE=')
# to avoid deleting an unrelated mention.
for rc in "$HOME/.zshrc" "$HOME/.zprofile" "$HOME/.bashrc" "$HOME/.bash_profile"; do
    if [ -f "$rc" ] && grep -q "^export CLAUDE_CODE_STATUSLINE=" "$rc"; then
        # macOS sed needs '' after -i; BSD/GNU compatible via tmpfile.
        tmp=$(mktemp)
        grep -v '^# Kivun Terminal statusline$' "$rc" \
            | grep -v '^export CLAUDE_CODE_STATUSLINE=' > "$tmp"
        mv "$tmp" "$rc"
        log "Removed CLAUDE_CODE_STATUSLINE export from $rc"
        removed=$((removed + 1))
    fi
done

# --- Claude Code settings.json statusLine entry ---
# Only remove it if it points at our installed path. Leaves other
# statusline configs alone. We don't ship jq as a dep, so use Python
# (always present on macOS) for a safe JSON edit.
SETTINGS="$HOME/.claude/settings.json"
if [ -f "$SETTINGS" ]; then
    if python3 -c '
import json, sys
p = sys.argv[1]
with open(p) as f:
    data = json.load(f)
sl = data.get("statusLine", {})
cmd = sl.get("command", "") if isinstance(sl, dict) else ""
if "/usr/local/share/kivun-terminal/" in cmd or "kivun-terminal/statusline.mjs" in cmd:
    data.pop("statusLine", None)
    with open(p, "w") as f:
        json.dump(data, f, indent=2)
    print("removed")
' "$SETTINGS" 2>/dev/null | grep -q removed; then
        log "Removed Kivun statusLine entry from $SETTINGS"
        removed=$((removed + 1))
    fi
fi

# --- System-wide files (require sudo) ---
STATUSLINE_DIR="/usr/local/share/kivun-terminal"
if [ -d "$STATUSLINE_DIR" ]; then
    log "Removing $STATUSLINE_DIR (sudo required)..."
    sudo rm -rf "$STATUSLINE_DIR" && {
        log "Removed $STATUSLINE_DIR"
        removed=$((removed + 1))
    }
fi

# --- pkg receipt ---
if pkgutil --pkg-info com.kivun.terminal &>/dev/null; then
    log "Removing pkg receipt com.kivun.terminal (sudo required)..."
    sudo pkgutil --forget com.kivun.terminal && {
        log "pkg receipt removed"
        removed=$((removed + 1))
    }
fi

# --- Stale sudoers file (safety belt — should never exist, but just in case) ---
if [ -f /etc/sudoers.d/kivun-brew-temp ]; then
    log "WARNING: stale /etc/sudoers.d/kivun-brew-temp found from a crashed install"
    log "Removing (sudo required)..."
    sudo rm -f /etc/sudoers.d/kivun-brew-temp && log "Removed"
fi

log ""
log "Removed $removed item(s)."
log ""
log "NOT removed (remove manually if desired):"
log "  * Homebrew    — /opt/homebrew (Apple Silicon) or /usr/local/Homebrew (Intel)"
log "  * Node.js     — brew uninstall node"
log "  * Git         — brew uninstall git"
log "  * Claude Code — rm -f \$(which claude) or follow Anthropic's docs"
log ""
log "To reinstate the Finder right-click menu if you ever reinstall,"
log "log out and back in so Automator re-scans services."

exit 0
