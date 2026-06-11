#!/bin/bash
# Kivun Terminal - Bash Launcher (WSL side)
# Handles Konsole profile, colors, RTL/BiDi, title, maximize.
# Called by kivun-terminal.bat with:
#   bash kivun-launch.sh <wsl_path> <claude_prompt> <primary_language> <use_vcxsrv> <log_file> <text_dir> [primary_monitor]
#
# primary_monitor format: "X Y W H" (Windows primary-monitor bounds, passed
# in from the Windows launcher via PowerShell). When provided, Konsole is
# sized/positioned to fit that monitor instead of spanning all displays.

WSL_PATH="${1:-~}"
CLAUDE_PROMPT="$2"
PRIMARY_LANG="${3:-hebrew}"
USE_VCXSRV="${4:-false}"
LOG_FILE="${5:-/tmp/kivun-bash-launch.log}"
TEXT_DIR="${6:-rtl}"
PRIMARY_MON="${7:-}"
# v1.2.7: extra Claude flags from config.txt CLAUDE_FLAGS=. Empty by
# default; users edit config.txt to set --continue / --model opus / etc.
# Passed unquoted to claude so the shell word-splits "--a --b" into two
# args. Not embedded in CLAUDE_PROMPT — that's the system prompt text.
CLAUDE_FLAGS="${8:-}"
STARTUP_CMDS_FILE="${9:-}"

# v1.1.5: read product version from the VERSION file the .bat ships next
# to this script. Single source of truth -- previously the bash log
# header had a hardcoded "v1.0.6" string that drifted four releases out
# of date and caused a user to ask "is this really 1.0.6?". $0 may be
# absolute (when the .bat invokes us with "%INST_WSL%kivun-launch.sh")
# or via PATH; resolve it before reading the sibling VERSION file.
SCRIPT_DIR_FOR_VERSION="$(cd "$(dirname "$0")" 2>/dev/null && pwd || echo /tmp)"
PRODUCT_VERSION="unknown"
if [ -r "$SCRIPT_DIR_FOR_VERSION/VERSION" ]; then
    PRODUCT_VERSION="$(tr -d '\r\n' < "$SCRIPT_DIR_FOR_VERSION/VERSION")"
fi

mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null

{
    echo "========================================"
    echo "KIVUN BASH LAUNCHER LOG (v$PRODUCT_VERSION)"
    echo "========================================"
    echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "User: $USER"
    echo "Working Directory: $(pwd)"
    echo "Log File: $LOG_FILE"
    echo "========================================"
    echo ""
} >> "$LOG_FILE"

log() {
    echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "START - Bash launcher started (Kivun Terminal v$PRODUCT_VERSION)"
log "INFO - Parameters received:"
log "  WSL_PATH=$WSL_PATH"
log "  PRIMARY_LANG=$PRIMARY_LANG"
log "  USE_VCXSRV=$USE_VCXSRV"
log "  LOG_FILE=$LOG_FILE"
log "  TEXT_DIR=$TEXT_DIR"

# v1.1.14: defense-in-depth root-user guard. The Windows .bat already
# tries to find a non-root user when WSLg is root-owned, but if some
# upstream WSL/distro change defeats that detection (or someone runs
# this script directly via `wsl --user root -- bash kivun-launch.sh`),
# we still need to refuse cleanly. Claude Code refuses to start with
# --dangerously-skip-permissions when running as root, and the user
# sees a cryptic "Claude exited with code 1" without context.
if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    log "ERROR - Running as root (EUID=0). Claude Code refuses to start as root."
    {
        echo ""
        echo "============================================================"
        echo " ERROR: Kivun launcher is running as root."
        echo "============================================================"
        echo " Claude Code refuses --dangerously-skip-permissions when"
        echo " running as root for security reasons."
        echo ""
        echo " Fix: create a non-root user in Ubuntu and set it as the"
        echo " default. From Windows cmd or PowerShell:"
        echo ""
        echo "   wsl -d Ubuntu --user root -- adduser yourname"
        echo "   wsl -d Ubuntu --user root -- usermod -aG sudo yourname"
        echo "   ubuntu config --default-user yourname"
        echo "   wsl --terminate Ubuntu"
        echo ""
        echo " Then re-launch Kivun Terminal."
        echo "============================================================"
    }
    exit 1
fi

MY_UID="$(id -u)"
# NOTE: we intentionally do NOT kill the user's existing Konsole windows.
# Earlier versions ran `pkill -x -u $MY_UID konsole` here to clear zombie
# windows left by failed launches — but it also closed LIVE sessions, so
# opening a second project silently killed the first. We now keep existing
# windows and, when one is open, add a new TAB to it instead (see the launch
# branch further below). Stale-window confusion is avoided by matching the
# specific WM_CLASS `kivun-terminal` and activating the existing window.

log "INFO - Checking XDG_RUNTIME_DIR for WSLg sockets"
# WSLg puts its Wayland/D-Bus/PulseAudio sockets in /mnt/wslg/runtime-dir.
# That dir is world-writable (777) so any user can use it, even if owned
# by a different UID. Previously we replaced it with /tmp/runtime-$UID
# whenever we weren't the owner, which broke Konsole's display discovery.
# Now we only fall back to /tmp if the WSLg dir is missing OR unwritable.
WSLG_DIR="/mnt/wslg/runtime-dir"
if [ -d "$WSLG_DIR" ] && [ -w "$WSLG_DIR" ] && [ -S "$WSLG_DIR/wayland-0" ]; then
  export XDG_RUNTIME_DIR="$WSLG_DIR"
  # Qt's QStandardPaths rejects XDG_RUNTIME_DIR unless perms are 0700.
  # WSLg ships it as 0777. If we're the owner, tighten it — otherwise
  # Konsole (a Qt app) fails to locate its display/D-Bus sockets and
  # the window never renders visibly.
  if [ -O "$WSLG_DIR" ]; then
    chmod 700 "$WSLG_DIR" 2>/dev/null && log "INFO - Tightened WSLg dir perms to 0700 for Qt"
  fi
  log "SUCCESS - Using WSLg runtime dir: $XDG_RUNTIME_DIR"
else
  export XDG_RUNTIME_DIR="/tmp/runtime-$(id -u)"
  mkdir -p "$XDG_RUNTIME_DIR"
  chmod 700 "$XDG_RUNTIME_DIR"
  log "WARNING - WSLg runtime dir unavailable, using fallback: $XDG_RUNTIME_DIR"
fi

# Ensure DISPLAY / WAYLAND_DISPLAY are set (they should already be, but
# some shells drop them when the launcher is invoked via 'wsl bash' from
# Windows, where the environment is partially sanitized).
[ -z "$DISPLAY" ] && export DISPLAY=":0"
[ -z "$WAYLAND_DISPLAY" ] && export WAYLAND_DISPLAY="wayland-0"
log "INFO - Display env: DISPLAY=$DISPLAY, WAYLAND_DISPLAY=$WAYLAND_DISPLAY"

# --- Managed per-user D-Bus session bus -----------------------------------
# WSLg does not provide a D-Bus *session* bus, but `konsole --new-tab` needs
# one so a fresh launch can find an already-open Kivun window and add a tab to
# it instead of opening a separate window. dbus-daemon ships with Ubuntu, so we
# run a tiny reusable session bus ourselves and persist its address — every
# launch is a separate `wsl` invocation, so they must rendezvous on a known
# socket. Best-effort: if the bus can't start we just fall back to windows.
KIVUN_BUS_SOCK="$XDG_RUNTIME_DIR/kivun-bus"
KIVUN_BUS_ADDR_FILE="$XDG_RUNTIME_DIR/kivun-dbus-address"
kivun_bus_alive() {
    # $1 = dbus address; succeeds only if it names a live unix socket.
    case "$1" in
        unix:path=*) ;;
        *) return 1 ;;
    esac
    local p="${1#unix:path=}"; p="${p%%,*}"
    [ -S "$p" ]
}
if [ -f "$KIVUN_BUS_ADDR_FILE" ]; then
    DBUS_SESSION_BUS_ADDRESS="$(cat "$KIVUN_BUS_ADDR_FILE" 2>/dev/null)"
