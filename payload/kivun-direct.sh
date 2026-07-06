#!/bin/bash
# kivun-direct.sh — fallback runner used when Konsole cannot start.
# Invoked from kivun-terminal.bat's :run_direct path.
# $1 = Linux work directory (already wslpath-converted by the launcher)
# $2 = Claude system-prompt string (language-specific)
# $3 = Optional extra Claude flags (CLAUDE_FLAGS from config.txt;
#      passed unquoted to claude so the shell word-splits "--a --b").
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

# $3 unquoted on purpose — bash word-splits "--continue --model opus"
# into two argv entries. If $3 is empty, no extra args reach claude.
EXTRA_FLAGS="${3:-}"

# Resolve the claude binary once. The Anthropic curl installer drops it at
# ~/.local/bin/claude, which is NOT on the default non-interactive PATH.
if [ -x "$HOME/.local/bin/claude" ]; then
    CLAUDE_BIN="$HOME/.local/bin/claude"
elif [ -x "$HOME/.npm-global/bin/claude" ]; then
    CLAUDE_BIN="$HOME/.npm-global/bin/claude"
elif [ -x /usr/local/bin/claude ]; then
    CLAUDE_BIN="/usr/local/bin/claude"
elif command -v claude >/dev/null 2>&1; then
    CLAUDE_BIN="claude"
else
    echo "ERROR: claude binary not found in any of:" >&2
    echo "  \$HOME/.local/bin/claude" >&2
    echo "  \$HOME/.npm-global/bin/claude" >&2
    echo "  /usr/local/bin/claude" >&2
    echo "  PATH" >&2
    exit 127
fi

# Bake the prompt into a named var: the interactive shell below (and its claude()
# function) can't see the positional $2, and set -u would fault on a bare $2 there.
PROMPT="$2"

run_claude_direct() {
    # `command` bypasses the claude() function defined for the post-exit shell
    # below, so this always runs the real binary (no recursion).
    command "$CLAUDE_BIN" --append-system-prompt "$PROMPT" $EXTRA_FLAGS "$@"
}

# Resume-flag safety net (v1.5.6): same logic as kivun-launch.sh. If the flags
# ask to resume (--continue / -c / --resume / -r) but this folder has no prior
# conversation, Claude exits immediately with "No conversation found to
# continue". Detect that fast failure and reopen a FRESH session rather than
# leaving the user with a closed terminal. Neither attempt uses exec any more, so
# after Claude ends we can drop to an interactive shell instead of closing.
case " $EXTRA_FLAGS " in
    *" --continue "*|*" -c "*|*" --resume "*|*" -r "*) RESUMING=1 ;;
    *) RESUMING=0 ;;
esac

if [ "$RESUMING" = "1" ]; then
    START=$(date +%s 2>/dev/null || echo 0)
    run_claude_direct
    RC=$?
    END=$(date +%s 2>/dev/null || echo 0)
    if [ "$RC" -ne 0 ] && [ $(( END - START )) -lt 10 ]; then
        EXTRA_FLAGS=$(echo " $EXTRA_FLAGS " | sed -E 's/ (--continue|--resume|-c|-r)( [^ -][^ ]*)?/ /g; s/  */ /g; s/^ //; s/ $//')
        echo ""
        echo " No previous conversation found in this folder — starting fresh..."
        echo ""
        run_claude_direct
    fi
else
    run_claude_direct
fi

# Instead of exec-ing claude (which closed the window the moment Claude exited),
# drop to an interactive shell so the user can run commands and type 'claude' to
# come back. The rcfile's claude() re-runs the same invocation (with the resume
# flags already stripped above if the first attempt found no history).
echo ""
echo "==============================================="
echo " Type 'claude' to return to Claude, or 'exit' to close."
echo " הקלידו claude כדי לחזור, או exit כדי לסגור"
echo "==============================================="
RC_TMP="/tmp/kivun-direct-rc-$(id -u).sh"
rm -f "$RC_TMP" 2>/dev/null
cat > "$RC_TMP" << RCEOF
[ -f "\$HOME/.bashrc" ] && . "\$HOME/.bashrc"
claude() {
    command "$CLAUDE_BIN" --append-system-prompt "$PROMPT" $EXTRA_FLAGS "\$@"
    echo ""
    echo " Type 'claude' to return, or 'exit' to close this window."
    echo " הקלידו claude כדי לחזור, או exit כדי לסגור"
}
RCEOF
exec bash --rcfile "$RC_TMP" -i
