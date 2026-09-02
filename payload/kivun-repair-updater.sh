#!/bin/bash
# kivun-repair-updater.sh — one-time migration for the v1.4.37 auto-update fix.
#
# Background: before v1.4.37 the npm fallback ran `npm install -g` as root, so
# Claude landed in root-owned /usr/local/lib/node_modules. The runtime user
# cannot write there, so Claude's auto-update fails forever ("Auto-update
# failed: no write permission to npm prefix") and the user is stuck on an old
# version. New installs no longer do this; this script repairs EXISTING ones.
#
# What it does: if Claude resolves to a root-owned system slot (/usr/local/bin
# or /usr/bin), run THAT binary's native installer (`claude install`, no sudo),
# which drops a user-writable copy in ~/.local/bin — exactly what `claude
# /doctor` recommends. Guarded by a marker so it runs at most once, and exits 0
# on every path so it can never block the launch.
#
# Shipped as a script (not an inline `wsl bash -lc "..."` one-liner) on purpose:
# the launcher invokes it via `wsl -- bash <path>` after CRLF-normalizing it,
# which is immune to the cmd.exe quoting that mangled the inline form. Must run
# as the launcher's non-root user (the same one that runs Claude).

set -u

MARKER="$HOME/.kivun/updater-repaired"

# One-shot: already migrated (or already attempted) — nothing to do.
[ -f "$MARKER" ] && exit 0

# Find a root-owned system-slot claude (the result of the old root npm
# fallback). Check the filesystem directly rather than `command -v claude`,
# which in a login shell can resolve to a /mnt/c Windows binary.
CC=/usr/local/bin/claude
[ -x "$CC" ] || CC=/usr/bin/claude
[ -x "$CC" ] || exit 0

# Already migrated to a user-writable native install — leave it alone.
[ -x "$HOME/.local/bin/claude" ] && exit 0

mkdir -p "$HOME/.kivun"

# Run the system binary's own installer to migrate to ~/.local/bin. Mark only
# on success so a transient failure (e.g. offline) retries on the next launch.
# `latest` puts the migrated copy on the current release channel rather than the
# slower `stable` one — a bare `install` would rescue the permissions but leave
# the user pinned to a channel that can sit still for weeks.
if "$CC" install latest >> /tmp/kivun-claude.log 2>&1; then
  touch "$MARKER"
fi

exit 0