fi
if kivun_bus_alive "$DBUS_SESSION_BUS_ADDRESS"; then
    log "INFO - Reusing managed D-Bus session bus: $DBUS_SESSION_BUS_ADDRESS"
elif command -v dbus-daemon >/dev/null 2>&1; then
    rm -f "$KIVUN_BUS_SOCK" 2>/dev/null
    setsid dbus-daemon --session \
        --address="unix:path=$KIVUN_BUS_SOCK" \
        --nofork --nopidfile >/dev/null 2>&1 &
    DBUS_SESSION_BUS_ADDRESS="unix:path=$KIVUN_BUS_SOCK"
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        kivun_bus_alive "$DBUS_SESSION_BUS_ADDRESS" && break
        sleep 0.2
    done
    if kivun_bus_alive "$DBUS_SESSION_BUS_ADDRESS"; then
        echo "$DBUS_SESSION_BUS_ADDRESS" > "$KIVUN_BUS_ADDR_FILE"
        log "INFO - Started managed D-Bus session bus: $DBUS_SESSION_BUS_ADDRESS"
    else
        log "WARNING - Managed D-Bus session bus did not come up; tabs disabled this launch"
        DBUS_SESSION_BUS_ADDRESS=""
    fi
else
    log "WARNING - dbus-daemon not found; cannot share a window (tabs disabled)"
    DBUS_SESSION_BUS_ADDRESS=""
fi
[ -n "$DBUS_SESSION_BUS_ADDRESS" ] && export DBUS_SESSION_BUS_ADDRESS

log "INFO - Setting up keyboard layout for $PRIMARY_LANG"
# Map RESPONSE_LANGUAGE → xkb layout code. Languages without a real
# xkb layout fall back to "il" (Hebrew) — they share RTL semantics and
# most users of those scripts already know Hebrew keyboards.
case "$PRIMARY_LANG" in
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
  dhivehi)     KBD_PRIMARY="il" ;;  # no xkb; RTL fallback
  nko)         KBD_PRIMARY="ml" ;;  # Niger-area fallback
  adlam)       KBD_PRIMARY="ml" ;;  # Fulani, Niger/Sahel
  mandaic)     KBD_PRIMARY="il" ;;  # no xkb; RTL fallback
  samaritan)   KBD_PRIMARY="il" ;;  # Samaritan Hebrew
  dari)        KBD_PRIMARY="af" ;;
  uyghur)      KBD_PRIMARY="cn" ;;
  balochi)     KBD_PRIMARY="pk" ;;
  kashmiri)    KBD_PRIMARY="in" ;;
  shahmukhi)   KBD_PRIMARY="pk" ;;
  azeri-south) KBD_PRIMARY="ir" ;;  # Southern Azeri uses Persian script
  jawi)        KBD_PRIMARY="my" ;;
  turoyo)      KBD_PRIMARY="sy" ;;
  azerbaijani) KBD_PRIMARY="az" ;;  # legacy key from older config
  *)           KBD_PRIMARY="il" ;;
esac
log "SUCCESS - Keyboard layout mapped to: $KBD_PRIMARY"

# --- Keyboard: US English + the primary RTL script as two xkb groups, with
# Alt+Shift to toggle. Open in whatever language the user is CURRENTLY using
# instead of always forcing the RTL script: WSLg forwards the active Windows
# keyboard layout into the X server, so `setxkbmap -query` (read BEFORE we
# override anything) tells us what they're on, and we put that layout first.
# Defined as a function so it runs once now AND again once the Konsole window
# exists — the early apply can be dropped by WSLg before the window grabs
# focus, which was the "stuck on Hebrew, first Alt+Shift does nothing"
# symptom. Detection is best-effort; on anything unexpected we open
# English-first so the terminal is immediately ready for commands and paths.
KIVUN_KBD_LAYOUTS=""
apply_kivun_keyboard() {
    command -v setxkbmap >/dev/null 2>&1 || return 0
    if [ "$KBD_PRIMARY" = "us" ]; then
        setxkbmap -layout us 2>/dev/null || true   # English: nothing to toggle
        return 0
    fi
    if [ -z "$KIVUN_KBD_LAYOUTS" ]; then
        _kb_cur=$(setxkbmap -query 2>/dev/null | sed -n 's/^layout:[[:space:]]*//p' | cut -d, -f1)
        case "$_kb_cur" in
            "$KBD_PRIMARY") KIVUN_KBD_LAYOUTS="${KBD_PRIMARY},us" ;;
            *)              KIVUN_KBD_LAYOUTS="us,${KBD_PRIMARY}" ;;
        esac
        log "INFO - Keyboard: current='${_kb_cur:-unknown}' -> '${KIVUN_KBD_LAYOUTS}' (Alt+Shift toggles)"
    fi
    setxkbmap -layout "$KIVUN_KBD_LAYOUTS" -option "" -option grp:alt_shift_toggle 2>/dev/null || true
}

