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
