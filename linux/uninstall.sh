#!/bin/bash
# Kivun Terminal — Linux uninstaller
# Removes user-level files deployed by install.sh. System packages
# (konsole, nodejs, git, claude) are intentionally left installed;
# remove them yourself if desired.

set -u

log() { echo "[$(date '+%H:%M:%S')] $1"; }

log "=== Kivun Terminal Linux Uninstaller ==="

removed=0
remove_if_exists() {
    if [ -e "$1" ]; then
        rm -rf "$1"
        log "Removed: $1"
        removed=$((removed + 1))
    fi
}

# Payload
remove_if_exists "$HOME/.local/share/kivun-terminal"
remove_if_exists "$HOME/.local/bin/kivun-terminal"

# Config (ask first — user may have custom settings)
if [ -f "$HOME/.config/kivun-terminal/config.txt" ]; then
    read -p "Remove config file $HOME/.config/kivun-terminal/config.txt? [y/N] " ans
    case "$ans" in
        [yY]|[yY][eE][sS])
            remove_if_exists "$HOME/.config/kivun-terminal"
            ;;
        *) log "Keeping config at $HOME/.config/kivun-terminal/config.txt" ;;
    esac
fi

# Konsole profile (keep color scheme in case user likes it)
remove_if_exists "$HOME/.local/share/konsole/KivunTerminal.profile"
if [ -f "$HOME/.local/share/konsole/ColorSchemeNoam.colorscheme" ]; then
    read -p "Remove Konsole color scheme 'ColorSchemeNoam'? [y/N] " ans
    case "$ans" in
        [yY]|[yY][eE][sS]) remove_if_exists "$HOME/.local/share/konsole/ColorSchemeNoam.colorscheme" ;;
        *) log "Keeping ColorSchemeNoam.colorscheme" ;;
    esac
fi

# Desktop entries
remove_if_exists "$HOME/.local/share/applications/kivun-terminal.desktop"

DESKTOP_DIR="$HOME/Desktop"
if command -v xdg-user-dir >/dev/null 2>&1; then
    _d=$(xdg-user-dir DESKTOP 2>/dev/null)
    [ -n "$_d" ] && DESKTOP_DIR="$_d"
fi
remove_if_exists "$DESKTOP_DIR/Kivun Terminal.desktop"

# File-manager right-click integrations
remove_if_exists "$HOME/.local/share/nautilus/scripts/Open with Kivun Terminal"
remove_if_exists "$HOME/.local/share/kio/servicemenus/open-with-kivun-terminal.desktop"

# Cache (contains the generated launch script)
remove_if_exists "${XDG_CACHE_HOME:-$HOME/.cache}/kivun-terminal"
# Legacy /tmp path from pre-1.0.6 builds
remove_if_exists "/tmp/kivun-claude-launch-$(id -u).sh"

# Update desktop database
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
fi

log ""
log "Removed $removed item(s)."
log ""
log "System packages (konsole, nodejs, git, claude) were NOT removed."
log "To remove them:"
log "  claude:  rm -f \$(which claude)   # or follow Anthropic's uninstall steps"
log "  konsole: use your distro's package manager"
log ""
log "Claude Code user settings were NOT touched (~/.claude/)."
log "To remove the Kivun statusline entry, edit ~/.claude/settings.json."