# --- Statusline setup ---
# Copy statusline.mjs into ~/.local/share/kivun-terminal/ and register it
# in Claude Code's settings. Complication: on this user's machine, Claude
# in WSL also walks up from cwd (/mnt/c/Users/<user>/) and picks up
# %USERPROFILE%/.claude/settings.json — which has a Windows-path
# statusline command that Linux node can't execute, SILENTLY breaking our
# registration. Fix: write a settings.local.json override at the PROJECT
# level (higher precedence than project settings.json) with a Linux-valid
# command. Also keep the user-level settings.json for redundancy.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/statusline.mjs" ] && [ -f "$SCRIPT_DIR/configure-statusline.js" ]; then
  KT_HOME="$HOME/.local/share/kivun-terminal"
  mkdir -p "$KT_HOME"
  cp "$SCRIPT_DIR/statusline.mjs" "$KT_HOME/statusline.mjs" 2>/dev/null
  sed -i 's/\r$//' "$KT_HOME/statusline.mjs" 2>/dev/null
  if command -v node >/dev/null 2>&1; then
    # 1. User-level registration (~/.claude/settings.json)
    node "$SCRIPT_DIR/configure-statusline.js" "$KT_HOME/statusline.mjs" \
      && log "SUCCESS - Statusline registered: $KT_HOME/statusline.mjs" \
      || log "WARNING - configure-statusline.js failed"

    # 2. Write a WSL-only settings file at $KT_HOME/settings.json. The
    # tmp launch script passes this to claude via --settings. The
    # outputStyle/verbosity knobs suppress tool-call spam and compact the
    # transcript — matching the config the user runs on Windows Terminal.
    # lines=2 reserves a SECOND line of vertical space for the
    # statusline. statusline.mjs writes two lines (project/model/context
    # on top, session/weekly usage bars on bottom); without lines>=2,
    # Claude Code 2.1.x clips to one line and silently drops the second
    # process.stdout.write. NOTE: padding is horizontal-only — using it
    # here as a vertical-reserve was a false lead.
    #
    # The user-level configure-statusline.js sets this in
    # ~/.claude/settings.json, but --settings overrides that file — so
    # this per-session settings.json must set lines itself.
    #
    # We DELIBERATELY do not include outputStyle/transcriptVerbosity/
    # showToolCalls/showCommandOutput/showCommand/showCode here. The
    # sibling kivun-terminal (Windows Terminal) project — which renders
    # the 2-line statusline correctly — has only `statusLine` in its
    # settings.json. When this file also had the verbosity keys, the
    # second statusline row failed to render in WSL/Konsole, even with
    # lines:2 set. Matching the sibling's minimal config restored
    # 2-line rendering. Adding any of those keys back risks the same
    # collapse — re-test with this exact minimal payload before adding
    # any verbosity tuning.
    cat > "$KT_HOME/settings.json" <<EOF
{
  "statusLine": {
    "type": "command",
    "command": "node \\"$KT_HOME/statusline.mjs\\"",
    "lines": 2
  }
}
EOF
    log "SUCCESS - Wrote WSL-only settings: $KT_HOME/settings.json"
  else
    log "WARNING - node not in PATH, skipping statusline registration"
  fi
else
  log "INFO - statusline.mjs not found in install dir, skipping"
fi

if [ "$USE_VCXSRV" = "true" ]; then
  log "INFO - VcXsrv mode enabled, testing connection"
  # The Windows host is the WSL default gateway, not /etc/resolv.conf's
  # nameserver (that can be a corporate DNS like 10.x.x.x and won't be
  # where VcXsrv listens). Prefer the gateway; fall back to resolv.conf.
  WINDOWS_HOST=$(ip route show default 2>/dev/null | awk '/^default/{print $3; exit}')
  if [ -z "$WINDOWS_HOST" ]; then
    WINDOWS_HOST=$(awk '/^nameserver/{print $2; exit}' /etc/resolv.conf 2>/dev/null)
    log "INFO - Gateway unavailable, using resolv.conf nameserver: $WINDOWS_HOST"
  fi
  export DISPLAY="${WINDOWS_HOST}:0"
  log "INFO - DISPLAY set to $DISPLAY"

  if timeout 3 xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then
    log "SUCCESS - VcXsrv is reachable"
    # Authorize only THIS user to talk to the X server. `xhost +local:`
    # allows every local UID; `xhost +si:localuser:$USER` limits to the
    # invoking user via SI-authenticated ucred checks. Matches the
    # access-control-on xlaunch config (-ac removed, DisableAC=False).
    xhost "+si:localuser:$USER" 2>/dev/null || true
    apply_kivun_keyboard
    log "SUCCESS - Keyboard layout configured (VcXsrv mode, Alt+Shift enabled)"
    echo "Keyboard mode: VcXsrv (Alt+Shift toggle enabled)"
  else
    # Falling back to WSLg here is NOT inherently a failure: on modern
    # Windows 11 + WSL2 (WSLg >= 1.0.65) WSLg handles X11 keyboard +
    # display fine, including Alt+Shift xkb layout switching. The
    # message is INFO, not WARNING, because most users on a current
    # build will have a working terminal even though USE_VCXSRV=true.
    # The reason VcXsrv is unreachable here is almost always one of:
    #   1. VcXsrv is not running (the launcher tried to start it but
    #      it has not opened TCP yet, or the install lacks xlaunch.exe).
    #   2. VcXsrv is running but Windows Firewall blocks inbound TCP
    #      6000 from the WSL Hyper-V vEthernet adapter.
    #   3. VcXsrv is running with -nolisten tcp (rare; most modern
    #      builds default to listening).
    # If keyboard switching DOES break for the user, that confirms WSLg
    # is the actual problem and they need real VcXsrv connectivity --
    # at which point they should check the firewall + that VcXsrv was
    # launched with -listen tcp. See docs/VCXSRV_TROUBLESHOOTING.md.
    log "INFO - VcXsrv configured but unreachable; using WSLg (works for most modern Windows 11 setups)"
    echo "Display: WSLg (VcXsrv unreachable -- usually fine on Windows 11)"
    export DISPLAY=:0
    log "INFO - DISPLAY reset to :0 for WSLg"
    apply_kivun_keyboard
    log "SUCCESS - Keyboard layout configured (WSLg fallback mode)"
  fi
else
  log "INFO - WSLg mode (default)"
  apply_kivun_keyboard
  log "SUCCESS - Keyboard layout configured (WSLg mode)"
  echo "Keyboard: Alt+Shift switches layouts (opens in your current language)"
fi

log "INFO - Deploying Konsole profile and color scheme"
mkdir -p ~/.local/share/konsole

if [ "$TEXT_DIR" = "rtl" ]; then
    BIDI_ENABLED="true"
    BIDI_LINE_LTR="false"
    log "INFO - BiDi enabled, line direction auto-detect (Hebrew right-aligned, English left-aligned)"
else
    BIDI_ENABLED="false"
    BIDI_LINE_LTR="true"
    log "INFO - BiDi disabled, lines forced to LTR"
fi

cat > ~/.local/share/konsole/KivunTerminal.profile << PROFEOF
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
# %d = current directory basename, so each tab/window is named by its project
# folder (e.g. "gvSIG") instead of a static "Kivun Terminal". %D would be the
# full path; %n the program name.
LocalTabTitleFormat=%d
RemoteTabTitleFormat=%d

[Scrolling]
HistorySize=10000
ScrollBarPosition=1

[Terminal Features]
BlinkingCursorEnabled=true
BidiEnabled=$BIDI_ENABLED
BidiLineLTR=$BIDI_LINE_LTR
PROFEOF

cat > ~/.local/share/konsole/ColorSchemeNoam.colorscheme << 'CSEOF'
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
CSEOF

log "SUCCESS - Profile and color scheme deployed"

log "INFO - Changing directory to: $WSL_PATH"
cd "$WSL_PATH" 2>/dev/null || cd ~
log "SUCCESS - Current directory: $(pwd)"

