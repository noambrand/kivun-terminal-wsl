#!/bin/bash
# kivun-direct.sh — fallback runner used when Konsole cannot start.
# Invoked from kivun-terminal.bat's :run_direct path.
# $1 = Linux work directory (already wslpath-converted by the launcher)
# $2 = Claude system-prompt string (language-specific)
#
# We resolve the claude binary explicitly. The Anthropic curl installer
# drops claude at ~/.local/bin/claude, which is NOT on the default PATH
# for non-interactive bash invocations - so a bare `claude` call from
# the .bat fallback would fail even when claude IS installed.
set -u

# v1.1.15: defense-in-depth root-user guard. The Windows .bat now passes
# --user <non-root-user> to wsl, so this script should never run as root
# in normal flow. But if upstream WSL changes break the .bat detection,
# OR someone invokes this script directly via `wsl --user root -- bash
# kivun-direct.sh`, refuse cleanly with the same fix-instructions that
# kivun-launch.sh shows. Claude Code refuses to start with
# --dangerously-skip-permissions when EUID==0; without this guard the
# user just sees that cryptic error.
if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    echo ""
    echo "============================================================"
    echo " ERROR: Kivun direct-fallback is running as root."
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
    exit 1
fi

cd "$1" 2>/dev/null || cd "$HOME"

if [ -x "$HOME/.local/bin/claude" ]; then
    exec "$HOME/.local/bin/claude" --append-system-prompt "$2"
elif [ -x /usr/local/bin/claude ]; then
    exec /usr/local/bin/claude --append-system-prompt "$2"
elif command -v claude >/dev/null 2>&1; then
    exec claude --append-system-prompt "$2"
else
    echo "ERROR: claude binary not found in any of:" >&2
    echo "  \$HOME/.local/bin/claude" >&2
    echo "  /usr/local/bin/claude" >&2
    echo "  PATH" >&2
    exit 127
fi
