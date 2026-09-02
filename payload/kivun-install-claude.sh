#!/bin/bash
# Auto-install Claude Code via Anthropic's official installer.
# Called by kivun-terminal.bat when claude is not found in WSL.
#
# Run via `setsid -f bash kivun-install-claude.sh` so the install
# survives wsl.exe exit. v1.1.21/v1.1.22 tried `( ... ) & disown` but
# the detached subshell was killed when wsl.exe's interop relay exited
# its cgroup. `setsid -f` creates a new session — the install becomes
# session leader, fully orphaned from wsl.exe.
#
# The `latest` argument is deliberate. Anthropic ships two release channels:
# `stable` (conservative, can sit unchanged for weeks) and `latest` (current).
# bootstrap.sh with NO argument installs stable, and stable is what the built-in
# auto-updater then follows forever, so those users silently fall dozens of
# releases behind. Passing `latest` both installs the current build AND makes
# the binary persist "autoUpdatesChannel": "latest" in ~/.claude/settings.json,
# which is what every later auto-update reads. See also kivun-fast-updates.sh,
# which does the same for people who already had Claude before this version.
#
# Output → /tmp/kivun-claude.log
# Exit code → /tmp/kivun-install-rc (atomic marker the launcher polls for)

set +e

rm -f /tmp/kivun-claude.log /tmp/kivun-install-rc

{
  timeout 600 bash -c '
    curl -fsSL --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 30 https://claude.ai/install.sh -o /tmp/claude-installer.sh \
      && bash /tmp/claude-installer.sh latest
    rc=$?
    rm -f /tmp/claude-installer.sh
    exit $rc
  '
} > /tmp/kivun-claude.log 2>&1

echo $? > /tmp/kivun-install-rc