log "INFO - Checking BiDi wrapper config (KIVUN_BIDI_WRAPPER)"
# Parent .bat doesn't pass this key, so read it directly from the
# config.txt deployed next to this script. Default-when-absent is "on"
# so users upgrading from v1.0.6 (whose config.txt predates this key)
# get the wrapper activated without needing a config edit.
KIVUN_BIDI_WRAPPER="on"
if [ -f "$SCRIPT_DIR/config.txt" ]; then
    val=$(grep -E '^[[:space:]]*KIVUN_BIDI_WRAPPER[[:space:]]*=' "$SCRIPT_DIR/config.txt" 2>/dev/null | tail -1 \
        | sed -e 's/^[[:space:]]*KIVUN_BIDI_WRAPPER[[:space:]]*=[[:space:]]*//' -e 's/\r$//' -e 's/[[:space:]]*$//')
    [ -n "$val" ] && KIVUN_BIDI_WRAPPER="$val"
fi

# Tabbed mode: when a Kivun window is already open, add a new tab to it
# instead of opening a separate window (lets you run several projects side by
# side). Default "on". Set KIVUN_TABBED=off in config.txt for a separate
# window per launch — either way the existing window is never closed.
KIVUN_TABBED="on"
if [ -f "$SCRIPT_DIR/config.txt" ]; then
    val=$(grep -E '^[[:space:]]*KIVUN_TABBED[[:space:]]*=' "$SCRIPT_DIR/config.txt" 2>/dev/null | tail -1 \
        | sed -e 's/^[[:space:]]*KIVUN_TABBED[[:space:]]*=[[:space:]]*//' -e 's/\r$//' -e 's/[[:space:]]*$//')
    [ -n "$val" ] && KIVUN_TABBED="$val"
fi
log "INFO - KIVUN_TABBED=$KIVUN_TABBED"

# Bullet-strip on Hebrew lines. ON by default after a v1.1.8 user-confirmed
# fix: Konsole 23.x (Ubuntu 24.04 default) classifies the leading ● as
# LTR-anchoring and refuses to flip the line RTL even with RLM at start.
# Stripping the bullet means the first visible char is Hebrew and BiDi
# flips the line RTL automatically. Set to "off" in config.txt to keep
# bullet markers visible (alignment will revert to broken on Konsole 23.x;
# Konsole 24.04+ is unaffected and may not need this).
KIVUN_BIDI_STRIP_BULLET="on"
if [ -f "$SCRIPT_DIR/config.txt" ]; then
    val=$(grep -E '^[[:space:]]*KIVUN_BIDI_STRIP_BULLET[[:space:]]*=' "$SCRIPT_DIR/config.txt" 2>/dev/null | tail -1 \
        | sed -e 's/^[[:space:]]*KIVUN_BIDI_STRIP_BULLET[[:space:]]*=[[:space:]]*//' -e 's/\r$//' -e 's/[[:space:]]*$//')
    [ -n "$val" ] && KIVUN_BIDI_STRIP_BULLET="$val"
fi
export KIVUN_BIDI_STRIP_BULLET
log "INFO - KIVUN_BIDI_STRIP_BULLET=$KIVUN_BIDI_STRIP_BULLET"

# Strip-incoming bidi controls. Default "auto" — wrapper strips silently
# but logs a single line to ~/.local/state/kivun-terminal/bidi-strip.log
# the first time it sees an embedding/isolate control char in the upstream
# stream. Lets us answer "is Claude actually emitting these?" from real-
# user data without spamming. See KIVUN_BIDI_STRIP_INCOMING in injector.js
# for the full mode breakdown (off/auto/on).
KIVUN_BIDI_STRIP_INCOMING="auto"
if [ -f "$SCRIPT_DIR/config.txt" ]; then
    val=$(grep -E '^[[:space:]]*KIVUN_BIDI_STRIP_INCOMING[[:space:]]*=' "$SCRIPT_DIR/config.txt" 2>/dev/null | tail -1 \
        | sed -e 's/^[[:space:]]*KIVUN_BIDI_STRIP_INCOMING[[:space:]]*=[[:space:]]*//' -e 's/\r$//' -e 's/[[:space:]]*$//')
    [ -n "$val" ] && KIVUN_BIDI_STRIP_INCOMING="$val"
fi
export KIVUN_BIDI_STRIP_INCOMING
log "INFO - KIVUN_BIDI_STRIP_INCOMING=$KIVUN_BIDI_STRIP_INCOMING"

# Raw upstream byte dump. Off by default — debug-only feature for cases
# where the strip log alone isn't enough to diagnose a render bug. When
# on, every chunk Claude sends is appended to
# ~/.local/state/kivun-terminal/bidi-raw-dump.bin BEFORE strip-incoming
# touches it. File auto-rotates to .old at 5 MiB to bound growth.
KIVUN_BIDI_DUMP_RAW="off"
if [ -f "$SCRIPT_DIR/config.txt" ]; then
    val=$(grep -E '^[[:space:]]*KIVUN_BIDI_DUMP_RAW[[:space:]]*=' "$SCRIPT_DIR/config.txt" 2>/dev/null | tail -1 \
        | sed -e 's/^[[:space:]]*KIVUN_BIDI_DUMP_RAW[[:space:]]*=[[:space:]]*//' -e 's/\r$//' -e 's/[[:space:]]*$//')
    [ -n "$val" ] && KIVUN_BIDI_DUMP_RAW="$val"
fi
export KIVUN_BIDI_DUMP_RAW
log "INFO - KIVUN_BIDI_DUMP_RAW=$KIVUN_BIDI_DUMP_RAW"

# Flatten ANSI SGR (color/style) sequences inside RTL lines. ON by default
# (v1.1.10). Konsole 23.x's BiDi only spans continuous-attribute regions;
# any color change splits the run and Qt mis-positions the resulting LTR
# fragments to the visual left instead of their UAX #9 logical position.
# Stripping SGR escapes from RTL lines makes the whole line one attribute
# run and gets correct positioning -- at the cost of syntax color on
# Hebrew lines. Turn off if you'd rather keep colors at the cost of
# broken positioning.
KIVUN_BIDI_FLATTEN_COLORS_RTL="on"
if [ -f "$SCRIPT_DIR/config.txt" ]; then
    val=$(grep -E '^[[:space:]]*KIVUN_BIDI_FLATTEN_COLORS_RTL[[:space:]]*=' "$SCRIPT_DIR/config.txt" 2>/dev/null | tail -1 \
        | sed -e 's/^[[:space:]]*KIVUN_BIDI_FLATTEN_COLORS_RTL[[:space:]]*=[[:space:]]*//' -e 's/\r$//' -e 's/[[:space:]]*$//')
    [ -n "$val" ] && KIVUN_BIDI_FLATTEN_COLORS_RTL="$val"
fi
export KIVUN_BIDI_FLATTEN_COLORS_RTL
log "INFO - KIVUN_BIDI_FLATTEN_COLORS_RTL=$KIVUN_BIDI_FLATTEN_COLORS_RTL"

