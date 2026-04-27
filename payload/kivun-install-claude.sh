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
# Output → /tmp/kivun-claude.log
# Exit code → /tmp/kivun-install-rc (atomic marker the launcher polls for)

set +e

rm -f /tmp/kivun-claude.log /tmp/kivun-install-rc

{
  timeout 600 bash -c '
    curl -fsSL https://claude.ai/install.sh -o /tmp/claude-installer.sh \
      && bash /tmp/claude-installer.sh
    rc=$?
    rm -f /tmp/claude-installer.sh
    exit $rc
  '
} > /tmp/kivun-claude.log 2>&1

echo $? > /tmp/kivun-install-rc
