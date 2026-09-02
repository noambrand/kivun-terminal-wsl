#!/bin/bash
# kivun-fast-updates.sh — put this machine's Claude Code on the CURRENT release
# channel, one time, for people who already had Claude before this version.
#
# Background: Anthropic publishes two channels. `stable` is conservative and can
# sit on the same build for weeks; `latest` is the current one. A Claude that was
# installed without an explicit channel follows `stable` forever, so the user
# reports "it stopped updating" while the auto-updater is in fact working
# perfectly — it just has nothing to fetch. Observed 2026-09-03: stable 2.1.236,
# latest 2.1.258, twenty-two releases apart.
#
# Fresh installs are handled at the source (kivun-install-claude.sh passes
# `latest`). This script is the other half: existing installs, which never run
# that path again.
#
# What it does: writes "autoUpdatesChannel": "latest" into ~/.claude/settings.json,
# the key Claude's own updater reads on every check. That is instant and offline,
# so the launch is never blocked on a download — the next auto-update simply
# finds the newer build and takes it. Only if this machine has no JSON tool at
# all does it fall back to a detached `claude install latest`.
#
# One-shot (marker-guarded) and always exits 0, so it can never block a launch.
# Must run as the launcher's non-root user — the one whose $HOME holds .claude.

set -u

MARKER="$HOME/.kivun/fast-updates-set"
SETTINGS="$HOME/.claude/settings.json"

[ -f "$MARKER" ] && exit 0

# No Claude on this machine yet → the fresh-install path already passes `latest`.
CC="$HOME/.local/bin/claude"
[ -x "$CC" ] || CC="$(command -v claude 2>/dev/null || true)"
[ -n "$CC" ] && [ -x "$CC" ] || exit 0

mkdir -p "$HOME/.kivun" "$HOME/.claude" 2>/dev/null

# Already on the fast channel — nothing to do, and never look again.
if [ -f "$SETTINGS" ] && grep -q '"autoUpdatesChannel"[[:space:]]*:[[:space:]]*"latest"' "$SETTINGS" 2>/dev/null; then
  touch "$MARKER"
  exit 0
fi

# No settings file yet: writing one is safe and needs no JSON parser.
if [ ! -s "$SETTINGS" ]; then
  printf '{\n  "autoUpdatesChannel": "latest"\n}\n' > "$SETTINGS" 2>/dev/null && touch "$MARKER"
  exit 0
fi

# A settings file exists and must be edited without disturbing anything else in
# it, so this needs a real JSON parser. Write to a temp file and move it into
# place only on success, so a crash mid-write can never leave the user with a
# truncated settings.json.
TMP="$SETTINGS.kivun-tmp.$$"

if command -v python3 >/dev/null 2>&1; then
  if python3 - "$SETTINGS" "$TMP" <<'PY' 2>>/tmp/kivun-claude.log
import json, sys
src, dst = sys.argv[1], sys.argv[2]
with open(src, encoding='utf-8') as f:
    settings = json.load(f)
settings['autoUpdatesChannel'] = 'latest'
with open(dst, 'w', encoding='utf-8') as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
    f.write('\n')
PY
  then
    mv -f "$TMP" "$SETTINGS" && touch "$MARKER"
    exit 0
  fi
  rm -f "$TMP"
fi

if command -v node >/dev/null 2>&1; then
  if node -e '
const fs = require("fs");
const [src, dst] = process.argv.slice(1);
const settings = JSON.parse(fs.readFileSync(src, "utf8"));
settings.autoUpdatesChannel = "latest";
fs.writeFileSync(dst, JSON.stringify(settings, null, 2) + "\n");
' "$SETTINGS" "$TMP" >>/tmp/kivun-claude.log 2>&1
  then
    mv -f "$TMP" "$SETTINGS" && touch "$MARKER"
    exit 0
  fi
  rm -f "$TMP"
fi

# Last resort: no JSON tool on this machine. Claude's own installer writes the
# same key, so run it detached — it downloads, which is why it is not the first
# choice. The marker is set only when it succeeds, so an offline machine retries
# on the next launch.
setsid -f bash -c "'$CC' install latest >>/tmp/kivun-claude.log 2>&1 && touch '$MARKER'" >/dev/null 2>&1

exit 0