# Per-run RLE/PDF bracketing of Hebrew runs INSIDE RTL paragraphs.
# Default OFF in v1.1.11+ — Konsole 23.x's BiDi treats per-run RLE/PDF
# pairs as attribute-region boundaries and mispositions LTR fragments
# (English/code) inside Hebrew sentences. Skipping per-run bracketing
# means line-start RLM + Konsole's UAX #9 handle direction without
# extra region boundaries. Hebrew runs inside LTR paragraphs still
# get bracketed (the Hebrew is the exception in an LTR flow).
# Set to "on" if you want the legacy v1.1.0 - v1.1.10 behavior back.
KIVUN_BIDI_BRACKET_RTL_RUNS="off"
if [ -f "$SCRIPT_DIR/config.txt" ]; then
    val=$(grep -E '^[[:space:]]*KIVUN_BIDI_BRACKET_RTL_RUNS[[:space:]]*=' "$SCRIPT_DIR/config.txt" 2>/dev/null | tail -1 \
        | sed -e 's/^[[:space:]]*KIVUN_BIDI_BRACKET_RTL_RUNS[[:space:]]*=[[:space:]]*//' -e 's/\r$//' -e 's/[[:space:]]*$//')
    [ -n "$val" ] && KIVUN_BIDI_BRACKET_RTL_RUNS="$val"
fi
export KIVUN_BIDI_BRACKET_RTL_RUNS
log "INFO - KIVUN_BIDI_BRACKET_RTL_RUNS=$KIVUN_BIDI_BRACKET_RTL_RUNS"

# RTL cost optimizer (EXPERIMENT, issue #98). Off by default. When on,
# PIPED stdin prompts are normalized and scaffold-wrapped locally before
# reaching Claude — the user's full request is always carried verbatim.
# Savings UNPROVEN: input tokens may INCREASE; the experiment measures
# output-token impact. Interactive TUI typing is NEVER touched.
KIVUN_RTL_COST_OPTIMIZER="off"
if [ -f "$SCRIPT_DIR/config.txt" ]; then
    val=$(grep -E '^[[:space:]]*KIVUN_RTL_COST_OPTIMIZER[[:space:]]*=' "$SCRIPT_DIR/config.txt" 2>/dev/null | tail -1 \
        | sed -e 's/^[[:space:]]*KIVUN_RTL_COST_OPTIMIZER[[:space:]]*=[[:space:]]*//' -e 's/\r$//' -e 's/[[:space:]]*$//')
    [ -n "$val" ] && KIVUN_RTL_COST_OPTIMIZER="$val"
fi
export KIVUN_RTL_COST_OPTIMIZER
log "INFO - KIVUN_RTL_COST_OPTIMIZER=$KIVUN_RTL_COST_OPTIMIZER"

# Optimizer sub-knobs (only consulted when the master switch is on).
KIVUN_RTL_COST_OPTIMIZER_SCAFFOLD="on"
if [ -f "$SCRIPT_DIR/config.txt" ]; then
    val=$(grep -E '^[[:space:]]*KIVUN_RTL_COST_OPTIMIZER_SCAFFOLD[[:space:]]*=' "$SCRIPT_DIR/config.txt" 2>/dev/null | tail -1 \
        | sed -e 's/^[[:space:]]*KIVUN_RTL_COST_OPTIMIZER_SCAFFOLD[[:space:]]*=[[:space:]]*//' -e 's/\r$//' -e 's/[[:space:]]*$//')
    [ -n "$val" ] && KIVUN_RTL_COST_OPTIMIZER_SCAFFOLD="$val"
fi
export KIVUN_RTL_COST_OPTIMIZER_SCAFFOLD

KIVUN_RTL_COST_OPTIMIZER_SHOW_PREVIEW="on"
if [ -f "$SCRIPT_DIR/config.txt" ]; then
    val=$(grep -E '^[[:space:]]*KIVUN_RTL_COST_OPTIMIZER_SHOW_PREVIEW[[:space:]]*=' "$SCRIPT_DIR/config.txt" 2>/dev/null | tail -1 \
        | sed -e 's/^[[:space:]]*KIVUN_RTL_COST_OPTIMIZER_SHOW_PREVIEW[[:space:]]*=[[:space:]]*//' -e 's/\r$//' -e 's/[[:space:]]*$//')
    [ -n "$val" ] && KIVUN_RTL_COST_OPTIMIZER_SHOW_PREVIEW="$val"
fi
export KIVUN_RTL_COST_OPTIMIZER_SHOW_PREVIEW

KIVUN_RTL_COST_OPTIMIZER_SHOW_ESTIMATE="on"
if [ -f "$SCRIPT_DIR/config.txt" ]; then
    val=$(grep -E '^[[:space:]]*KIVUN_RTL_COST_OPTIMIZER_SHOW_ESTIMATE[[:space:]]*=' "$SCRIPT_DIR/config.txt" 2>/dev/null | tail -1 \
        | sed -e 's/^[[:space:]]*KIVUN_RTL_COST_OPTIMIZER_SHOW_ESTIMATE[[:space:]]*=[[:space:]]*//' -e 's/\r$//' -e 's/[[:space:]]*$//')
    [ -n "$val" ] && KIVUN_RTL_COST_OPTIMIZER_SHOW_ESTIMATE="$val"
fi
export KIVUN_RTL_COST_OPTIMIZER_SHOW_ESTIMATE

KIVUN_RTL_COST_OPTIMIZER_AUDIT="on"
if [ -f "$SCRIPT_DIR/config.txt" ]; then
    val=$(grep -E '^[[:space:]]*KIVUN_RTL_COST_OPTIMIZER_AUDIT[[:space:]]*=' "$SCRIPT_DIR/config.txt" 2>/dev/null | tail -1 \
        | sed -e 's/^[[:space:]]*KIVUN_RTL_COST_OPTIMIZER_AUDIT[[:space:]]*=[[:space:]]*//' -e 's/\r$//' -e 's/[[:space:]]*$//')
    [ -n "$val" ] && KIVUN_RTL_COST_OPTIMIZER_AUDIT="$val"
fi
export KIVUN_RTL_COST_OPTIMIZER_AUDIT

# Copy the wrapper source out of /mnt/c into a WSL-native path, run npm
# install once, and return the absolute path to the wrapper binary. Called
# only when KIVUN_BIDI_WRAPPER=on. Side effects: creates
# ~/.local/share/kivun-terminal/kivun-claude-bidi/ and node_modules inside
# it on first run. Subsequent runs skip npm install unless package.json has
# been updated.
deploy_bidi_wrapper() {
    local src="$SCRIPT_DIR/kivun-claude-bidi"
    local dst="$HOME/.local/share/kivun-terminal/kivun-claude-bidi"

    if [ ! -d "$src" ]; then
        log "WARNING - Wrapper source not found at $src (installer may be outdated)"
        return 1
    fi

    mkdir -p "$dst"
    log "INFO - Syncing wrapper: $src -> $dst"
    (cd "$src" && tar --exclude=node_modules --exclude=.git -cf - .) \
        | (cd "$dst" && tar xf -) >> "$LOG_FILE" 2>&1

    # Installer files come from Windows and may have CRLF even if the repo
    # itself is LF-clean (git autocrlf on checkout). Strip CR from the
    # handful of text files the wrapper actually sources at runtime.
    find "$dst" -type f \( -name '*.js' -o -name '*.cjs' -o -name '*.json' -o -name '*.sh' \) \
        -exec sed -i 's/\r$//' {} + 2>/dev/null
    [ -f "$dst/bin/kivun-claude-bidi" ] && sed -i 's/\r$//' "$dst/bin/kivun-claude-bidi" 2>/dev/null
    chmod +x "$dst/bin/kivun-claude-bidi" 2>/dev/null

    # npm install guard: reinstall only if node_modules is missing or the
    # shipped package.json is newer than our install stamp.
    local stamp="$dst/node_modules/.kivun-install-stamp"
    if [ ! -f "$stamp" ] || [ "$dst/package.json" -nt "$stamp" ]; then
        if command -v npm >/dev/null 2>&1; then
            log "INFO - Installing wrapper dependencies (npm install --production)"
            (cd "$dst" && npm install --production --no-audit --no-fund) >> "$LOG_FILE" 2>&1
            local rc=$?
            if [ $rc -ne 0 ]; then
                log "ERROR - npm install failed (exit $rc); wrapper will not work"
                return 1
            fi
            mkdir -p "$(dirname "$stamp")"
            touch "$stamp"
            log "SUCCESS - Wrapper dependencies installed"
        else
            log "ERROR - npm not found in WSL; install Node.js first (apt install nodejs npm)"
            return 1
        fi
    else
        log "INFO - Wrapper dependencies up to date"
    fi

    return 0
}

