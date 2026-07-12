#!/usr/bin/env bash
# kivun-apply-color.sh <TERMINAL_COLOR value>   (v1.6.2)
#
# Regenerate Konsole's color scheme + the profile's ColorScheme line from a
# color value, so a NEW Konsole tab/window shows the chosen color WITHOUT a full
# Kivun relaunch. This is the WSL half of the folder picker's "Apply now".
#
# Scope, on purpose: this affects tabs/windows opened AFTER it runs. The already
# open window keeps its color - Konsole loads a scheme into memory when a session
# starts and can't live-swap it from a file edit. Recoloring the running session
# would need Konsole D-Bus, which is unreliable under WSLg (Qt6/Wayland, forked
# instances) and is intentionally left to the roadmap until it can be tested on a
# real machine. So the honest promise here is "new tab shows it", and the live
# Claude session in the current tab is preserved (a relaunch would kill it).
#
# Safe to run while Kivun is open (rewriting the files doesn't touch the running
# session). Idempotent. Colour semantics are kept IDENTICAL to kivun-launch.sh;
# CI (validate-launcher-windows.yml) diffs the resolver below against the
# launcher's to catch drift.
set -u

KONSOLE_DIR="${HOME}/.local/share/konsole"
PROFILE="${KONSOLE_DIR}/KivunTerminal.profile"
SCHEME="${KONSOLE_DIR}/ColorSchemeNoam.colorscheme"

TERMINAL_COLOR="${1:-kivun}"

# ---- resolver: KEEP IN EXACT SYNC with kivun-launch.sh kivun_resolve_color() ----
# Sets KIVUN_USE_SCHEME (0/1) and, when 1, KIVUN_BG_RGB / KIVUN_FG_RGB as "R,G,B"
# decimal triples (the format Konsole .colorscheme files use).
KIVUN_USE_SCHEME=0; KIVUN_BG_RGB=""; KIVUN_FG_RGB=""
kivun_resolve_color() {
    local v hexbody r g b lum
    v=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
    case "$v" in
        ''|default) KIVUN_USE_SCHEME=0; return ;;
        kivun) KIVUN_BG_RGB="200,230,255"; KIVUN_FG_RGB="12,12,12";   KIVUN_USE_SCHEME=1; return ;;
        dark)  KIVUN_BG_RGB="30,30,30";   KIVUN_FG_RGB="242,242,242"; KIVUN_USE_SCHEME=1; return ;;
        black) KIVUN_BG_RGB="12,12,12";   KIVUN_FG_RGB="242,242,242"; KIVUN_USE_SCHEME=1; return ;;
        white) KIVUN_BG_RGB="255,255,255"; KIVUN_FG_RGB="12,12,12";   KIVUN_USE_SCHEME=1; return ;;
    esac
    if [[ "$v" =~ ^#([0-9a-f]{6}|[0-9a-f]{3})$ ]]; then
        hexbody="${v#\#}"
        if [ ${#hexbody} -eq 3 ]; then
            hexbody="${hexbody:0:1}${hexbody:0:1}${hexbody:1:1}${hexbody:1:1}${hexbody:2:1}${hexbody:2:1}"
        fi
        r=$((16#${hexbody:0:2})); g=$((16#${hexbody:2:2})); b=$((16#${hexbody:4:2}))
        lum=$(( (299 * r + 587 * g + 114 * b) / 1000 ))
        KIVUN_BG_RGB="$r,$g,$b"
        if [ "$lum" -ge 128 ]; then KIVUN_FG_RGB="12,12,12"; else KIVUN_FG_RGB="242,242,242"; fi
        KIVUN_USE_SCHEME=1
        return
    fi
    KIVUN_USE_SCHEME=0
}
kivun_resolve_color "$TERMINAL_COLOR"

# If Kivun has never launched, there is no profile to update yet. The choice is
# already saved to config.txt (the picker wrote it), so the first launch builds
# everything from scratch. Nothing to live-apply - exit quietly, success.
if [ ! -f "$PROFILE" ]; then
    echo "kivun-apply-color: no profile at ${PROFILE} yet; saved for next launch"
    exit 0
fi
mkdir -p "$KONSOLE_DIR"

if [ "$KIVUN_USE_SCHEME" = "1" ]; then
    DESIRED="ColorScheme=ColorSchemeNoam"
else
    DESIRED="# ColorScheme unset (TERMINAL_COLOR=default) - Konsole default look"
fi

# Surgically replace ONLY the ColorScheme line (or the "unset" comment) under
# [Appearance]. This preserves Font / BidiEnabled / cursor, which the launcher
# set from the user's language - a full profile rewrite here could clobber them.
# If neither marker exists (unexpected), insert right after [Appearance].
if grep -qE '^ColorScheme=|^# ColorScheme unset' "$PROFILE"; then
    sed -i -E "s|^ColorScheme=.*|${DESIRED}|; s|^# ColorScheme unset.*|${DESIRED}|" "$PROFILE"
else
    sed -i "/^\[Appearance\]/a ${DESIRED}" "$PROFILE"
fi

# Write the scheme file only when a color is in use. For TERMINAL_COLOR=default
# the profile above omits ColorScheme=, so Konsole shows its own look and a stale
# scheme file (if any) is simply never referenced - same as kivun-launch.sh.
if [ "$KIVUN_USE_SCHEME" = "1" ]; then
cat > "$SCHEME" << CSEOF
[Background]
Color=$KIVUN_BG_RGB

[BackgroundFaint]
Color=$KIVUN_BG_RGB

[BackgroundIntense]
Color=$KIVUN_BG_RGB

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
Color=$KIVUN_FG_RGB

[ForegroundFaint]
Color=$KIVUN_FG_RGB

[ForegroundIntense]
Color=$KIVUN_FG_RGB

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
fi

if [ "$KIVUN_USE_SCHEME" = "1" ]; then
    echo "kivun-apply-color: TERMINAL_COLOR=${TERMINAL_COLOR} -> bg ${KIVUN_BG_RGB} / fg ${KIVUN_FG_RGB}; open a new tab (Ctrl+Shift+T) to see it"
else
    echo "kivun-apply-color: TERMINAL_COLOR=${TERMINAL_COLOR} -> Konsole default look (no custom scheme); open a new tab to see it"
fi
exit 0