CLAUDE_EXEC="claude"
if [ "$KIVUN_BIDI_WRAPPER" = "on" ]; then
    if deploy_bidi_wrapper; then
        WRAPPER_BIN="$HOME/.local/share/kivun-terminal/kivun-claude-bidi/bin/kivun-claude-bidi"
        if [ -x "$WRAPPER_BIN" ]; then
            CLAUDE_EXEC="$WRAPPER_BIN"
            log "SUCCESS - BiDi wrapper active: $CLAUDE_EXEC"
        else
            log "WARNING - Wrapper binary missing after deploy; using unwrapped claude"
        fi
    else
        log "WARNING - Wrapper deploy failed; using unwrapped claude (see log above)"
    fi
else
    log "INFO - BiDi wrapper off (KIVUN_BIDI_WRAPPER=$KIVUN_BIDI_WRAPPER)"
fi

log "INFO - Creating temporary launch script"
# Per-user path so a stale file left by a different UID (e.g. from an
# earlier run as 'username' or root) can't block us with EPERM.
LAUNCH_TMP="/tmp/kivun-claude-launch-$(id -u).sh"
rm -f "$LAUNCH_TMP" 2>/dev/null
cat > "$LAUNCH_TMP" << LAUNCHEOF
#!/bin/bash -l
echo "==============================================="
echo " Kivun Terminal - Starting Claude Code"
echo "==============================================="
echo ""

if ! command -v "$CLAUDE_EXEC" >/dev/null 2>&1; then
    echo "ERROR: '$CLAUDE_EXEC' not found / not executable."
    echo "PATH: \$PATH"
    echo ""
    echo "If 'claude' is missing, install it with:"
    echo "  curl -fsSL https://claude.ai/install.sh | bash"
    echo ""
    echo "Press Enter to close."
    read
    exit 1
fi

echo "Claude binary: \$(command -v "$CLAUDE_EXEC")"
echo "Working directory: \$(pwd)"
echo ""

# Use --settings to point Claude at our WSL-only settings file. This is
# needed because when cwd is under /mnt/c/Users/<user>/ Claude walks up
# and finds %USERPROFILE%/.claude/settings.json which has a Windows-path
# statusLine command that Linux node cannot execute.
KT_SETTINGS="\$HOME/.local/share/kivun-terminal/settings.json"

if [ -n "$CLAUDE_PROMPT" ]; then
    $CLAUDE_EXEC --settings "\$KT_SETTINGS" --append-system-prompt "$CLAUDE_PROMPT" $CLAUDE_FLAGS
else
    $CLAUDE_EXEC --settings "\$KT_SETTINGS" $CLAUDE_FLAGS
fi
EXIT_CODE=\$?

echo ""
echo "==============================================="
echo " Claude exited with code \$EXIT_CODE"
echo "==============================================="
echo "Press Enter to close."
read
LAUNCHEOF
chmod +x "$LAUNCH_TMP"
log "SUCCESS - Launch script created: $LAUNCH_TMP (CLAUDE_PROMPT length: ${#CLAUDE_PROMPT})"

# v1.1.17: WSLg picks the Windows-side taskbar icon by matching a
# launched window's WM_CLASS (or Wayland app_id) against installed
# .desktop files' StartupWMClass entries. Setting _NET_WM_ICON via
# python-xlib (the v1.1.7 path below) works under VcXsrv but is
# ignored by WSLg's RDP icon channel — so users on the default
# (USE_VCXSRV=false) configuration saw a blank title-bar/taskbar icon.
#
# Fix: register a kivun-terminal.desktop in ~/.local/share/applications/
# pointing to our PNG, then launch Konsole with --name kivun-terminal
# so its WM_CLASS becomes "kivun-terminal". WSLg matches that class
# against the .desktop StartupWMClass and uses our PNG for the icon.
#
# Newer Konsole (Qt6, e.g. Ubuntu "questing"/"resolute" under Wayland) removed
# the X11 --name option and aborts with "Unknown option 'name'" — which made
# the terminal window never open at all. Probe once and only pass --name where
# this Konsole accepts it; without it we lose the custom WM_CLASS (taskbar icon
# grouping) but the window opens, which matters far more.
KIVUN_NAME_OPT="--name kivun-terminal"
if ! timeout 10 konsole --name kivun-terminal --version >/dev/null 2>&1; then
    KIVUN_NAME_OPT=""
    log "INFO - Konsole rejects --name (Qt6/Wayland); launching without it"
fi
ICON_PNG_DEPLOY="$(dirname "$0")/kivun-icon.png"
if [ -f "$ICON_PNG_DEPLOY" ]; then
    DESKTOP_DIR="$HOME/.local/share/applications"
    mkdir -p "$DESKTOP_DIR"
    cat > "$DESKTOP_DIR/kivun-terminal.desktop" <<DESKEOF
[Desktop Entry]
Type=Application
Name=Kivun Terminal
Comment=Claude Code with full RTL/BiDi rendering
Exec=konsole $KIVUN_NAME_OPT --profile KivunTerminal
Icon=$ICON_PNG_DEPLOY
Terminal=false
Categories=Utility;TerminalEmulator;
StartupWMClass=kivun-terminal
DESKEOF
    # Refresh the desktop-database cache so WSLg's xdg lookup sees
    # the new entry. Best-effort: the binary may not be installed,
    # in which case the entry is still discoverable via plain file
    # scan (slower but works).
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$DESKTOP_DIR" >> "$LOG_FILE" 2>&1
    fi
    log "SUCCESS - .desktop registered: $DESKTOP_DIR/kivun-terminal.desktop"
else
    log "WARNING - kivun-icon.png missing; cannot register .desktop entry"
fi

# Decide: open a NEW WINDOW, or add a TAB to an existing Kivun window?
# Tab mode needs the managed bus AND a Konsole already registered on it (one
# we can drive over D-Bus). We detect that by asking the bus for an
# org.kde.konsole-<pid> service — not just pgrep — so we never try to tab into
# a konsole that isn't reachable (e.g. one started before this version, or on
# a different bus); those just get a fresh window.
KIVUN_MODE="window"
KIVUN_SVC=""
if [ "$KIVUN_TABBED" = "on" ] && [ -n "$DBUS_SESSION_BUS_ADDRESS" ] \
   && command -v dbus-send >/dev/null 2>&1; then
    KIVUN_SVC="$(dbus-send --session --print-reply --dest=org.freedesktop.DBus \
        /org/freedesktop/DBus org.freedesktop.DBus.ListNames 2>/dev/null \
        | grep -oE 'org\.kde\.konsole-[0-9]+' | head -1)"
    [ -n "$KIVUN_SVC" ] && KIVUN_MODE="tab"
fi

# setsid detaches Konsole into a new session so it survives the parent bash
# dying (e.g. user closes the cmd.exe window or the wsl bridge exits). Without
# it, closing the launcher's console window sent SIGHUP to Konsole and killed
# the live Claude session. --name kivun-terminal sets WM_CLASS res_name (Qt
# arg); combined with the kivun-terminal.desktop StartupWMClass above, WSLg
# uses kivun-icon.png as the taskbar icon.
if [ "$KIVUN_MODE" = "tab" ]; then
    log "INFO - Existing Konsole on bus ($KIVUN_SVC) — adding a new tab via D-Bus (KIVUN_TABBED=on)"
    # Konsole's `--new-tab` flag does NOT reliably attach to a running instance
    # under WSLg (it falls back to a new window). The reliable path is Konsole's
    # D-Bus API: create a session (tab) in the window with our profile + the
    # chosen working directory, then exec the launch script inside it. $PWD is
    # the already-resolved target folder (we cd'd to $WSL_PATH earlier).
    #
    # NOTE: the profile arg here is the profile's *Name* ("Kivun Terminal"),
    # NOT the filename ("KivunTerminal"). The CLI `--profile` matches the
    # filename, but Konsole's D-Bus newSession matches the Name= field; passing
    # the filename silently falls back to the black Built-in profile.
    KIVUN_SID="$(dbus-send --session --print-reply --dest="$KIVUN_SVC" /Windows/1 \
        org.kde.konsole.Window.newSession string:"Kivun Terminal" string:"$PWD" 2>/dev/null \
        | awk '/int32/{print $NF}')"
    if [ -n "$KIVUN_SID" ]; then
        log "SUCCESS - Created tab session $KIVUN_SID in $KIVUN_SVC (dir: $PWD)"
        # Focus the new tab (best-effort).
        dbus-send --session --dest="$KIVUN_SVC" /Windows/1 \
            org.kde.konsole.Window.setCurrentSession int32:"$KIVUN_SID" >/dev/null 2>&1
        # Give the tab's shell a moment to come up, then exec the launch script
        # in it (runCommand types+runs it; --print-reply makes dbus-send wait).
        sleep 2
        dbus-send --session --print-reply --dest="$KIVUN_SVC" /Sessions/"$KIVUN_SID" \
            org.kde.konsole.Session.runCommand string:"exec \"$LAUNCH_TMP\"" >/dev/null 2>&1
        KPID=0
    else
        log "WARNING - D-Bus newSession failed; falling back to a new window"
        KIVUN_MODE="window"
    fi
fi

if [ "$KIVUN_MODE" = "window" ]; then
    log "INFO - Launching Konsole with KivunTerminal profile (WM_CLASS=kivun-terminal)"
    log "INFO - Command: setsid konsole $KIVUN_NAME_OPT --profile KivunTerminal -e $LAUNCH_TMP"
    setsid konsole $KIVUN_NAME_OPT --profile KivunTerminal -e "$LAUNCH_TMP" </dev/null >> "$LOG_FILE" 2>&1 &
    KPID=$!
    if [ $KPID -gt 0 ]; then
        log "SUCCESS - Konsole started with PID: $KPID"
    else
        log "ERROR - Failed to start Konsole!"
        log "ERROR - Check if konsole is installed: command -v konsole"
        command -v konsole >> "$LOG_FILE" 2>&1
        exit 1
    fi
fi

if [ "$KIVUN_MODE" = "tab" ]; then
    # Tab mode: the window already exists and is sized/iconed/named. Just
    # bring it to the front so the new tab is visible. Skip all geometry.
    log "INFO - Tab mode: activating existing Kivun window, skipping geometry/icon"
    sleep 1
    if command -v xdotool >/dev/null 2>&1; then
        WID=$(xdotool search --class kivun-terminal 2>/dev/null | head -1)
        [ -z "$WID" ] && WID=$(xdotool search --class konsole 2>/dev/null | head -1)
        if [ -n "$WID" ]; then
            xdotool windowactivate "$WID" 2>/dev/null
            log "SUCCESS - Activated existing Kivun window (ID: $WID)"
        else
            log "WARNING - Could not find existing Kivun window to activate"
        fi
    fi
else
log "INFO - Waiting 3 seconds for Konsole window to appear"
sleep 3

# --- Determine target geometry for Konsole ---
# Priority:
#   1. PRIMARY_MON arg from Windows ("X Y W H") — most accurate, Windows knows
#      the real primary monitor and taskbar.
#   2. xrandr with "connected primary" tag — works on WSLg (single virtual
#      screen), sometimes on VcXsrv.
#   3. Xinerama head #0 — VcXsrv exposes this with per-Windows-monitor info.
#   4. Fall back to 100% 100% / 0,0 (legacy behavior — spans all monitors).
TARGET_X=""; TARGET_Y=""; TARGET_W=""; TARGET_H=""
if [ -n "$PRIMARY_MON" ]; then
  read -r TARGET_X TARGET_Y TARGET_W TARGET_H <<< "$PRIMARY_MON"
  log "INFO - Using Windows primary monitor bounds: ${TARGET_W}x${TARGET_H} at +${TARGET_X}+${TARGET_Y}"
elif command -v xrandr >/dev/null 2>&1; then
  GEOM=$(xrandr --query 2>/dev/null | awk '
    / connected primary / {
      for (i=1; i<=NF; i++) {
        if ($i ~ /^[0-9]+x[0-9]+\+[0-9]+\+[0-9]+$/) { print $i; exit }
      }
    }')
  if [ -n "$GEOM" ]; then
    TARGET_W=${GEOM%%x*}; rest=${GEOM#*x}
    TARGET_H=${rest%%+*}; rest=${rest#*+}
    TARGET_X=${rest%%+*}; TARGET_Y=${rest#*+}
    log "INFO - Using xrandr primary: ${TARGET_W}x${TARGET_H} at +${TARGET_X}+${TARGET_Y}"
  fi
fi
if [ -z "$TARGET_W" ] && command -v xdpyinfo >/dev/null 2>&1; then
  # VcXsrv Xinerama fallback. Each "head #N: WxH @ X,Y" line is a monitor.
  # On Windows, the primary monitor is always at coord (0,0) — prefer that
  # head over head #0, since Xinerama head-ordering is VcXsrv-internal and
  # doesn't always map head #0 to primary.
  PRIMARY_HEAD=$(xdpyinfo -ext XINERAMA 2>/dev/null | awk '
    /head #[0-9]+:/ {
      # $3 = "WIDTHxHEIGHT", $5 = "X,Y"
      if ($5 == "0,0") { print $3, $5; exit }
    }')
  if [ -z "$PRIMARY_HEAD" ]; then
    PRIMARY_HEAD=$(xdpyinfo -ext XINERAMA 2>/dev/null | awk '/head #0:/ {print $3, $5; exit}')
  fi
  if [ -n "$PRIMARY_HEAD" ]; then
    SIZE=${PRIMARY_HEAD% *}
    POS=${PRIMARY_HEAD#* }
    TARGET_W=${SIZE%%x*}
    TARGET_H=${SIZE#*x}
    TARGET_X=${POS%%,*}
    TARGET_Y=${POS#*,}
    log "INFO - Using Xinerama primary: ${TARGET_W}x${TARGET_H} at +${TARGET_X}+${TARGET_Y}"
  fi
fi

if command -v wmctrl >/dev/null 2>&1; then
  log "INFO - Using wmctrl for window management"
  wmctrl -r "Konsole" -N "Kivun Terminal" 2>/dev/null
  # Skip wmctrl's own maximize — it maximizes across the virtual screen
  # (spanning all monitors). We size/position manually via xdotool below.
  log "SUCCESS - Window renamed via wmctrl"
else
  log "WARNING - wmctrl not available"
fi

if command -v xdotool >/dev/null 2>&1; then
  log "INFO - Using xdotool for window management"
  WID=$(xdotool search --class konsole 2>/dev/null | head -1)
  if [ -n "$WID" ]; then
    log "SUCCESS - Found Konsole window (ID: $WID)"
    xdotool set_window --name "Kivun Terminal" "$WID" 2>/dev/null

    # Re-apply the keyboard layout now that the window actually exists. The
    # early setxkbmap (run before Konsole opened) can be dropped by WSLg
    # before the window grabs focus, leaving the first Alt+Shift doing
    # nothing ("stuck on Hebrew"). Focus the window, then re-apply so the
    # toggle is reliable from the first keystroke.
    xdotool windowactivate "$WID" 2>/dev/null
    apply_kivun_keyboard

    # Override the X server's default window icon (VcXsrv shows its own
    # X if the client doesn't set _NET_WM_ICON; Konsole sets only an
    # empty NAME). Best-effort: silently skip if python deps or icon
    # file are missing — the launcher already works without it.
    ICON_DIR="$(dirname "$0")"
    ICON_PNG="${ICON_DIR}/kivun-icon.png"
    ICON_PY="${ICON_DIR}/kivun-set-icon.py"
    if [ -f "$ICON_PNG" ] && [ -f "$ICON_PY" ] && command -v python3 >/dev/null 2>&1; then
      if python3 -c "import Xlib, PIL" 2>/dev/null; then
        if python3 "$ICON_PY" "$WID" "$ICON_PNG" >> "$LOG_FILE" 2>&1; then
          log "SUCCESS - Window icon set from $ICON_PNG"
        else
          log "WARNING - Setting window icon failed (see log above)"
        fi
      else
        log "INFO - Skipping icon override (python3-xlib + python3-pil not installed)"
      fi
    else
      log "INFO - Skipping icon override (icon assets not deployed)"
    fi

    if [ -n "$TARGET_W" ]; then
      # Unmaximize first so size/move take effect reliably
      wmctrl -i -r "$WID" -b remove,maximized_vert,maximized_horz 2>/dev/null
      # Size window to 80% of primary monitor and center it within that
      # monitor's bounds. Integer math via shell arithmetic expansion.
      WIN_W=$(( TARGET_W * 80 / 100 ))
      WIN_H=$(( TARGET_H * 80 / 100 ))
      WIN_X=$(( TARGET_X + (TARGET_W - WIN_W) / 2 ))
      WIN_Y=$(( TARGET_Y + (TARGET_H - WIN_H) / 2 ))
      xdotool windowmove "$WID" "$WIN_X" "$WIN_Y" 2>/dev/null
      xdotool windowsize "$WID" "$WIN_W" "$WIN_H" 2>/dev/null
      log "SUCCESS - Konsole sized to ${WIN_W}x${WIN_H} at +${WIN_X}+${WIN_Y} (80% of primary ${TARGET_W}x${TARGET_H})"
    else
      # No monitor info available — let KDE remember last window placement.
      log "WARNING - No monitor info, leaving Konsole at its default position"
    fi
  else
    log "WARNING - Could not find Konsole window with xdotool"
  fi
else
  log "WARNING - xdotool not available"
fi
fi  # end window-mode geometry/icon block (skipped in tab mode)

# v1.4.0: type any startup slash commands the HTA picker recorded into
# the running Konsole/Claude window. Background subshell so the main
# launcher continues to wait on Konsole. Best-effort — silently skips
# if xdotool is missing, the file is gone, or the Konsole window can't
# be found.
TYPER_PID=""
if [ -n "$STARTUP_CMDS_FILE" ] && [ -f "$STARTUP_CMDS_FILE" ] && command -v xdotool >/dev/null 2>&1; then
  log "INFO - Startup commands file: $STARTUP_CMDS_FILE — will type after Claude is ready"
  (
    # Wait for Claude to be ready for input. 5s is the empirical lower
    # bound on a warm WSL2; on a cold start the user will see the
    # commands type a second or two after the Claude prompt appears.
    sleep 5
    KIVUN_WID=$(xdotool search --class kivun-terminal 2>/dev/null | head -1)
    if [ -z "$KIVUN_WID" ]; then
      KIVUN_WID=$(xdotool search --class konsole 2>/dev/null | head -1)
    fi
    if [ -n "$KIVUN_WID" ]; then
      while IFS= read -r line; do
        [ -z "$line" ] && continue
        log "INFO - Typing startup command: $line"
        xdotool type --window "$KIVUN_WID" --delay 25 "$line" 2>/dev/null
        xdotool key --window "$KIVUN_WID" Return 2>/dev/null
        sleep 1
      done < "$STARTUP_CMDS_FILE"
    else
      log "WARNING - Could not find Kivun/Konsole window for startup commands"
    fi
    # One-shot: clear the file so the next launch starts fresh unless
    # the user re-enters commands in the picker.
    rm -f "$STARTUP_CMDS_FILE" 2>/dev/null
  ) &
  TYPER_PID=$!
fi

if [ "$KIVUN_MODE" = "window" ]; then
    log "INFO - Waiting for Konsole process to complete"
    wait $KPID
    log "COMPLETE - Bash launcher finished (Konsole process ended)"
else
    # Tab mode: the tab belongs to the already-running Konsole, so there is no
    # window of ours to wait on. Let any startup-command typing finish before
    # the launcher (and its WSL bridge) exits — otherwise the bridge closing
    # could SIGHUP the typist mid-type — then return promptly.
    [ -n "$TYPER_PID" ] && wait "$TYPER_PID" 2>/dev/null
    log "COMPLETE - Bash launcher finished (tab dispatched to existing window)"
fi
